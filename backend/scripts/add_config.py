import argparse
from pymongo import MongoClient
from datetime import datetime,timezone


'''
db.users.updateMany(
  {}, 
  {
    $set: {
      interests: [
        { "name": "Programming", "emoji": "💻" },
        { "name": "AI & Machine Learning", "emoji": "🤖" },
        { "name": "Data Science", "emoji": "📊" },
        { "name": "Business & Startups", "emoji": "🚀" },
        { "name": "Engineering", "emoji": "⚙️" }
      ]
    }
  }
)
'''
# -------------------------------
# MongoDB Config
# -------------------------------
MONGO_URI = "mongodb://localhost:27017"
DB_NAME = "studently_db"
COLLECTION_NAME = "config"

# -------------------------------
# Departments
# -------------------------------
departments_data = [
    {"name": "Computer Science"},
    {"name": "Electrical Engineering"},
    {"name": "Science & Humanities"},
    {"name": "Management"},
    {"name": "AI & Data Science"},
    {"name": "Cyber Security"}
]

# -------------------------------
# Interests
# -------------------------------
interests_data = [
    {
        "category": "Academics & Career",
        "data": [
            {"name": "Programming", "emoji": "💻"},
            {"name": "AI & Machine Learning", "emoji": "🤖"},
            {"name": "Data Science", "emoji": "📊"},
            {"name": "Business & Startups", "emoji": "🚀"},
            {"name": "Finance & Investing", "emoji": "💰"},
            {"name": "Marketing", "emoji": "📢"},
            {"name": "Public Speaking", "emoji": "🎤"},
            {"name": "Research", "emoji": "🔬"},
            {"name": "Engineering", "emoji": "⚙️"},
            {"name": "Design", "emoji": "🎨"}
        ]
    },
    {
        "category": "Tech & Gaming",
        "data": [
            {"name": "Gaming", "emoji": "🎮"},
            {"name": "Mobile Apps", "emoji": "📱"},
            {"name": "Web Development", "emoji": "🌐"},
            {"name": "Cybersecurity", "emoji": "🔐"},
            {"name": "Blockchain", "emoji": "⛓️"},
            {"name": "Open Source", "emoji": "🧩"},
            {"name": "UI/UX Design", "emoji": "🖌️"}
        ]
    },
    {
        "category": "Creative & Arts",
        "data": [
            {"name": "Photography", "emoji": "📷"},
            {"name": "Videography", "emoji": "🎥"},
            {"name": "Music", "emoji": "🎵"},
            {"name": "Singing", "emoji": "🎤"},
            {"name": "Dancing", "emoji": "💃"},
            {"name": "Writing", "emoji": "✍️"},
            {"name": "Poetry", "emoji": "📜"},
            {"name": "Acting", "emoji": "🎭"}
        ]
    },
    {
        "category": "Sports & Fitness",
        "data": [
            {"name": "Gym", "emoji": "🏋️"},
            {"name": "Football", "emoji": "⚽"},
            {"name": "Cricket", "emoji": "🏏"},
            {"name": "Basketball", "emoji": "🏀"},
            {"name": "Badminton", "emoji": "🏸"},
            {"name": "Running", "emoji": "🏃"},
            {"name": "Cycling", "emoji": "🚴"},
            {"name": "Hiking", "emoji": "🥾"}
        ]
    },
    {
        "category": "Social & Lifestyle",
        "data": [
            {"name": "Traveling", "emoji": "✈️"},
            {"name": "Food & Cooking", "emoji": "🍜"},
            {"name": "Coffee", "emoji": "☕"},
            {"name": "Tea", "emoji": "🍵"},
            {"name": "Volunteering", "emoji": "🤝"},
            {"name": "Event Planning", "emoji": "🎉"},
            {"name": "Clubs & Societies", "emoji": "🏫"}
        ]
    },
    {
        "category": "Entertainment",
        "data": [
            {"name": "Movies", "emoji": "🎬"},
            {"name": "TV Shows", "emoji": "📺"},
            {"name": "Anime", "emoji": "🌀"},
            {"name": "Memes", "emoji": "😂"},
            {"name": "YouTube", "emoji": "📹"},
            {"name": "Podcasts", "emoji": "🎧"}
        ]
    },
    {
        "category": "Personal Growth",
        "data": [
            {"name": "Self Improvement", "emoji": "📈"},
            {"name": "Productivity", "emoji": "⏱️"},
            {"name": "Reading", "emoji": "📚"},
            {"name": "Journaling", "emoji": "📓"},
            {"name": "Mindfulness", "emoji": "🧘"},
            {"name": "Networking", "emoji": "🔗"}
        ]
    }
]

# -------------------------------
# Batch Range & Current Term
# -------------------------------
batch_range = {"start": 2018, "end": 2026}
current_term = {"semester": "Spring", "year": 2026}  # Semester: Spring, Summer, Fall

# -------------------------------
# Argument Parser
# -------------------------------
parser = argparse.ArgumentParser(description='Add App Config to MongoDB.')
parser.add_argument(
    '--save',
    help='Save the data to MongoDB if set',
    action='store_true'
)

args = parser.parse_args()

# -------------------------------
# App Config Document
# -------------------------------
app_config = {
    "departments": departments_data,
    "interests": interests_data,
    "batch_range": batch_range,
    "current_term": current_term,
    "updated_at": datetime.now(timezone.utc).replace(tzinfo=None) # ISO timestamp
}

# -------------------------------
# Main Logic
# -------------------------------
if args.save:
    try:
        client = MongoClient(MONGO_URI)
        db = client[DB_NAME]
        collection = db[COLLECTION_NAME]

        # Upsert config document
        collection.insert_one(app_config)

        print("App config saved successfully with updated_at =", app_config["updated_at"])

    except Exception as e:
        print("Error inserting app config:", str(e))
else:
    print("Dry run mode. Use --save to insert into MongoDB.")
    print("App config data:", app_config)