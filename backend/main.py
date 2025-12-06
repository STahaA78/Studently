from fastapi import FastAPI
from routes.user_routes import router as user_router
from contextlib import asynccontextmanager
import logging
from fastapi.middleware.cors import CORSMiddleware

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

# Include routes from user_routes.py
app.include_router(user_router, prefix="/users")
