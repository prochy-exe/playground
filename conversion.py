import os
import subprocess
import concurrent.futures

# Function to convert video files to h264 8bit using ffmpeg
def convert_to_h264(file_path):
  output_file = file_path.replace('.mkv', '_REENCODED.mkv')
  # Determine the input codec using ffprobe
  ffprobe_audio_command = [
    ffprobe_path,
    '-hide_banner',
    '-v', 'error',
    '-select_streams', 'a',
    '-show_entries', 'stream_tags=language',
    '-of', 'default=noprint_wrappers=1:nokey=1',
    file_path]
  ffprobe_codec_command = [
    ffprobe_path,
    '-hide_banner',
    '-v', 'error',
    '-select_streams', 'v:0',
    '-show_entries', 'stream=codec_name',
    '-of', 'default=noprint_wrappers=1:nokey=1',
    file_path]
  try:
      audio_info = subprocess.check_output(ffprobe_audio_command, universal_newlines=True).strip()
      codec_info = subprocess.check_output(ffprobe_codec_command, universal_newlines=True).strip()
      if codec_info == 'h264':
        return 'aborted'
  except subprocess.CalledProcessError as e:
      print(f"Error executing ffprobe: {e}")
      return None

  # Identify the stream index for the Japanese audio track
  lines = audio_info.split('\n')
  japanese_audio_index = 0
  if len(lines) == 1:
    pass
  else:
    for line in lines:
      if line.strip() == 'jpn':
        break
      japanese_audio_index += 1
  
  # Run ffmpeg with hardware acceleration and chosen decoder
  ffmpeg_command = [
    ffmpeg_path,
    '-hide_banner',
    '-hwaccel', 'auto',
    '-i', file_path,
    '-map', '0:v:0',
    '-map', f'0:a:{japanese_audio_index}',
    '-map', '0:s?',
    '-map', '0:t?',
    '-vf', 'format=yuv420p',
    '-profile:v', 'high',
    '-preset', 'p1',
    '-c:v', 'h264_nvenc',
    '-c:s', 'copy',
    '-c:a', 'copy',
    '-c:t', 'copy',
    output_file
  ]
  subprocess.run(ffmpeg_command)
  return output_file

# Function to convert files in a directory using threading
def convert_file(file):
  print(f"Converting {file}...")
  converted_file = convert_to_h264(file)
  if converted_file == 'aborted':
    print('File already in H264 codec')
    return
  os.remove(file)
  os.rename(converted_file, converted_file.replace('_REENCODED', ''))

def chunks(lst, n):
    """Split a list into chunks of approximately equal size."""
    chunk_size = len(lst) // n
    for i in range(0, len(lst), chunk_size):
        yield lst[i:i + chunk_size]

# Function to navigate through the directory and perform conversion with threading
def convert_directory(directory):
    finalFiles = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.mkv') or file.endswith('.mp4') or file.endswith('.avi'):
                file_path = os.path.join(root, file)
                finalFiles.append(file_path)

    num_threads = min(len(finalFiles), 8)  # Using number of available CPU cores
    # Create a ThreadPoolExecutor with the desired number of threads
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_threads) as executor:
        # Submit conversion tasks for each file
        futures = [executor.submit(convert_file, file) for file in finalFiles]

        # Wait for all tasks to complete
        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()  # Get the result to propagate any exceptions
            except Exception as e:
                print(f"An error occurred: {e}")

# Main function to start conversion process
def main():
  global ffprobe_path
  global ffmpeg_path
  ffprobe_path = r"C:\Program Files (x86)\Tools\ffprobe.exe"  # Specify the full path to ffmpeg.exe
  ffmpeg_path = r"C:\Program Files (x86)\Tools\ffmpeg.exe"  # Specify the full path to ffmpeg.exe
  anime_library = r"H:\Anime"
  convert_directory(anime_library)

if __name__ == "__main__":
  main()
