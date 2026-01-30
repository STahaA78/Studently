from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

# MongoDB connection URL
# For local MongoDB:
MONGO_URL = "mongodb://localhost:27017"

# If using MongoDB Atlas:
# MONGO_URL = "mongodb+srv://username:password@cluster0.mongodb.net/studently_db?retryWrites=true&w=majority"

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
    knowledge_hub_collection = db["knowledge_hub"]
    courses_collection = db["courses"]

    print("MongoDB connection established!")

except ConnectionFailure:
    print("Error: MongoDB server not available.")
except Exception as e:
    print(f"An unexpected error occurred while connecting to MongoDB: {e}")