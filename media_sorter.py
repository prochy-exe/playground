import os
import tkinter as tk
from tkinter import filedialog
from PIL import Image, ImageTk
import cv2
import shutil
import keyboard  # Import the keyboard library
import time
import threading  # Import threading for handling keypresses in the background

# Create a Tkinter window
root = tk.Tk()
root.title("Media Viewer")

# Get screen width and height
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()

# Set the window size to half the screen size
window_width = screen_width // 2
window_height = screen_height // 2
root.geometry(f"{window_width}x{window_height}")

# Label for the loading message
loading_label = tk.Label(root, text="Loading files, please wait...", font=('Arial', 20))
loading_label.pack(fill=tk.BOTH, expand=True)

# Variables for media files and current index
media_files = []  # This will hold the list of media files
current_index = 0  # Index to track the currently displayed file
folder_path = ""  # The folder path of the media files
current_file_path = ""  # To track the currently displayed file path

# Function to resize and maintain aspect ratio
def resize_to_fit(image, max_width, max_height):
    # Get current image dimensions
    width, height = image.size
    # Calculate the scaling factor to fit the image within the max width and height
    scaling_factor = min(max_width / width, max_height / height)
    new_width = int(width * scaling_factor)
    new_height = int(height * scaling_factor)
    return image.resize((new_width, new_height), Image.Resampling.LANCZOS)

# Function to display image
def display_image(file_path):
    global current_index, current_file_path
    current_file_path = file_path  # Track the current file being displayed

    image = Image.open(file_path)
    # Resize the image to fit within the window while maintaining aspect ratio
    image = resize_to_fit(image, window_width, window_height)
    photo = ImageTk.PhotoImage(image)
    label = tk.Label(root, image=photo)
    label.image = photo  # Keep a reference to avoid garbage collection
    label.pack(fill=tk.BOTH, expand=True)

# Function to play video
def display_video(file_path):
    global current_index, current_file_path
    current_file_path = file_path  # Track the current file being displayed
    cap = cv2.VideoCapture(file_path)
    label = tk.Label(root)
    label.pack(fill=tk.BOTH, expand=True)
    
    def update_video():
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = Image.fromarray(frame)
            # Resize the video frame to fit within the window while maintaining aspect ratio
            frame = resize_to_fit(frame, window_width, window_height)
            photo = ImageTk.PhotoImage(frame)
            label.config(image=photo)
            label.image = photo
            root.update()
            time.sleep(0.03)  # Control frame rate
        cap.release()

    # Start video playback in a separate thread to avoid blocking the UI
    video_thread = threading.Thread(target=update_video)
    video_thread.daemon = True  # Ensure thread exits when the program ends
    video_thread.start()

# Function to iterate through folder and display media files
def load_media_files(folder_path):
    global media_files
    media_files = [f for f in os.listdir(folder_path) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.mp4', '.avi', '.mov'))]
    
    if not media_files:
        print("No media files found in the folder.")
        return
    
    # Start displaying the first media file after loading is done
    display_next_media()

# Function to display the current media file
def display_next_media():
    global current_index, media_files
    if current_index < len(media_files):
        file_name = media_files[current_index]
        media_path = os.path.join(folder_path, file_name)
        
        # Clear all widgets before displaying the new one
        for widget in root.winfo_children():
            widget.destroy()

        if file_name.lower().endswith(('.jpg', '.jpeg', '.png')):
            display_image(media_path)
        elif file_name.lower().endswith(('.mp4', '.avi', '.mov')):
            display_video(media_path)

# Function to handle keypresses (running in a separate thread)
def keypress_handler():
    global current_index, folder_path, media_files, current_file_path
    while True:
        event = keyboard.read_event()  # Listen for key press event
        if event.event_type == keyboard.KEY_DOWN:
            key = event.name

            if key == 'esc':
                break  # Exit on Escape key press

            # Copy the file to a folder named after the pressed key
            target_folder = os.path.join(folder_path, key)
            
            if not os.path.exists(target_folder):
                os.makedirs(target_folder)

            # Copy the file only if it's not being accessed by another process
            try:
                file_name = media_files[current_index]
                current_file_path = os.path.join(folder_path, file_name)
                target_path = os.path.join(target_folder, file_name)

                # Copy the file to the new folder
                shutil.copy(current_file_path, target_path)
                print(f"Copied {file_name} to {target_folder}")
            except Exception as e:
                print(f"Error copying file: {e}")

            # Move to the next media file
            current_index += 1
            if current_index >= len(media_files):
                print('All media files have been sorted.')
                break

            # Display the next media file
            display_next_media()

    root.destroy()
    exit()

# Open folder dialog to choose folder
folder_path = filedialog.askdirectory()
if folder_path:
    # Run the media loading in a separate thread to avoid blocking the UI
    loading_thread = threading.Thread(target=load_media_files, args=(folder_path,))
    loading_thread.daemon = True
    loading_thread.start()

    # Start a thread for keypress handling
    keypress_thread = threading.Thread(target=keypress_handler)
    keypress_thread.daemon = True
    keypress_thread.start()

# Start the Tkinter main loop
root.mainloop()
