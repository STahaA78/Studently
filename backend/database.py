from pymongo import MongoClient

# MongoDB connection URL
# For local MongoDB:
MONGO_URL = "mongodb://localhost:27017"

# If using MongoDB Atlas:
# MONGO_URL = "mongodb+srv://username:password@cluster0.mongodb.net/studently_db?retryWrites=true&w=majority"

# Connect to MongoDB
client = MongoClient(MONGO_URL)

# Create/access database
db = client["studently_db"]

# Collections
users_collection = db["users"]
# connections_collection = db["connections"]

print("MongoDB connection established!")
