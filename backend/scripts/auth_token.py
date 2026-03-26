import requests

def get_firebase_id_token(api_key: str, email: str, password: str):
    """Logs into Firebase Auth and returns a valid JWT ID Token."""
    
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}"
    payload = {
        "email": email,
        "password": password,
        "returnSecureToken": True
    }
    
    try:
        response = requests.post(url, json=payload)
        data = response.json()
        
        if "idToken" in data:
            print("\n✅ SUCCESS! Copy the token below:\n")
            print(data["idToken"])
            print("\n(Note: This token expires in exactly 1 hour)")
            return data["idToken"]
        else:
            print("\n❌ ERROR logging in. Check your credentials or API Key.")
            print(f"Details: {data}")
            return None
            
    except Exception as e:
        print(f"\n❌ REQUEST FAILED: {e}")
        return None

if __name__ == "__main__":
    # 1. Paste your Web API Key from the Firebase Console
    API_KEY = "AIzaSyBoCiDrwwhsaxX361R2NekzPir0TgJI4iI"
    
    # 2. Enter the credentials of a user already registered in your Firebase Auth
    EMAIL = "tester@test.com"
    PASSWORD = "tester"
    
    get_firebase_id_token(API_KEY, EMAIL, PASSWORD)