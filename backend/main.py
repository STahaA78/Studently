from fastapi import FastAPI, HTTPException
from contextlib import asynccontextmanager
import logging

logging.basicConfig(
    level=logging.DEBUG,  # Set to INFO or ERROR in production
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
LOGGER = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    LOGGER.info("Studently Backend Starting Up...")
    # Perform startup tasks here
    yield
    LOGGER.info("Studently Backend Shutting Down...")
    # Perform shutdown tasks here

app = FastAPI(title="Studently Backend", lifespan=lifespan)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}