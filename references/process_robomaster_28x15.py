from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

INPUT_PATH = Path("map.png")
CROPPED_OUTPUT_PATH = Path("robomaster_cropped_28x15.png")
FINAL_OUTPUT_PATH = Path("robomaster_28x15_grid_scale_cm_title.png")

MAP_W_MM = 28000
MAP_H_MM = 15000

GRID_INTERVAL_MM = 1000

# Extra inward crop after auto-cropping. Increase these values to trim more edge pixels.
# Order: left, top, right, bottom.
INSET_CROP_PX_SIZE = 18.5
INSET_CROP_PX = (INSET_CROP_PX_SIZE, INSET_CROP_PX_SIZE,
                 INSET_CROP_PX_SIZE, INSET_CROP_PX_SIZE)

LINE_COLOR = (255, 255, 255, 70)
LINE_WIDTH = 1
DASH_LEN = 8
GAP_LEN = 10

LEFT_MARGIN = 72
BOTTOM_MARGIN = 42
TOP_MARGIN = 44
RIGHT_MARGIN = 42

TICK_COLOR = (80, 80, 80)
TEXT_COLOR = (70, 70, 70)
AXIS_LINE_COLOR = (170, 170, 170)
TITLE_COLOR = (50, 50, 50)
TICK_LEN = 6
TITLE_TEXT = "2026RMUC"


def load_font(size=12):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for fp in candidates:
        p = Path(fp)
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


FONT = load_font(12)
TITLE_FONT = load_font(18)


def text_size(draw, text, font):
    try:
        bbox = draw.textbbox((0, 0), text, font=font)
        return bbox[2] - bbox[0], bbox[3] - bbox[1]
    except Exception:
        return draw.textsize(text, font=font)


def draw_dashed_line(draw, start, end, dash_len=8, gap_len=10, fill=(255, 255, 255, 70), width=1):
    x1, y1 = start
    x2, y2 = end
    if x1 == x2:
        y = y1
        step = dash_len + gap_len
        while y < y2:
            draw.line((x1, y, x2, min(y + dash_len, y2)),
                      fill=fill, width=width)
            y += step
    elif y1 == y2:
        x = x1
        step = dash_len + gap_len
        while x < x2:
            draw.line((x, y1, min(x + dash_len, x2), y2),
                      fill=fill, width=width)
            x += step
    else:
        raise ValueError("Only horizontal / vertical lines are supported.")


def auto_crop_to_ratio_remove_white_border(img, target_w=28, target_h=15, white_threshold=250):
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()

    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if not (r >= white_threshold and g >= white_threshold and b >= white_threshold):
                xs.append(x)
                ys.append(y)

    x0, x1 = min(xs), max(xs) + 1
    y0, y1 = min(ys), max(ys) + 1
    bbox_w = x1 - x0
    bbox_h = y1 - y0

    k = min(bbox_w // target_w, bbox_h // target_h)
    crop_w = target_w * k
    crop_h = target_h * k

    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2

    left = round(cx - crop_w / 2)
    top = round(cy - crop_h / 2)
    right = left + crop_w
    bottom = top + crop_h

    if left < x0:
        left = x0
        right = left + crop_w
    if right > x1:
        right = x1
        left = right - crop_w
    if top < y0:
        top = y0
        bottom = top + crop_h
    if bottom > y1:
        bottom = y1
        top = bottom - crop_h

    return rgb.crop((left, top, right, bottom))


# Extra inset crop after auto-cropping, then re-crop to target aspect ratio.
def inset_crop_to_ratio(img, inset_px=(0, 0, 0, 0), target_w=28, target_h=15):
    left_inset, top_inset, right_inset, bottom_inset = inset_px
    w, h = img.size

    left = left_inset
    top = top_inset
    right = w - right_inset
    bottom = h - bottom_inset

    if left >= right or top >= bottom:
        raise ValueError("Inset crop is too large for the image size.")

    cropped = img.crop((left, top, right, bottom))
    cw, ch = cropped.size

    target_ratio = target_w / target_h
    current_ratio = cw / ch

    if current_ratio > target_ratio:
        new_w = round(ch * target_ratio)
        offset_x = (cw - new_w) // 2
        cropped = cropped.crop((offset_x, 0, offset_x + new_w, ch))
    elif current_ratio < target_ratio:
        new_h = round(cw / target_ratio)
        offset_y = (ch - new_h) // 2
        cropped = cropped.crop((0, offset_y, cw, offset_y + new_h))

    return cropped


def add_grid_rulers_title(base):
    w, h = base.size
    px_per_mm_x = w / MAP_W_MM
    px_per_mm_y = h / MAP_H_MM

    canvas_w = LEFT_MARGIN + w + RIGHT_MARGIN
    canvas_h = TOP_MARGIN + h + BOTTOM_MARGIN

    canvas = Image.new("RGB", (canvas_w, canvas_h), "white")
    map_left = LEFT_MARGIN
    map_top = TOP_MARGIN
    map_right = map_left + w
    map_bottom = map_top + h
    canvas.paste(base, (map_left, map_top))

    overlay = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    draw_overlay = ImageDraw.Draw(overlay)

    x_mm = GRID_INTERVAL_MM
    while x_mm < MAP_W_MM:
        x_px = map_left + round(x_mm * px_per_mm_x)
        draw_dashed_line(draw_overlay, (x_px, map_top), (x_px, map_bottom),
                         dash_len=DASH_LEN, gap_len=GAP_LEN,
                         fill=LINE_COLOR, width=LINE_WIDTH)
        x_mm += GRID_INTERVAL_MM

    y_mm = GRID_INTERVAL_MM
    while y_mm < MAP_H_MM:
        y_px = map_top + round(y_mm * px_per_mm_y)
        draw_dashed_line(draw_overlay, (map_left, y_px), (map_right, y_px),
                         dash_len=DASH_LEN, gap_len=GAP_LEN,
                         fill=LINE_COLOR, width=LINE_WIDTH)
        y_mm += GRID_INTERVAL_MM

    canvas = Image.alpha_composite(
        canvas.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(canvas)

    draw.line((map_left, map_bottom, map_right, map_bottom),
              fill=AXIS_LINE_COLOR, width=1)
    draw.line((map_left, map_top, map_left, map_bottom),
              fill=AXIS_LINE_COLOR, width=1)
    draw.line((map_left, map_top, map_right, map_top),
              fill=AXIS_LINE_COLOR, width=1)
    draw.line((map_right, map_top, map_right, map_bottom),
              fill=AXIS_LINE_COLOR, width=1)

    tw, th = text_size(draw, TITLE_TEXT, TITLE_FONT)
    title_x = map_left + (w - tw) / 2
    title_y = (TOP_MARGIN - th) / 2
    draw.text((title_x, title_y), TITLE_TEXT,
              fill=TITLE_COLOR, font=TITLE_FONT)

    for x_mm in range(0, MAP_W_MM + 1, GRID_INTERVAL_MM):
        x_px = map_left + round(x_mm * px_per_mm_x)
        draw.line((x_px, map_bottom, x_px, map_bottom + TICK_LEN),
                  fill=TICK_COLOR, width=1)
        label_cm = str(x_mm // 10)
        ltw, lth = text_size(draw, label_cm, FONT)
        draw.text((x_px - ltw / 2, map_bottom + TICK_LEN + 2),
                  label_cm, fill=TEXT_COLOR, font=FONT)

    for y_mm in range(0, MAP_H_MM + 1, GRID_INTERVAL_MM):
        y_px = map_bottom - round(y_mm * px_per_mm_y)
        draw.line((map_left - TICK_LEN, y_px, map_left, y_px),
                  fill=TICK_COLOR, width=1)
        label_cm = str(y_mm // 10)
        ltw, lth = text_size(draw, label_cm, FONT)
        draw.text((map_left - TICK_LEN - 4 - ltw, y_px - lth / 2),
                  label_cm, fill=TEXT_COLOR, font=FONT)

    return canvas


if __name__ == "__main__":
    original = Image.open(INPUT_PATH)
    cropped = auto_crop_to_ratio_remove_white_border(
        original, target_w=28, target_h=15)
    cropped = inset_crop_to_ratio(
        cropped, inset_px=INSET_CROP_PX, target_w=28, target_h=15)
    cropped.save(CROPPED_OUTPUT_PATH)

    final_img = add_grid_rulers_title(cropped)
    final_img.save(FINAL_OUTPUT_PATH)

    print(f"Saved cropped map to: {CROPPED_OUTPUT_PATH}")
    print(f"Saved final image to: {FINAL_OUTPUT_PATH}")
