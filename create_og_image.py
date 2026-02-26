#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont

# Create image with CBRN branding (1200x630 for OG image)
width, height = 1200, 630
image = Image.new('RGB', (width, height), color='#0D1A16')
draw = ImageDraw.Draw(image)

# Fill background with dark gradient colors
for y in range(height):
    r = int(10 + (y / height) * 3)
    g = int(15 + (y / height) * 11)
    b = int(13 + (y / height) * 9)
    draw.line([(0, y), (width, y)], fill=(r, g, b))

# Draw green circle for icon
cx, cy, radius = 280, 315, 100
draw.ellipse(
    [cx - radius, cy - radius, cx + radius, cy + radius],
    fill='#38FF9C'
)

# Draw shield symbol (simplified)
shield_path = [
    (cx, cy - 60),
    (cx + 40, cy - 45),
    (cx + 40, cy + 20),
    (cx + 30, cy + 45),
    (cx, cy + 60),
    (cx - 30, cy + 45),
    (cx - 40, cy + 20),
    (cx - 40, cy - 45)
]
draw.polygon(shield_path, fill='#0A0F0D')

# Load fonts
try:
    font_path = '/System/Library/Fonts/Helvetica.ttc'
    title_font = ImageFont.truetype(font_path, 72)
    subtitle_font = ImageFont.truetype(font_path, 46)
    desc_font = ImageFont.truetype(font_path, 32)
except Exception:
    title_font = ImageFont.load_default()
    subtitle_font = ImageFont.load_default()
    desc_font = ImageFont.load_default()

# Draw text content
text_x = 420
draw.text((text_x, 210), 'CBRN', font=title_font, fill='#38FF9C')
draw.text((text_x, 295), 'Tactical Command System', font=subtitle_font, fill='#FFFFFF')
draw.text((text_x, 370), 'Chemical, Biological,', font=desc_font, fill='#CCCCCC')
draw.text((text_x, 415), 'Radiological, Nuclear Response', font=desc_font, fill='#CCCCCC')

# Save the image
image.save('web/og-image.png', 'PNG', optimize=True)
print('✅ OG image created: web/og-image.png')
