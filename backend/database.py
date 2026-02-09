from pymongo import MongoClient

MONGO_URL = "mongodb://localhost:27017"
client = MongoClient(MONGO_URL)

db = client["studently_db"]

users_collection = db["users"]
posts_collection = db["posts"]
messages_collection = db["messages"]
conversations_collection = db["conversations"]
knowledge_hub_collection = db["knowledge_hub"]

print("MongoDB connected successfully")
