from pymongo import MongoClient
from pymongo.errors import ConnectionFailure
import os
# MongoDB connection URL
# For local MongoDB:

# If using MongoDB Atlas:
# MONGO_URL = "mongodb+srv://username:password@cluster0.mongodb.net/studently_db?retryWrites=true&w=majority"
MONGO_URL = os.getenv("MONGO_URL")
if not MONGO_URL:
    raise Exception("MONGO_URL environment variable not set. Please set it to your MongoDB connection string.")

try:
    # Connect to MongoDB with a timeout
    client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
    
    # Trigger a command to verify the connection
    client.admin.command('ping')
    
    # Create/access database
    db = client["studently_db"]

    # Collections
    users_collection = db["users"]
    posts_collection = db["posts"]
    conversations_collection = db["conversations"]
    messages_collection = db["messages"]
    
    # NEW: Knowledge Hub Collection
    courses_collection = db["courses"]
    resources_collection = db["resources"]

    print("MongoDB connection established!")

except ConnectionFailure:
    print("Error: MongoDB server not available.")
except Exception as e:
    print(f"An unexpected error occurred while connecting to MongoDB: {e}")