from flask import Flask, render_template, request, jsonify, send_file
from PIL import Image, ImageEnhance
import io, numpy as np, random, json

app = Flask(__name__)

def apply_stuttery_effect(image, num_frames=10):
    """Applies a stuttery effect by randomly displacing pixels, repeating the last valid pixel to avoid transparency."""
    
    image_array = np.array(image)
    height, width, channels = image_array.shape  
    
    output_image = np.zeros((height, width, channels), dtype=np.uint32)  
    for _ in range(num_frames):
        
        offset = random.randint(-5, 5)
        
        shifted_array = np.zeros_like(image_array)
        if offset > 0:  
            shifted_array[:, offset:] = image_array[:, :-offset]
            
            shifted_array[:, :offset] = np.repeat(image_array[:, 0:1], offset, axis=1)
            
        elif offset < 0:  
            shifted_array[:, :offset] = image_array[:, -offset:]

            shifted_array[:, offset:] = np.repeat(image_array[:, -1:], -offset, axis=1)
            
        else:  
            shifted_array = image_array.copy()
        
        output_image += shifted_array
    
    average_pixels = np.clip(output_image // num_frames, 0, 255).astype(np.uint8)
    
    output_image = Image.fromarray(average_pixels, 'RGBA')
    
    return output_image

def apply_datamosh_effect(image, direction="vertical", melt_region_percentage=30, variation_percentage=10, max_shift=500, selection = None):
    """Applies a datamoshing effect by shifting pixel data in groups with random shifts and start/end points per column/row."""
    melt_region_percentage = float(melt_region_percentage * 0.01)
    variation_percentage = float(variation_percentage * 0.01)
    original_pixels = np.array(image)
    height, width, channels = original_pixels.shape
    transparent_base = np.zeros((height, width, channels), dtype=np.uint8)
    pixels = transparent_base.copy()
    if selection:
        x, y, w, h = selection
    else:
        x, y, w, h = 0, 0, width, height

    x_end = min(x + w, width)
    y_end = min(y + h, height)
    random_ratio_variation = random.uniform(0, variation_percentage)
    if direction == "vertical":

        for x_pos in range(x, x_end):
            column_melt_start = int((y_end - y) * (1 - (melt_region_percentage + random_ratio_variation)))
            column_melt_end = height

            shift_height = random.randint(1, max_shift)

            for y_pos in range(y + column_melt_start, column_melt_end):
                source_y = y_pos + shift_height
                if source_y < height:
                    pixels[y_pos, x_pos] = original_pixels[source_y, x_pos]  
                else:
                    pixels[y_pos, x_pos] = original_pixels[height - 1, x_pos]

    elif direction == "horizontal":
        
        for y_pos in range(y, y_end):
            row_melt_start = int((x_end - x) * (1 - (melt_region_percentage + random_ratio_variation)))
            row_melt_end = width

            shift_width = random.randint(1, max_shift)

            for x_pos in range(x + row_melt_start, row_melt_end):
                source_x = x_pos + shift_width
                if source_x < width:
                    pixels[y_pos, x_pos] = original_pixels[y_pos, source_x]  
                else:
                    pixels[y_pos, x_pos] = original_pixels[y_pos, width - 1]

    datamosh_layer = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGBA')
    
    return datamosh_layer

def random_row_shift(image, horizontal_shift_percentage=5, max_rows_to_shift=5):
    """Randomly shifts the contents of a minimum of 5 rows in the image horizontally."""
    horizontal_shift_percentage = float(horizontal_shift_percentage * 0.01)
    try: 
        pixels = np.array(image)
        height, width, channels = pixels.shape
                
        row_indices = random.sample(range(height), max_rows_to_shift)
        shifted_pixels = pixels.copy()
        horizontal_shift = random.randint(-int(width * horizontal_shift_percentage), int(width * horizontal_shift_percentage))
        for row_index in row_indices:
            if horizontal_shift > 0:
                shifted_pixels[row_index, :-horizontal_shift] = pixels[row_index, horizontal_shift:]
                shifted_pixels[row_index, -horizontal_shift:] = pixels[row_index, -horizontal_shift:]  
            if horizontal_shift < 0:  
                shifted_pixels[row_index, -horizontal_shift:] = pixels[row_index, :-horizontal_shift]
                shifted_pixels[row_index, :horizontal_shift] = pixels[row_index, :horizontal_shift]  
        return Image.fromarray(np.clip(shifted_pixels, 0, 255).astype(np.uint8), 'RGBA')
    except:
        return random_row_shift(image, horizontal_shift_percentage, max_rows_to_shift)

def adjust_color(image):
    r, g, b, a = image.split()
    r = r.point(lambda p: p * 0.9)  
    g = g.point(lambda p: p * 0.1)  
    b = b.point(lambda p: p * 1.5)  
    return Image.merge("RGBA", (r, g, b, a))

def byte_corruption(image, corruption_amount=10, jpeg_header_size=50):

    if img_format == 'JPEG':
        image = image.convert('RGB')

    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format=img_format)

    img_bytes = bytearray(img_byte_arr.getvalue())

    if img_format.lower() in ['jpeg', 'jpg']:
        header_size = jpeg_header_size
    elif img_format.lower() == 'png':
        header_size = 8
    else:
        raise ValueError("Unsupported image format. Use JPG, JPEG, or PNG.")

    for _ in range(corruption_amount):
        pos = random.randint(header_size, len(img_bytes) - 1)
        img_bytes[pos] = random.randint(0, 255)

    corrupted_image = Image.open(io.BytesIO(img_bytes))

    return corrupted_image

def apply_melt_effect(image, melt_amount=5, direction="vertical", selection = None):
    """Melts center x rows or columns."""
    original_pixels = np.array(image)
    height, width, channels = original_pixels.shape
    if selection:
        x, y, w, h = selection
    else:
        x, y, w, h = 0, 0, height, width
    transparent_base = np.zeros((height, width, channels), dtype=np.uint8)
    pixels = transparent_base.copy()
    
    if direction == "vertical":
        center_row = y + h // 2
        for melt_row in range(melt_amount):
            source_row = center_row + melt_row  
            if source_row < height:
                for row in range(source_row, height):
                    pixels[row, x:x + w] = original_pixels[source_row, x:x + w]

    elif direction == "horizontal":
        center_col = x + w // 2
        for melt_col in range(melt_amount):
            source_col = center_col + melt_col
            if source_col < width:
                for col in range(source_col, width):
                    pixels[y:y + h, col] = original_pixels[y:y + h, source_col]

    melt_layer = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGBA')
    return melt_layer

def apply_corrupt_effect(image, direction="vertical", selection = None):
    """Corrupts the selection and melts either the bottom rows or right columns of the selection."""
    original_pixels = np.array(image)
    height, width, channels = original_pixels.shape
    if selection:
        x, y, w, h = selection
    else:
        x, y, w, h = 0, 0, height, width
    transparent_base = np.zeros((height, width, channels), dtype=np.uint8)
    pixels = transparent_base.copy()
    
    if direction == "horizontal":
        for row in range(y, y + h):
            if row < height:
                source_row = random.randint(y, y + h - 1)
                pixels[row, x:x + w] = original_pixels[source_row, x:x + w]
    elif direction == "vertical":
        for col in range(x, x + w):
            if col < width:
                source_col = random.randint(x, x + w - 1)
                pixels[y:y + h, col] = original_pixels[y:y + h, source_col]

    corrupt_layer = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGBA')
    return corrupt_layer

# Function to apply effects
def process_image(image):
    img = Image.open(io.BytesIO(image)).convert('RGBA')
    
    # Adjust brightness
    enhancer = ImageEnhance.Brightness(img)
    img = enhancer.enhance(brightness)
    
    # Adjust contrast
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(contrast)
    
    # Adjust sharpness
    enhancer = ImageEnhance.Sharpness(img)
    img = enhancer.enhance(sharpness)

    layers = []

    # Apply filters
    if apply_stutter:
        img = apply_stuttery_effect(img, stutter_frames)
    if apply_datamosh:
        layers.append(apply_datamosh_effect(img, datamosh_direction, datamosh_melt_region_percentage, datamosh_variation_percentage, datamosh_max_shift))
    if apply_pink_purple:
        img = adjust_color(img)
    if apply_random_row_shift:
        img = random_row_shift(img, horizontal_shift_percentage, max_rows_to_shift)

    for selection in selections:
        selection = selections[selection]
        selection_coords = selection['x'], selection['y'], selection['width'], selection['height']
        if selection['apply_datamosh_selection']:
            layers.append(apply_datamosh_effect(img, selection['datamosh_selection_direction'], selection['datamosh_selection_melt_region_percentage'], selection['datamosh_selection_variation_percentage'], selection['datamosh_selection_max_shift'], selection_coords))
        if selection['apply_corrupt_selection']:
            layers.append(apply_corrupt_effect(img, selection['corrupt_selection_direction'], selection_coords))
        if selection['apply_melt_selection']:
            layers.append(apply_melt_effect(img, selection['melt_selection_amount'], selection['melt_selection_direction'], selection_coords))

    if layers:
        for layer in layers:
            img = Image.alpha_composite(img, layer)

    if apply_byte_corruption:
        img = byte_corruption(img, corruption_amount, jpeg_header_size)
    
    return img

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/process', methods=['POST'])
def process():
    global img_format, brightness, contrast, sharpness, \
        apply_stutter, stutter_frames, apply_datamosh, \
        datamosh_direction, datamosh_melt_region_percentage, datamosh_variation_percentage, \
        datamosh_max_shift, apply_pink_purple, apply_random_row_shift, \
        horizontal_shift_percentage, max_rows_to_shift, apply_byte_corruption, \
        corruption_amount, jpeg_header_size, selections
        
    if 'image' not in request.files:
        return "No file uploaded", 400

    ext = request.files['image'].filename.split('.')[1].lower()
    if ext in ['jpeg', 'jpg']:
        img_format = 'JPEG'
    elif ext == 'png':
        img_format = 'PNG'
    else:
        raise ValueError("Unsupported image format. Use JPG, JPEG, or PNG.")
    
    image = request.files['image'].read()
    brightness = 1 + float(request.form.get('brightness', 0))
    contrast = 1 + float(request.form.get('contrast', 0))
    sharpness = 1 + float(request.form.get('sharpness', 0))
    apply_stutter = request.form.get('apply_stutter') == 'true'
    if apply_stutter:
        stutter_frames = int(request.form.get('stutter_frames'), 10)
    apply_datamosh = request.form.get('apply_datamosh') == 'true'
    if apply_datamosh:
        datamosh_direction = request.form.get('datamosh_direction')
        datamosh_melt_region_percentage = int(request.form.get('datamosh_melt_region_percentage', 30))
        datamosh_variation_percentage = int(request.form.get('datamosh_variation_percentage', 10))
        datamosh_max_shift = int(request.form.get('datamosh_max_shift', 500))
    apply_pink_purple = request.form.get('apply_pink_purple') == 'true'
    apply_random_row_shift = request.form.get('apply_random_row_shift') == 'true'
    if apply_random_row_shift:
        horizontal_shift_percentage = int(request.form.get('horizontal_shift_percentage', 5))
        max_rows_to_shift = int(request.form.get('max_rows_to_shift', 5))
    apply_byte_corruption = request.form.get('apply_byte_corruption') == 'true'
    if apply_byte_corruption:
        corruption_amount = int(request.form.get('corruption_amount', 10))
        jpeg_header_size = int(request.form.get('jpeg_header_size', 50))
    selections = json.loads(request.form.get('selections', r'{}'))
    
    processed_img = process_image(image)
    
    img_io = io.BytesIO()
    processed_img = processed_img.convert('RGB')
    processed_img.save(img_io, 'JPEG')
    img_io.seek(0)
    
    return send_file(img_io, mimetype='image/jpeg')

if __name__ == '__main__':
    app.run(debug=True)
