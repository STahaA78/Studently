from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
import logging
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth

# NEW: Import the WebSocket connection manager
from utils.websocket_manager import manager 

# Import Routes
from routes.user_routes import router as user_router
from routes.post_routes import router as post_router
from routes.chat_routes import router as chat_router
from routes.profile_routes import router as profile_router
from routes.knowledge_hub import router as hub_router

# Suppress noisy loggers
logging.getLogger("pymongo").setLevel(logging.WARNING)
logging.getLogger("motor").setLevel(logging.WARNING)

# Root logger
root_logger = logging.getLogger()
root_logger.setLevel(logging.DEBUG)

# Add a console handler if none exists
if not root_logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    ch.setFormatter(formatter)
    root_logger.addHandler(ch)

# Module-level logger example
LOGGER = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    LOGGER.info("Studently Backend Starting Up...")
    yield
    LOGGER.info("Studently Backend Shutting Down...")

app = FastAPI(title="Studently Backend", lifespan=lifespan)

# CORS Middleware to allow requests from any origin (for development purposes)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Length", "Content-Range", "Accept-Ranges"],
)

# Include routes
app.include_router(user_router, prefix="/users", tags=["Authentication"])
app.include_router(profile_router, prefix="/profile", tags=["Profile & Connect"])
app.include_router(post_router, prefix="/feed", tags=["Community Feed"])
app.include_router(chat_router, prefix="/chat", tags=["Direct Messages"])
app.include_router(hub_router, prefix="/hub", tags=["Knowledge Hub"])

# WEBSOCKET ENDPOINT
@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    # 1. Validate Token & Get User ID
    try:
        payload = auth.verify_id_token(token)
        user_id = payload.get("user_id")
        
        if not user_id:
            LOGGER.warning("WebSocket auth failed: No user_id found in token.")
            await websocket.close(code=1008)
            return
    except Exception as e:
        LOGGER.error(f"WebSocket auth failed: {e}")
        await websocket.close(code=1008)
        return

    # 2. Add to Manager
    await manager.connect(websocket, user_id)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        # Note: Must pass BOTH websocket and user_id to remove the exact connection
        manager.disconnect(websocket, user_id)

@app.get("/")
def read_root():
    return {"message": "Welcome to Studently API"}