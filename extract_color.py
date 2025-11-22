from PIL import Image
from collections import Counter
import webcolors

def closest_colour(requested_colour):
    min_colours = {}
    for key, name in webcolors.CSS3_HEX_TO_NAMES.items():
        r_c, g_c, b_c = webcolors.hex_to_rgb(key)
        rd = (r_c - requested_colour[0]) ** 2
        gd = (g_c - requested_colour[1]) ** 2
        bd = (b_c - requested_colour[2]) ** 2
        min_colours[(rd + gd + bd)] = name
    return min_colours[min(min_colours.keys())]

def get_dominant_orange(image_path):
    img = Image.open(image_path)
    img = img.convert("RGBA")
    pixels = img.getdata()
    
    # Filter for non-transparent, non-black, non-white pixels
    # We are looking for the orange.
    # Orange is roughly High Red, Medium Green, Low Blue.
    
    orange_candidates = []
    
    for r, g, b, a in pixels:
        if a < 200: continue # Skip transparent
        
        # Skip blacks/grays/whites
        if r < 50 and g < 50 and b < 50: continue # Black
        if r > 200 and g > 200 and b > 200: continue # White
        if abs(r-g) < 20 and abs(r-b) < 20: continue # Gray
        
        # Check for "orangeness" (R > G > B usually)
        if r > g and r > b:
            orange_candidates.append((r, g, b))
            
    if not orange_candidates:
        print("No orange found.")
        return

    counts = Counter(orange_candidates)
    most_common = counts.most_common(1)[0][0]
    
    hex_color = '#{:02x}{:02x}{:02x}'.format(*most_common)
    print(f"Dominant Orange: {hex_color}")

if __name__ == "__main__":
    get_dominant_orange("assets/images/app_logo.png")
