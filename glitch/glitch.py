from PIL import Image
import numpy as np, random, os, sys, matplotlib.pyplot as plt, io
from matplotlib.widgets import RectangleSelector

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

def apply_datamosh_effect(image, direction="vertical", melt_region_percentage=0.3, ratio_variation=0.1, max_shift=500):
    """Applies a datamoshing effect by shifting pixel data in groups with random shifts and start/end points per column/row."""
    pixels = np.array(image)
    height, width, channels = pixels.shape
    original_pixels = pixels.copy()

    if direction == "vertical":
        for x in range(width):        
            column_melt_start = int(height * (1 - (melt_region_percentage + random.uniform(0, ratio_variation))))
            column_melt_end = height

            shift_height = random.randint(1, max_shift)
            
            if column_melt_start < 0:
                column_melt_start = 0
            if column_melt_end > height:
                column_melt_end = height
            
            for y in range(column_melt_start, column_melt_end):
                source_y = y + shift_height
                if source_y < height:
                    pixels[y, x] = original_pixels[source_y, x]  
                else:
                    pixels[y, x] = original_pixels[height - 1, x]  

    elif direction == "horizontal":
        for y in range(height):
            row_melt_start = int(width * (1 - (melt_region_percentage + random.uniform(0, ratio_variation))))
            row_melt_end = width
            shift_width = random.randint(1, max_shift)
            
            if row_melt_start < 0:
                row_melt_start = 0
            if row_melt_end > width:
                row_melt_end = width
            
            for x in range(row_melt_start, row_melt_end):
                source_x = x + shift_width
                if source_x < width:
                    pixels[y, x] = original_pixels[y, source_x]  
                else:
                    pixels[y, x] = original_pixels[y, width - 1]  

    datamoshed_image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGBA')
    
    return datamoshed_image

def random_row_shift(image, horizontal_shift_percentage=0.05, vertical_shift_percentage=0.05):
    """Randomly shifts the contents of a minimum of 5 rows in the image horizontally."""
    try: 
        pixels = np.array(image)
        height, width, channels = pixels.shape
        
        num_rows_to_shift = max(5, round(height * horizontal_shift_percentage))
        
        row_indices = random.sample(range(height), num_rows_to_shift)
        shifted_pixels = pixels.copy()
        horizontal_shift = random.randint(-int(width * vertical_shift_percentage), int(width * vertical_shift_percentage))
        for row_index in row_indices:
            if horizontal_shift > 0:
                shifted_pixels[row_index, :-horizontal_shift] = pixels[row_index, horizontal_shift:]
                shifted_pixels[row_index, -horizontal_shift:] = pixels[row_index, -horizontal_shift:]  
            elif horizontal_shift < 0:  
                shifted_pixels[row_index, -horizontal_shift:] = pixels[row_index, :-horizontal_shift]
                shifted_pixels[row_index, :horizontal_shift] = pixels[row_index, :horizontal_shift]  
        return Image.fromarray(np.clip(shifted_pixels, 0, 255).astype(np.uint8), 'RGBA')
    except:
        return random_row_shift(image, horizontal_shift_percentage, vertical_shift_percentage)

def adjust_color(image):
    r, g, b, a = image.split()
    r = r.point(lambda p: p * 0.9)  
    g = g.point(lambda p: p * 0.1)  
    b = b.point(lambda p: p * 1.5)  
    return Image.merge("RGBA", (r, g, b, a))

def byte_corruption(image, corruption_amount=10, jpeg_header_size=50):
    img_format = image.format
    if not img_format:
        _, ext = os.path.splitext(glitch_image_path)
        ext = ext.lower()
        if ext in ['.jpeg', '.jpg']:
            img_format = 'JPEG'
        elif ext == '.png':
            img_format = 'PNG'
        else:
            raise ValueError("Unsupported image format. Use JPG, JPEG, or PNG.")

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

def manual_region_selection(image):
    """Allows the user to manually select multiple regions in the image for further processing."""
    fig, ax = plt.subplots()
    ax.imshow(image)
    rect_coords = []
    global temp_rect_coords
    temp_rect_coords = []
    
    def on_select(eclick, erelease):
        """Callback function for rectangle selection."""
        nonlocal rect_coords
        global temp_rect_coords
        
        x0, y0 = eclick.xdata, eclick.ydata
        x1, y1 = erelease.xdata, erelease.ydata
        temp_rect_coords = [int(x0), int(y0), int(x1 - x0), int(y1 - y0)]

    def on_key(event):
        print("Key pressed: ", event.key)
        global temp_rect_coords
        """Close the plot when 'enter' is pressed."""
        if event.key == 'enter':
            if temp_rect_coords and temp_rect_coords not in rect_coords:
                rect_coords.append(temp_rect_coords)
            plt.close(fig)
        elif event.key == ' ':
            rect_coords.append(temp_rect_coords)
            rectangle_selector.clear()

    rectangle_selector = RectangleSelector(ax, on_select, useblit=True,
                                           button=[1],  
                                           minspanx=5, minspany=5,  
                                           spancoords='pixels',
                                           interactive=True)
    
    fig.canvas.mpl_connect('key_press_event', on_key)
    plt.title("Draw a rectangle, then press 'enter' to finish, or 'space' to add another rectangle")
    plt.axis('off')  
    plt.show()
    return rect_coords

def melt_selection(image, rect_coords, melt_amount=5, direction="vertical"):
    """Melts center x rows or columns from selection."""
    pixels = np.array(image)
    x, y, w, h = rect_coords
    height, width, _ = pixels.shape
    datamoshed_pixels = pixels.copy()

    if direction == "vertical":
        center_row = y + h // 2
        for melt_row in range(melt_amount):
            source_row = center_row + melt_row  
            if source_row < height:
                for row in range(source_row, height):
                    datamoshed_pixels[row, x:x + w] = pixels[source_row, x:x + w]

    elif direction == "horizontal":
        center_col = x + w // 2
        for melt_col in range(melt_amount):
            source_col = center_col + melt_col
            if source_col < width:
                for col in range(source_col, width):
                    datamoshed_pixels[y:y + h, col] = pixels[y:y + h, source_col]

    datamoshed_image = Image.fromarray(np.clip(datamoshed_pixels, 0, 255).astype(np.uint8), 'RGBA')
    return datamoshed_image


def corrupt_selection(image, rect_coords, direction="vertical", enable_melt=True):
    """Corrupts the selection and melts either the bottom rows or right columns of the selection."""
    pixels = np.array(image)
    x, y, w, h = rect_coords
    height, width, _ = pixels.shape
    datamoshed_pixels = pixels.copy()

    if enable_melt:
        if direction == "vertical":
            for row in range(y, y + h):
                if row < height:
                    source_row = random.randint(y, y + h - 1)
                    datamoshed_pixels[row:, x:x + w] = pixels[source_row, x:x + w]
        elif direction == "horizontal":
            for col in range(x, x + w):
                if col < width:
                    source_col = random.randint(x, x + w - 1)
                    datamoshed_pixels[y:y + h, col:] = np.tile(
                        pixels[y:y + h, source_col:source_col + 1], (1, width - col, 1)
                    )

    if direction == "horizontal":
        for row in range(y, y + h):
            if row < height:
                source_row = random.randint(y, y + h - 1)
                datamoshed_pixels[row, x:x + w] = pixels[source_row, x:x + w]
    elif direction == "vertical":
        for col in range(x, x + w):
            if col < width:
                source_col = random.randint(x, x + w - 1)
                datamoshed_pixels[y:y + h, col] = pixels[y:y + h, source_col]

    datamoshed_image = Image.fromarray(np.clip(datamoshed_pixels, 0, 255).astype(np.uint8), 'RGBA')
    return datamoshed_image

def datamosh_selection(image, rect_coords, direction="vertical", melt_region_percentage=0.3, ratio_variation=0.1, max_shift=500):
    """Applies a datamoshing effect by shifting pixel data in a selected region, extending to the bottom or right of the image."""
    pixels = np.array(image)
    height, width, _ = pixels.shape
    original_pixels = pixels.copy()
    
    x, y, w, h = rect_coords
    
    x_end = min(x + w, width)
    y_end = min(y + h, height)
    random_ratio_variation = random.uniform(0, ratio_variation)

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

    datamoshed_image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), 'RGBA')
    
    return datamoshed_image

def apply_effects(input_image_path, output_image_path):
    image = Image.open(input_image_path).convert("RGBA")
    img_format = image.format
    if not img_format:
        _, ext = os.path.splitext(glitch_image_path)
        ext = ext.lower()
        if ext in ['.jpeg', '.jpg']:
            img_format = 'JPEG'
        elif ext == '.png':
            img_format = 'PNG'
        else:
            raise ValueError("Unsupported image format. Use JPG, JPEG, or PNG.")
        
    region_coords = manual_region_selection(image)

    for rect_coords in region_coords:
        # image = corrupt_selection(
        #     image = image,
        #     rect_coords = rect_coords,
        #     direction = "vertical",
        #     enable_melt = True
        # )
        
        # image = melt_selection(
        #     image = image, 
        #     rect_coords = rect_coords,
        #     melt_amount = 20,
        #     direction = "horizontal"
        # )

        image = datamosh_selection(
            image = image,
            rect_coords = rect_coords,
            direction = "horizontal",
            melt_region_percentage = 1,
            ratio_variation = .05,
            max_shift = 20        
        )
    
    # image = apply_stuttery_effect(
    #     image = image,
    #     num_frames = 5
    # )
    
    # image = apply_datamosh_effect(
    #     image = image,
    #     direction = "vertical",
    #     melt_region_percentage = .7,
    #     ratio_variation = .05,
    #     max_shift = 60
    # )
    
    # image = apply_datamosh_effect(
    #     image = image,
    #     direction = "horizontal",
    #     melt_region_percentage = .6,
    #     ratio_variation = .05,
    #     max_shift = 20
    # )
    
    # image = adjust_color(
    #     image = image
    # )
    
    # image = random_row_shift(
    #     image = image,
    #     horizontal_shift_percentage=.2,
    #     vertical_shift_percentage=.2
    # )

    # image = byte_corruption(
    #     image = image,
    #     corruption_amount = 5,
    #     jpeg_header_size = 50 #increase this if the saving the image causes errors and you are using a jpeg image
    # )
    
    if img_format == 'JPEG':
        image = image.convert('RGB')    
    
    image.save(output_image_path)

#glitch_image_path = sys.argv[1]
glitch_image_path = "yuno.jpg"
glitch_image_path = os.path.realpath(glitch_image_path)
glitch_image_name = os.path.basename(glitch_image_path).split('.')
glitch_image_output = os.path.join(os.path.dirname(glitch_image_path), f"{glitch_image_name[0]}_glitched.{glitch_image_name[1]}")
apply_effects(glitch_image_path, glitch_image_output)
