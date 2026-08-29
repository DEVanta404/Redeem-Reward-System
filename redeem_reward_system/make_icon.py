from PIL import Image, ImageDraw
import os

root = r'c:\Users\admin\OneDrive\Desktop\Reward System\redeem_reward_system'
asset_dir = os.path.join(root, 'assets')
os.makedirs(asset_dir, exist_ok=True)
out_path = os.path.join(asset_dir, 'kapetol_icon.png')

W = H = 1024
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

cx, cy = W // 2, H // 2
r = 430
black = (0, 0, 0, 255)
white = (255, 255, 255, 255)

# circular black badge
for radius in range(r, r - 30, -1):
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=black, width=2)
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=black)

# central white leaf cluster
leaf_shapes = [
    (cx - 360, cy - 40, cx - 100, cy + 200),
    (cx - 210, cy - 130, cx + 30, cy + 210),
    (cx + 30, cy - 130, cx + 270, cy + 210),
    (cx + 120, cy - 40, cx + 360, cy + 200),
]
for box in leaf_shapes:
    d.pieslice(box, start=180, end=360, fill=white)

# top central petal
points = [
    (cx - 55, cy - 270),
    (cx + 55, cy - 270),
    (cx + 180, cy - 110),
    (cx + 80, cy + 10),
    (cx, cy - 85),
    (cx - 80, cy + 10),
    (cx - 180, cy - 110),
]
d.polygon(points, fill=white)

# curved white accents
for box in [
    (cx - 290, cy - 160, cx + 290, cy + 60),
    (cx - 240, cy - 120, cx + 240, cy + 120),
    (cx - 180, cy - 70, cx + 180, cy + 170),
]:
    d.arc(box, start=180, end=360, fill=white, width=90)

# inner petal shapes to resemble latte art
inner_boxes = [
    (cx - 270, cy - 220, cx - 60, cy + 40),
    (cx - 120, cy - 260, cx + 120, cy + 30),
    (cx + 60, cy - 220, cx + 270, cy + 40),
]
for box in inner_boxes:
    d.pieslice(box, start=205, end=335, fill=white)

# Save with alpha background
img.save(out_path)
print(f'Created {out_path}')
