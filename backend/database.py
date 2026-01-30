from pymongo import MongoClient

# MongoDB connection URL
MONGO_URL = "mongodb://localhost:27017"

# Connect to MongoDB
client = MongoClient(MONGO_URL)

# Database
db = client["studently_db"]

# Collections
users_collection = db["users"]
connections_collection = db["connections"]

print("MongoDB connected successfully")
