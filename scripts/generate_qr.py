import qrcode
from qrcode.image.svg import SvgPathImage
import os
import shutil

URL = "https://football-bot-yeronym.duckdns.org/v/RTWVPnZOermi36mV6m0w6Ln84olQzhcn"
OUTPUT_DIR = r"c:\Users\yeronym\Documents\projects\homelab\data\letter"
ARTIFACT_DIR = r"C:\Users\yeronym\.gemini\antigravity\brain\46517457-14a3-4020-9fc8-c5585eadfd60"

# 1. High Resolution PNG (Print-Ready)
qr = qrcode.QRCode(
    version=None,
    error_correction=qrcode.constants.ERROR_CORRECT_M,
    box_size=15,
    border=3,
)
qr.add_data(URL)
qr.make(fit=True)

img_png = qr.make_image(fill_color="black", back_color="white")
png_path = os.path.join(OUTPUT_DIR, "qr_code.png")
img_png.save(png_path)
print(f"Saved PNG to {png_path}")

# 2. Vector SVG
qr_svg = qrcode.QRCode(
    image_factory=SvgPathImage,
    error_correction=qrcode.constants.ERROR_CORRECT_M,
    border=3,
)
qr_svg.add_data(URL)
qr_svg.make(fit=True)
svg_img = qr_svg.make_image()
svg_path = os.path.join(OUTPUT_DIR, "qr_code.svg")
svg_img.save(svg_path)
print(f"Saved SVG to {svg_path}")

# 3. Copy to Artifact directory for instant preview
if os.path.exists(ARTIFACT_DIR):
    shutil.copy(png_path, os.path.join(ARTIFACT_DIR, "qr_code.png"))
    shutil.copy(svg_path, os.path.join(ARTIFACT_DIR, "qr_code.svg"))
    print("Copied QR codes to Artifact directory.")
