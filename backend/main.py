from fastapi import FastAPI
from contextlib import asynccontextmanager
import logging
from fastapi.middleware.cors import CORSMiddleware

# Import Routes
from routes.user_routes import router as user_router
from routes.post_routes import router as post_router
from routes.chat_routes import router as chat_router
from routes.profile_routes import router as profile_router

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(logging.DEBUG)

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
)

# Include routes
app.include_router(user_router, prefix="/users", tags=["Authentication"])
app.include_router(profile_router, prefix="/profile", tags=["Profile & Connect"])
app.include_router(post_router, prefix="/feed", tags=["Community Feed"])
app.include_router(chat_router, prefix="/chat", tags=["Direct Messages"])

@app.get("/")
def read_root():
    return {"message": "Welcome to Studently API"}