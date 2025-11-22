from PIL import Image, ImageOps
import sys
import numpy as np
from scipy.ndimage import label, find_objects

def remove_text_and_crop(input_path, output_path):
    try:
        img = Image.open(input_path)
        img = img.convert("RGBA")
        
        # Determine mask
        # Check if alpha channel has variation
        r, g, b, a = img.split()
        alpha_arr = np.array(a)
        
        if np.min(alpha_arr) == 255:
            # Fully opaque, assume white background
            # Create mask from grayscale intensity (inverted)
            gray = img.convert("L")
            # Invert: White (255) becomes 0. Dark content becomes high values.
            inverted = ImageOps.invert(gray)
            mask = np.array(inverted) > 20 # Threshold for "not white"
            print("Detected opaque image, using brightness threshold for mask.")
        else:
            # Use alpha channel
            mask = alpha_arr > 20
            print("Detected transparent image, using alpha channel for mask.")

        # Find connected components
        labeled_array, num_features = label(mask)
        objects = find_objects(labeled_array)
        
        if num_features == 0:
            print("Image appears empty (all white/transparent).")
            return

        print(f"Found {num_features} connected components.")

        components = []
        for i, slice_obj in enumerate(objects):
            y_slice, x_slice = slice_obj
            area = np.sum(labeled_array[slice_obj] == (i + 1))
            y_center = (y_slice.start + y_slice.stop) / 2
            
            components.append({
                'index': i + 1,
                'area': area,
                'y_center': y_center,
                'slice': slice_obj
            })
            
        # Sort by area
        components.sort(key=lambda x: x['area'], reverse=True)
        
        main_component = components[0]
        print(f"Main component area: {main_component['area']}")
        
        # Identify text components
        # Text is likely small and below the main component.
        
        main_y_end = main_component['slice'][0].stop
        
        keep_indices = {main_component['index']}
        
        for comp in components[1:]:
            # Keep if large enough (> 10% of main)
            if comp['area'] > 0.1 * main_component['area']:
                keep_indices.add(comp['index'])
                continue
                
            # Keep if not strictly below main component (with buffer)
            comp_y_start = comp['slice'][0].start
            
            # If component starts significantly below the main component's bottom, drop it.
            # Buffer: 5% of main component height
            main_height = main_y_end - main_component['slice'][0].start
            buffer = 0.05 * main_height
            
            if comp_y_start < main_y_end - buffer:
                keep_indices.add(comp['index'])
            else:
                print(f"Dropping component at y={comp_y_start} (area={comp['area']}) - likely text")

        # Create new image
        new_mask = np.isin(labeled_array, list(keep_indices))
        
        data = np.array(img)
        
        # If original was opaque white background, we should probably make the background transparent now?
        # Or keep it white?
        # User wants "maximize content". Transparent background is better for icons.
        
        # Set alpha to 0 where mask is False
        # But we also need to set RGB to white/transparent?
        
        # Let's reconstruct:
        # Where new_mask is True, keep original pixel.
        # Where new_mask is False, make transparent (0,0,0,0).
        
        # However, if the original had white background, the "kept" pixels might still have white edges.
        # But for now, let's just mask.
        
        # Create a completely transparent base
        result_data = np.zeros_like(data)
        
        # Copy pixels where new_mask is True
        # We can just use the original data but set alpha=0 where !new_mask
        
        result_data = data.copy()
        result_data[~new_mask] = [0, 0, 0, 0] # Clear removed parts
        
        # Also, if the original was opaque, we might want to turn the "white background" into transparent
        # even within the kept area?
        # That's risky (might make white parts of the cat transparent).
        # Let's stick to removing the text blocks.
        
        result_img = Image.fromarray(result_data)
        
        # Crop whitespace
        bbox = result_img.getbbox()
        if bbox:
            final_img = result_img.crop(bbox)
            final_img.save(output_path)
            print(f"Saved processed image to {output_path}")
        else:
            print("Error: Result image is empty.")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    remove_text_and_crop("assets/images/app_logo.png", "assets/images/app_logo.png")
