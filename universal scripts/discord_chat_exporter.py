import requests, time, json

# Replace with your Discord token (breaks TOS, don't blame me)
TOKEN = "xxx"

# Replace with the channel ID of the DM
CHANNEL_ID = "xxx"

# Base URL
BASE_URL = f"https://discord.com/api/v9/channels/{CHANNEL_ID}/messages"

# Headers
headers = {
    "Authorization": TOKEN,
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
}

def fetch_all_messages():
    all_messages = []  # Array to store filtered messages
    params = {"limit": 50}  # Fetch messages in chunks of 50

    while True:
        response = requests.get(BASE_URL, headers=headers, params=params)

        if response.status_code == 200:
            messages = response.json()
            if not messages:
                break  # No more messages to fetch

            # Filter and append only messages from the specified user
            for message in messages:
                all_messages.append({
                    "user_id": message["author"]["id"],
                    "username": message["author"]["username"],
                    "content": message["content"],
                    "timestamp": message["timestamp"],
                    "attachments": message["attachments"],
                    "embeds": message["embeds"]
                })

            # Set the `before` parameter for pagination to fetch older messages
            params["before"] = messages[-1]["id"]
        elif response.status_code == 429:
            retry_after = int(response.headers.get("Retry-After", 1))
            print(f"Rate limited. Retrying after {retry_after} seconds...")
            time.sleep(retry_after)
        else:
            print(f"Failed to fetch messages: {response.status_code} - {response.text}")
            break

    return all_messages

def save_messages_to_json(messages, filename="messages.json"):
    filename = f"{CHANNEL_ID}.json"
    """Save the list of messages to a JSON file."""
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(messages, f, ensure_ascii=False, indent=4)
    print(f"Messages saved to {filename}")

# Fetch all messages from the specified user and store them in an array
save_messages_to_json(fetch_all_messages())