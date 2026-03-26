import pandas as pd
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure
import argparse

parser = argparse.ArgumentParser(description='Extract course codes and names from an Excel file.')
parser.add_argument('--save', help='Save the extracted data to MongoDB if set to "true"', action='store_true')
parser.add_argument('--file', type=str, help='Path to the Excel file', default='tt.xlsx')

args = parser.parse_args()

# 1. Setup file path and the sheets you want to read
file_path = args.file
sheets_to_read = ['CS', 'DS', 'SE', 'AI', 'CY']

combined_data = []

# 2. Loop through each sheet
for sheet in sheets_to_read:
    try:
        # Read the specific sheet
        # header=1 assumes the first row (index 0) is the main title and row 2 (index 1) has 'Code', 'Course Title'
        # If your headers are on the very first row, change to header=0
        df = pd.read_excel(file_path, sheet_name=sheet, header=1)
        
        # 3. Extract only the first two columns by Index (0 and 1)
        # This gets 'Code' and 'Course Title' regardless of their exact names
        df_subset = df.iloc[:, [0, 1]]
        
        # Rename for consistency across all sheets
        df_subset.columns = ['code', 'name']
        
        # 4. CLEANING: Drop rows where 'code' is Empty (NaN)
        # This removes "Repeat Courses", "Seniors Batches", and empty separator lines
        df_clean = df_subset.dropna(subset=['code','name'])
        
        # 5. Extra Safety: Remove rows where the header itself was repeated
        df_clean = df_clean[df_clean['code'] != 'Code']
        
        # Add to list
        combined_data.append(df_clean)
        print(f"Processed {sheet}: Found {len(df_clean)} courses.")
        
    except Exception as e:
        print(f"Could not read sheet {sheet}: {e}")

# 6. Combine all sheets into one master list
if combined_data:
    master_df = pd.concat(combined_data)
    
    # 7. Remove Duplicates (e.g., 'Digital Logic Design' appears in all sheets)
    master_df = master_df.drop_duplicates(subset=['code'])
    
    # Reset index for a clean look
    master_df = master_df.reset_index(drop=True)
    print("\n--- Final Extracted Data ---")
    print(master_df.head(10))
    print(f"\nTotal Unique Courses Extracted: {len(master_df)}")
    if args.save:
        # Save to a new DB
        try:
            MONGO_URL = "mongodb://mongo:YaKCLpJBnispZHCjoYLIskTZvoMEMSTU@ballast.proxy.rlwy.net:52947"
            # Connect to MongoDB with a timeout
            client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
            
            # Trigger a command to verify the connection
            client.admin.command('ping')
            
            # Create/access database
            db = client["studently_db"]

            # Courses Collection
            courses_db = db["courses"]
            print("MongoDB connection established!")
            # Insert data into the collection
            records = master_df.to_dict(orient='records')
            insert_result = courses_db.insert_many(records)
            print(f"Inserted {len(insert_result.inserted_ids)} records into the courses collection.")

        except ConnectionFailure:
            print("Error: MongoDB server not available.")
        except Exception as e:
            print(f"An unexpected error occurred while connecting to MongoDB: {e}")
else:
    print("No data found.")