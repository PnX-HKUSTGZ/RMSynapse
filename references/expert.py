import cv2
import numpy as np

def crop_main_rect(in_path, out_path, pad=2):
    img = cv2.imread(in_path)  # BGR
    h, w = img.shape[:2]

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # 轻微去噪，让线更连贯
    gray = cv2.GaussianBlur(gray, (5,5), 0)

    # 边缘
    edges = cv2.Canny(gray, 30, 120)

    # 霍夫直线（找长直线）
    lines = cv2.HoughLinesP(
        edges,
        rho=1,
        theta=np.pi/180,
        threshold=120,
        minLineLength=int(min(w, h) * 0.35),  # 只要足够长的线
        maxLineGap=20
    )

    if lines is None:
        raise RuntimeError("没检测到足够长的直线，建议调低 threshold / minLineLength")

    # 把直线分成“近似水平/近似垂直”，并取最靠外的那几条
    horizontals = []
    verticals = []
    for x1, y1, x2, y2 in lines[:, 0]:
        dx, dy = abs(x2 - x1), abs(y2 - y1)
        if dy < 8 and dx > 50:        # 水平
            horizontals.append((x1, y1, x2, y2))
        elif dx < 8 and dy > 50:      # 垂直
            verticals.append((x1, y1, x2, y2))

    if len(horizontals) < 2 or len(verticals) < 2:
        raise RuntimeError("水平/垂直线不足，建议放宽 dy/dx 阈值或调 Canny/Hough 参数")

    # 取最上、最下、最左、最右的外框线位置
    top_y    = min(min(y1, y2) for x1,y1,x2,y2 in horizontals)
    bottom_y = max(max(y1, y2) for x1,y1,x2,y2 in horizontals)
    left_x   = min(min(x1, x2) for x1,y1,x2,y2 in verticals)
    right_x  = max(max(x1, x2) for x1,y1,x2,y2 in verticals)

    # 加一点 padding，避免裁得太紧
    x0 = max(left_x - pad, 0)
    y0 = max(top_y - pad, 0)
    x1 = min(right_x + pad, w-1)
    y1 = min(bottom_y + pad, h-1)

    cropped = img[y0:y1+1, x0:x1+1]
    cv2.imwrite(out_path, cropped)
    return (w, h), (x0, y0, x1, y1), (cropped.shape[1], cropped.shape[0])

# 用法
print(crop_main_rect("map.png", "map_cropped_rect.png", pad=-1))