"""把设计稿右上角那三个按钮放大标注，方便一眼看到"""

from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "shots", "desktop-mock.png")
OUT = os.path.join(ROOT, "shots", "window-buttons.png")

img = Image.open(SRC).convert("RGB")

# 两个窗口标题栏的右上角区域
crop_box = (830, 82, 1500, 200)
crop = img.crop(crop_box)
SCALE = 2
crop = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.LANCZOS)

CONFIG = "C:\\Windows\\Fonts\\msyh.ttc"
def font(size):
    try:
        return ImageFont.truetype(CONFIG, size)
    except Exception:
        return ImageFont.load_default()

# 加一条说明栏
BAR_H = 74
canvas = Image.new("RGB", (crop.width, crop.height + BAR_H), (14, 16, 24))
canvas.paste(crop, (0, 0))

d = ImageDraw.Draw(canvas)

def group(x0, x1, y0, y1):
    """原图坐标 -> 画布坐标"""
    return ((x0 - crop_box[0]) * SCALE, (y0 - crop_box[1]) * SCALE,
            (x1 - crop_box[0]) * SCALE, (y1 - crop_box[1]) * SCALE)

# 浏览器窗口：关闭 934-980，最大 888-934，最小 842-888，标题栏 y 90-126
d.rounded_rectangle(group(842, 980, 90, 126), radius=4, outline=(255, 80, 70), width=3)
# 笔记窗口
d.rounded_rectangle(group(1342, 1480, 150, 186), radius=4, outline=(255, 80, 70), width=3)

label = "红线区域 = 最小化 / 最大化 / 关闭（贴右上角、和标题栏一样高，Windows 11 同款）"
d.text((18, crop.height + 22), label, font=font(21), fill=(255, 255, 255))

canvas.save(OUT, "PNG")
print("wrote", OUT, canvas.size)
