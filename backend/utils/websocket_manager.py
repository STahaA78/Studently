import json
import asyncio
import logging
import os
from typing import Dict, List
from fastapi import WebSocket
import redis.asyncio as redis
from config import CONFIG
LOGGER = logging.getLogger(__name__)
REDIS_URL = CONFIG.REDIS_URL

class ConnectionManager:
    def __init__(self):
        # Maps user_id -> List of active WebSocket connections ON THIS WORKER ONLY
        self.active_connections: Dict[str, List[WebSocket]] = {}
        
        # Async Redis clients
        self.redis = redis.from_url(REDIS_URL, decode_responses=True)
        self.pubsub = self.redis.pubsub()
        
        # Background task for listening to Redis
        self.listener_task = None

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        
        # 1. Add to local worker's connections
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
            
            # Subscribe to this user's specific Redis channel
            await self.pubsub.subscribe(f"user:{user_id}")
            LOGGER.info(f"Worker subscribed to Redis channel: user:{user_id}")
            
        self.active_connections[user_id].append(websocket)
        LOGGER.debug(f"User {user_id} connected to WebSocket on this worker.")

        # 2. Ensure the Redis listener is running in the background
        if self.listener_task is None or self.listener_task.done():
            self.listener_task = asyncio.create_task(self._listen_to_redis())

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            
            # If this worker has no more connections for this user, unsubscribe from Redis
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
                # Fire and forget the async unsubscribe task
                asyncio.create_task(self._unsubscribe(user_id))
                
        LOGGER.debug(f"User {user_id} disconnected from WebSocket on this worker.")

    async def _unsubscribe(self, user_id: str):
        try:
            await self.pubsub.unsubscribe(f"user:{user_id}")
            LOGGER.info(f"Worker unsubscribed from Redis channel: user:{user_id}")
        except Exception as e:
            LOGGER.error(f"Error unsubscribing from Redis: {e}")

    async def send_to_user(self, message: dict, user_id: str):
        """Publishes a JSON message to the Redis channel for a specific user."""
        try:
            # Convert dictionary to a JSON string
            payload = json.dumps(message)
            # Yell into the Redis intercom
            await self.redis.publish(f"user:{user_id}", payload)
        except Exception as e:
            LOGGER.error(f"Error publishing to Redis for {user_id}: {e}")

    async def _listen_to_redis(self):
        """Background task that listens for Redis broadcasts and forwards them to local WebSockets."""
        try:
            async for message in self.pubsub.listen():
                if message["type"] == "message":
                    channel = message["channel"]
                    data = message["data"]
                    
                    # Extract user_id from channel name (e.g., "user:123" -> "123")
                    user_id = channel.split(":")[1]
                    
                    # Parse JSON string back to dictionary
                    payload = json.loads(data)
                    
                    # If this specific worker holds the connection for the user, send it!
                    if user_id in self.active_connections:
                        for connection in self.active_connections[user_id]:
                            try:
                                await connection.send_json(payload)
                            except Exception as e:
                                LOGGER.error(f"Error sending message to local websocket: {e}")
        except asyncio.CancelledError:
            pass
        except Exception as e:
            LOGGER.error(f"Redis listener error: {e}")
            self.listener_task = None # Reset so it can be restarted on next connect

manager = ConnectionManager()