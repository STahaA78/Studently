from pymongo import MongoClient
from pymongo.errors import ConnectionFailure
import os
from config import CONFIG
# Get MongoDB URL from environment variable
MONGO_URL = CONFIG.MONGO_URL

try:
    client = MongoClient(MONGO_URL)
    db = client["studently_db"]

    # Core Collections
    users_collection = db["users"]
    posts_collection = db["posts"]
    messages_collection = db["messages"]
    conversations_collection = db["conversations"]
    knowledge_hub_collection = db["knowledge_hub"]

    # Knowledge Hub Collections
    courses_collection = db["courses"]
    resources_collection = db["resources"]

    print("MongoDB connection established successfully!")

except ConnectionFailure:
    print("Error: MongoDB server not available.")

except Exception as e:
    print(f"Unexpected MongoDB connection error: {e}")