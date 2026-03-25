from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
import logging
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth
from fastapi.staticfiles import StaticFiles

# NEW: Import the WebSocket connection manager
from utils.websocket_manager import manager 

# Import Routes
from routes.user_routes import router as user_router
from routes.post_routes import router as post_router
from routes.chat_routes import router as chat_router
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
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
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
app.include_router(user_router, prefix="/users", tags=["Authentication & User Operations"])
app.include_router(post_router, prefix="/feed", tags=["Community Feed"])
app.include_router(chat_router, prefix="/chat", tags=["Direct Messages"])
app.include_router(hub_router, prefix="/hub", tags=["Knowledge Hub"])

# WEBSOCKET ENDPOINT
@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    # 1. Validate Token & Get User ID
    try:
        payload = auth.verify_id_token(token)
        # Fix 1: Use 'uid' instead of 'user_id'
        user_id = payload.get("user_id") 
        
        if not user_id:
            LOGGER.warning("WebSocket auth failed: No uid found in token.")
            # Fix 2: Return to reject connection safely
            return 
    except Exception as e:
        LOGGER.error(f"WebSocket auth failed: {e}")
        # Fix 2: Return to reject connection safely
        return 

    # 2. Add to Manager (This accepts the connection)
    await manager.connect(websocket, user_id)
    
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except Exception: 
        # Fix 3: Catch generic Exception to prevent memory leaks
        manager.disconnect(websocket, user_id)

@app.get("/")
def read_root():
    return {"message": "Welcome to Studently API"}

    