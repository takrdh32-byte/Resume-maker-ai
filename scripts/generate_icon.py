#!/usr/bin/env python3
import os, sys
from PIL import Image, ImageDraw, ImageFont

# रंग
RED = (229, 57, 53)    # #E53935
WHITE = (255, 255, 255)
SIZES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192
}
BASE_DIR = 'android/app/src/main/res'

def draw_icon(size):
    img = Image.new('RGBA', (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(img)

    # लाल गोला
    circle_margin = size * 0.08
    circle_bbox = [circle_margin, circle_margin, size - circle_margin, size - circle_margin]
    draw.ellipse(circle_bbox, fill=RED)

    # सफ़ेद "R"
    font_size = int(size * 0.55)
    try:
        # Linux में कोई bold font ढूँढ़े
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", font_size)
    except:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
        except:
            # फ़ॉलबैक — डिफ़ॉल्ट फ़ॉन्ट
            font = ImageFont.load_default()

    # "R" का टेक्स्ट
    text = "R"
    # टेक्स्ट का आकार निकालें
    left, top, right, bottom = draw.textbbox((0,0), text, font=font)
    text_width = right - left
    text_height = bottom - top
    x = (size - text_width) / 2 - left
    y = (size - text_height) / 2 - top
    draw.text((x, y), text, fill=WHITE, font=font)

    return img

def main():
    os.makedirs(BASE_DIR, exist_ok=True)
    for density, size in SIZES.items():
        img = draw_icon(size)
        out_dir = os.path.join(BASE_DIR, f'mipmap-{density}')
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, 'ic_launcher.png')
        img.save(out_path)
        print(f'Generated {out_path} ({size}x{size})')

if __name__ == '__main__':
    main()