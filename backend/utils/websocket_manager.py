from fastapi import WebSocket
from typing import Dict, List
import logging

LOGGER = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # Maps user_id -> List of active WebSocket connections
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        LOGGER.debug(f"User {user_id} connected to WebSocket.")

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        LOGGER.debug(f"User {user_id} disconnected from WebSocket.")

    async def send_to_user(self, message: dict, user_id: str):
        """Sends a JSON message to all active connections for a specific user."""
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    LOGGER.error(f"Error sending message to {user_id}: {e}")
                    # Dead connections will be cleaned up on disconnect

manager = ConnectionManager()