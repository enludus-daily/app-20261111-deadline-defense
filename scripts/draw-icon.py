#!/usr/bin/env python3
"""しめきりディフェンスのアイコン（1024x1024・透過なし）。木のテーブル＋羊皮紙の盤＋城と時計の敵。

使い方: python3 scripts/draw-icon.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
INK = (58, 35, 18)


def main():
    img = Image.new("RGB", (S, S), (125, 75, 39))
    d = ImageDraw.Draw(img)
    # 木目
    for i in range(0, S, 4):
        t = i / S
        c = (int(125 - 40 * t), int(75 - 28 * t), int(39 - 18 * t))
        d.line([(0, i), (S, i)], fill=c, width=4)
    for k in range(18):
        y0 = k * 60 + 10
        pts = [(x, y0 + 8 * math.sin(x / 90 + k)) for x in range(0, S + 20, 20)]
        d.line(pts, fill=(84, 47, 22), width=3)
    # 羊皮紙の盤（傾けた札）
    board = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    b = ImageDraw.Draw(board)
    b.rounded_rectangle((150, 170, 874, 894), radius=70, fill=(242, 224, 182, 255), outline=INK + (255,), width=14)
    # 道
    road = [(250, 300), (520, 330), (740, 420), (560, 560), (330, 610), (500, 720)]
    b.line(road, fill=INK + (255,), width=86, joint="curve")
    for p in road:
        b.ellipse((p[0] - 43, p[1] - 43, p[0] + 43, p[1] + 43), fill=INK + (255,))
    b.line(road, fill=(210, 174, 112, 255), width=66, joint="curve")
    for p in road:
        b.ellipse((p[0] - 33, p[1] - 33, p[0] + 33, p[1] + 33), fill=(210, 174, 112, 255))
    # 足あとの点線
    for (a, c) in zip(road, road[1:]):
        n = int(math.dist(a, c) / 34)
        for j in range(n):
            t = (j + 0.5) / n
            x, y = a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t
            b.ellipse((x - 6, y - 6, x + 6, y + 6), fill=INK + (150,))
    shadow = board.split()[3].filter(ImageFilter.GaussianBlur(18))
    img.paste((40, 20, 8), (10, 26), shadow)
    img.paste(board, (0, 0), board)
    d = ImageDraw.Draw(img)

    # 城（右下）
    cx, base = 640, 840
    stone, stone_d = (233, 223, 200), (126, 112, 92)
    for (x0, w, h) in [(cx - 150, 80, 190), (cx + 70, 80, 190), (cx - 60, 120, 240)]:
        d.rectangle((x0 + 10, base - h + 12, x0 + w + 10, base + 12), fill=stone_d)
    d.rectangle((cx - 110, base - 130, cx + 120, base + 12), fill=stone_d)
    d.rectangle((cx - 120, base - 140, cx + 110, base), fill=stone, outline=INK, width=10)
    for (x0, w, h) in [(cx - 150, 80, 190), (cx + 70, 80, 190), (cx - 60, 120, 240)]:
        d.rectangle((x0, base - h, x0 + w, base), fill=stone, outline=INK, width=10)
        # 青い屋根
        d.polygon([(x0 - 14, base - h), (x0 + w + 14, base - h), (x0 + w / 2, base - h - w * 1.05)], fill=(42, 87, 170), outline=INK)
        d.line([(x0 - 14, base - h), (x0 + w / 2, base - h - w * 1.05), (x0 + w + 14, base - h), (x0 - 14, base - h)], fill=INK, width=9)
    # 門
    d.rectangle((cx - 30, base - 70, cx + 30, base), fill=(75, 42, 20))
    d.pieslice((cx - 30, base - 100, cx + 30, base - 40), 180, 360, fill=(75, 42, 20))
    # 旗
    fx, fy = cx, base - 240 - 126
    d.line([(fx, fy), (fx, fy - 70)], fill=INK, width=8)
    d.polygon([(fx + 4, fy - 70), (fx + 70, fy - 52), (fx + 4, fy - 34)], fill=(226, 85, 58), outline=INK)

    # 時計の敵（左上、立体）
    ex, ey, r = 330, 400, 150
    d.ellipse((ex - r, ey + r - 30, ex + r, ey + r + 30), fill=(70, 40, 18))
    for sgn in (-1, 1):
        bx = ex + sgn * 105
        d.pieslice((bx - 60, ey - r - 40, bx + 60, ey - r + 80), 180, 360, fill=(240, 194, 78), outline=INK, width=10)
    for sgn in (-1, 1):
        d.line([(ex + sgn * 60, ey + r - 10), (ex + sgn * 95, ey + r + 45)], fill=INK, width=22)
    d.ellipse((ex - r, ey - r + 16, ex + r, ey + r + 16), fill=INK)
    body = Image.new("RGBA", (2 * r, 2 * r), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    for k in range(r, 0, -2):
        t = k / r
        col = (int(238 + (255 - 238) * (1 - t) * 0.6), int(138 + (220 - 138) * (1 - t)), int(53 + (150 - 53) * (1 - t)))
        off = int((1 - t) * r * 0.35)
        bd.ellipse((r - k - off, r - k - off, r + k - off, r + k - off), fill=col + (255,))
    mask = Image.new("L", (2 * r, 2 * r), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, 2 * r - 1, 2 * r - 1), fill=255)
    img.paste(body, (ex - r, ey - r), mask)
    d = ImageDraw.Draw(img)
    d.ellipse((ex - r, ey - r, ex + r, ey + r), outline=INK, width=12)
    fr = 98
    d.ellipse((ex - fr, ey - fr, ex + fr, ey + fr), fill=(255, 243, 214), outline=INK, width=8)
    for i in range(12):
        a = i / 12 * 2 * math.pi
        r1 = fr * (0.62 if i % 3 == 0 else 0.75)
        d.line([(ex + math.cos(a) * fr * 0.86, ey + math.sin(a) * fr * 0.86), (ex + math.cos(a) * r1, ey + math.sin(a) * r1)], fill=INK, width=8 if i % 3 == 0 else 4)
    d.pieslice((ex - 80, ey - 80, ex + 80, ey + 80), -90, 20, fill=(238, 138, 53))
    d.line([(ex, ey), (ex, ey - 70)], fill=INK, width=14)
    d.line([(ex, ey), (ex + 66 * math.cos(math.radians(20)), ey + 66 * math.sin(math.radians(20)))], fill=INK, width=14)
    d.ellipse((ex - 14, ey - 14, ex + 14, ey + 14), fill=INK)
    # つや
    d.ellipse((ex - 128, ey - 100, ex - 98, ey - 50), fill=(255, 236, 200))

    # 大砲の玉（城から敵へ）
    d.ellipse((470, 540, 530, 600), fill=(46, 46, 52), outline=INK, width=6)
    d.ellipse((482, 552, 500, 570), fill=(150, 150, 158))

    img.save(OUT, "PNG", optimize=True)
    print("wrote", os.path.relpath(OUT), img.mode, img.size)


if __name__ == "__main__":
    main()
