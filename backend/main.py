from fastapi import FastAPI
from routes.user_routes import router as user_router
from contextlib import asynccontextmanager
import logging

logging.basicConfig(level=logging.DEBUG)
LOGGER = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    LOGGER.info("Studently Backend Starting Up...")
    yield
    LOGGER.info("Studently Backend Shutting Down...")

app = FastAPI(title="Studently Backend", lifespan=lifespan)

# Include routes from user_routes.py
app.include_router(user_router, prefix="/users")
