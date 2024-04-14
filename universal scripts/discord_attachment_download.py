import json, os, requests

CHANNEL_ID = "xxx"

messages = json.load(open(f'{CHANNEL_ID}.json', encoding='utf-8'))

if not os.path.exists(CHANNEL_ID):
    os.makedirs(CHANNEL_ID)

for message in messages:
    if message['attachments']:
        for attachment in message['attachments']:
            url = attachment['url']
            file_extension = attachment['filename'][-3:]
            filename = f"{attachment['id']}.{file_extension}"
            response = requests.get(url)
            file_path = os.path.join(CHANNEL_ID, filename)
            with open(file_path, 'wb') as f:
                f.write(response.content)
            print(f"Downloaded {filename}")