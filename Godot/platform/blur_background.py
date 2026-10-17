"""Makes assets/art/glass_forest_blur.png (the blurred menu backdrop) from glass_forest.png.
Run from the repository root:  python Godot/platform/blur_background.py"""
from PIL import Image, ImageFilter, ImageEnhance

source = "Godot/assets/art/glass_forest.png"
im = Image.open(source).convert("RGB")
small = im.resize((im.width // 2, im.height // 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(9))
out = small.resize(im.size, Image.LANCZOS)
ImageEnhance.Brightness(out).enhance(0.92).save("Godot/assets/art/glass_forest_blur.png", optimize=True)
