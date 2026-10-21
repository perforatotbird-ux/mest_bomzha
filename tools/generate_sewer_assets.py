from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import random, math

ROOT = Path(__file__).resolve().parents[1] / 'Assets/Environment/Sewer'
ROOT.mkdir(parents=True, exist_ok=True)
random.seed(7)


def rgba(hexv, a=255):
    hexv = hexv.lstrip('#')
    return tuple(int(hexv[i:i+2], 16) for i in (0, 2, 4)) + (a,)

PAL = {
    'night': rgba('#071116'),
    'wall_dark': rgba('#0d1a1f'),
    'wall_mid': rgba('#183027'),
    'wall_green': rgba('#274d35'),
    'moss': rgba('#78c331'),
    'slime': rgba('#8bf52c'),
    'slime2': rgba('#5bc920'),
    'acid': rgba('#a4ff2b'),
    'acid_deep': rgba('#3d7114'),
    'metal': rgba('#6d7567'),
    'stone': rgba('#495043'),
    'rust': rgba('#8d5426'),
    'lamp': rgba('#ffd56a'),
    'door': rgba('#6b4720'),
    'red': rgba('#d63d2e'),
    'fog': rgba('#9cecc0', 42),
}


def save(img, name):
    img.save(ROOT / name)
    print('wrote', name)


def noise_specks(draw, w, h, count, colors, r=(1, 3)):
    for _ in range(count):
        x = random.randint(0, w - 1)
        y = random.randint(0, h - 1)
        rr = random.randint(*r)
        c = random.choice(colors)
        draw.ellipse((x - rr, y - rr, x + rr, y + rr), fill=c)


def linear_gradient(w, h, top, bottom):
    img = Image.new('RGBA', (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px_row = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(4))
        for x in range(w):
            px[x, y] = px_row
    return img


def draw_light_beam(base, x, top_y, bottom_y, width, color):
    beam = Image.new('RGBA', base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(beam)
    poly = [
        (x - width * 0.3, top_y),
        (x + width * 0.3, top_y),
        (x + width, bottom_y),
        (x - width, bottom_y),
    ]
    d.polygon(poly, fill=color)
    beam = beam.filter(ImageFilter.GaussianBlur(radius=18))
    base.alpha_composite(beam)


def arches(draw, y, x0, x1, step, color, height=240, thickness=8):
    for x in range(x0, x1, step):
        draw.arc((x, y - height, x + step, y), 180, 360, fill=color, width=thickness)
        draw.line((x, y - height/2, x, y), fill=color, width=thickness)
        draw.line((x + step, y - height/2, x + step, y), fill=color, width=thickness)


def make_bg_far():
    w, h = 2048, 1024
    img = linear_gradient(w, h, rgba('#081116'), rgba('#1f3d2b'))
    d = ImageDraw.Draw(img)
    for _ in range(10):
        x = random.randint(-100, w)
        y = random.randint(280, 700)
        r = random.randint(180, 360)
        d.ellipse((x-r, y-r*0.65, x+r, y+r*0.65), outline=rgba('#274635', 120), width=4)
    arches(d, 720, -100, w + 120, 360, rgba('#2d4338', 110), height=280, thickness=6)
    for py in [220, 410, 610]:
        d.rectangle((0, py, w, py + 14), fill=rgba('#20352c', 80))
    for cx in [280, 690, 1220, 1680]:
        draw_light_beam(img, cx, 50, 940, 90, rgba('#9fd4ff', 35))
    haze = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hz = ImageDraw.Draw(haze)
    for _ in range(30):
        x = random.randint(0, w)
        y = random.randint(120, h)
        rw = random.randint(160, 360)
        rh = random.randint(40, 120)
        hz.ellipse((x-rw, y-rh, x+rw, y+rh), fill=rgba('#8fddb7', random.randint(8, 20)))
    haze = haze.filter(ImageFilter.GaussianBlur(24))
    img.alpha_composite(haze)
    save(img, 'bg_far.png')


def make_bg_mid():
    w, h = 2048, 1024
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in [240, 420, 590]:
        d.rectangle((0, y, w, y + 26), fill=rgba('#3f4a40', 120))
        d.rectangle((0, y+10, w, y + 18), fill=rgba('#1f251f', 120))
    for x in [120, 420, 780, 1120, 1500, 1850]:
        d.rectangle((x, 140, x + 34, 860), fill=rgba('#1d241d', 80))
        d.rectangle((x+10, 150, x + 24, 860), fill=rgba('#324238', 100))
    for _ in range(18):
        x = random.randint(0, w-220)
        y = random.randint(120, 760)
        ww = random.randint(140, 360)
        hh = random.randint(24, 56)
        r = 18
        d.rounded_rectangle((x, y, x+ww, y+hh), radius=r, outline=rgba('#6c4a25', 140), width=8, fill=rgba('#2e352d', 90))
        d.rectangle((x+20, y+hh//2-4, x+ww-20, y+hh//2+4), fill=rgba('#141714', 120))
    for x in [240, 640, 880, 1260, 1760]:
        for seg in range(7):
            y = 110 + seg * 95
            d.rounded_rectangle((x-5, y, x+20, y+68), radius=10, outline=rgba('#7c5b2d', 130), width=4)
    for x in [350, 870, 1460]:
        for i in range(6):
            y0 = 70 + i * 120
            d.ellipse((x-8, y0, x+8, y0+16), fill=rgba('#6f5634', 180))
            d.line((x, y0+8, x, y0+116), fill=rgba('#584626', 180), width=4)
    glow = Image.new('RGBA', (w, h), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    for x,y in [(250,720), (760,610), (1390,700), (1880,360)]:
        gd.ellipse((x-120,y-30,x+120,y+60), fill=rgba('#7ef329', 55))
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    img.alpha_composite(glow)
    save(img, 'bg_mid.png')


def make_bg_front():
    w, h = 2048, 1024
    img = Image.new('RGBA', (w, h), (0,0,0,0))
    d = ImageDraw.Draw(img)
    for side in [0, 1]:
        if side == 0:
            pts = [(0,1024),(0,760),(130,690),(240,750),(310,1024)]
        else:
            pts = [(2048,1024),(2048,760),(1900,700),(1760,770),(1680,1024)]
        d.polygon(pts, fill=rgba('#111212', 220))
        for _ in range(8):
            x = random.randint(0, 320) if side == 0 else random.randint(1720, 2048)
            y = random.randint(710, 1000)
            rr = random.randint(24, 80)
            d.ellipse((x-rr,y-rr*0.7,x+rr,y+rr*0.7), fill=rgba('#191c19', 180))
    for x in [260, 1740]:
        d.rounded_rectangle((x, 800, x+110, 920), radius=16, outline=rgba('#824d24', 180), width=10, fill=rgba('#30281d', 140))
    save(img, 'bg_front.png')


def make_platform(name, w=320, h=120, hanging=False):
    img = Image.new('RGBA', (w, h), (0,0,0,0))
    d = ImageDraw.Draw(img)
    top_h = 34 if not hanging else 26
    main = rgba('#c3c4b6') if not hanging else rgba('#8b5a2b')
    edge = rgba('#45473c') if not hanging else rgba('#43240e')
    fill = rgba('#676c5e') if not hanging else rgba('#73461d')
    d.rounded_rectangle((12, 14, w-12, top_h+10), radius=10, fill=main, outline=edge, width=6)
    d.rectangle((18, top_h, w-18, h-18), fill=fill)
    # bricks or planks
    if not hanging:
        for y in range(top_h+6, h-18, 22):
            offset = 0 if ((y//22) % 2)==0 else 24
            for x in range(18+offset, w-30, 48):
                d.line((x, y, x, min(h-18, y+18)), fill=edge, width=4)
            d.line((18, y, w-18, y), fill=edge, width=3)
    else:
        for x in range(24, w-16, 36):
            d.line((x, top_h+2, x+18, h-22), fill=rgba('#563010'), width=4)
            d.line((x, h-26, x+26, h-26), fill=rgba('#3b1d08'), width=4)
    # slime drips
    for _ in range(16 if not hanging else 10):
        x = random.randint(22, w-22)
        length = random.randint(10, 34 if not hanging else 22)
        d.rectangle((x-3, top_h+8, x+3, top_h+8+length), fill=PAL['slime2'])
        d.ellipse((x-9, top_h+length+2, x+9, top_h+length+16), fill=PAL['slime'])
    # grime / highlight
    noise_specks(d, w, h, 240, [rgba('#1d211e', 70), rgba('#95d531', 85), rgba('#9a9f94', 50)], (1,2))
    save(img, name)


def make_door():
    w,h = 256, 352
    img = Image.new('RGBA', (w,h), (0,0,0,0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((28,18,w-28,h-18), radius=24, fill=rgba('#3b2a16'), outline=rgba('#c48631'), width=10)
    d.rounded_rectangle((48,58,w-48,h-28), radius=72, fill=rgba('#70481e'), outline=rgba('#e4a53f'), width=8)
    d.rounded_rectangle((68,82,w-68,h-44), radius=56, fill=rgba('#2a231a'), outline=rgba('#8a5b29'), width=5)
    cx, cy = w//2, h//2+12
    d.ellipse((cx-36, cy-36, cx+36, cy+36), outline=rgba('#dba34f'), width=8, fill=rgba('#523616'))
    for a in range(0, 360, 60):
        rad = math.radians(a)
        x2 = cx + math.cos(rad)*54
        y2 = cy + math.sin(rad)*54
        d.line((cx, cy, x2, y2), fill=rgba('#e0b76a'), width=6)
    save(img, 'door_heavy.png')


def make_lamp():
    w,h=96,160
    img = Image.new('RGBA',(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    d.line((w//2,0,w//2,28), fill=rgba('#403322'), width=4)
    d.ellipse((w//2-8,20,w//2+8,36), fill=rgba('#4c3d2a'))
    glow = Image.new('RGBA',(w,h),(0,0,0,0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((8,38,88,120), fill=rgba('#ffd968',130))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(glow)
    d.rounded_rectangle((24,44,72,108), radius=12, outline=rgba('#84663a'), width=5, fill=rgba('#f7ca54', 140))
    for yy in range(48,108,12):
        d.line((30,yy,66,yy), fill=rgba('#644818'), width=2)
    for xx in [34,48,62]:
        d.line((xx,46,xx,106), fill=rgba('#644818'), width=2)
    save(img, 'lamp_cage.png')


def make_spout():
    w,h=256,240
    img = Image.new('RGBA',(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((38,48,166,146), radius=28, fill=rgba('#50402e'), outline=rgba('#8e5e2c'), width=10)
    d.rectangle((0,76,96,118), fill=rgba('#4b3a2b'))
    d.ellipse((118,74,210,160), fill=rgba('#131713'))
    d.line((165,146,190,220), fill=PAL['acid'], width=24)
    d.line((173,146,198,228), fill=rgba('#bfff3e',150), width=10)
    d.ellipse((162,210,226,236), fill=rgba('#7af22d',120))
    save(img, 'pipe_spout.png')


def make_chain():
    w,h=32,160
    img = Image.new('RGBA',(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    for i in range(5):
        y = i*30 + 4
        if i%2==0:
            d.rounded_rectangle((6,y,26,y+22), radius=9, outline=rgba('#916530'), width=4)
        else:
            d.rounded_rectangle((8,y,24,y+22), radius=8, outline=rgba('#6e4c20'), width=4)
    save(img, 'chain_segment.png')


def make_enemy_placeholder(name, size, body, accent):
    w,h = size
    img = Image.new('RGBA',(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8,8,w-8,h-8), radius=14, fill=rgba('#17212a', 220), outline=accent, width=4)
    d.rectangle((14,14,w-14,30), fill=accent)
    if 'drone' in name:
        d.ellipse((w//2-22,h//2-18,w//2+22,h//2+18), fill=body, outline=accent, width=3)
        d.ellipse((w//2-10,h//2-8,w//2+10,h//2+8), fill=rgba('#d9382c'))
        d.line((20,20,w-20,20), fill=rgba('#d8dde0'), width=5)
    elif 'dog' in name:
        d.rectangle((16,36,w-18,h-24), fill=body, outline=accent, width=3)
        d.polygon([(36,32),(54,18),(74,34)], fill=body, outline=accent)
        d.rectangle((30,h-24,36,h-8), fill=accent)
        d.rectangle((w-42,h-24,w-36,h-8), fill=accent)
    elif 'rat' in name:
        d.ellipse((16,24,w-20,h-18), fill=body, outline=accent, width=3)
        d.line((w-14,h//2,w-2,h//2-10), fill=accent, width=3)
    else:
        d.rectangle((22,30,w-22,h-18), fill=body, outline=accent, width=3)
        d.ellipse((26,10,w-26,46), fill=body, outline=accent, width=3)
        d.rectangle((30,h-22,38,h-4), fill=accent)
        d.rectangle((w-38,h-22,w-30,h-4), fill=accent)
    save(img, name)


make_bg_far()
make_bg_mid()
make_bg_front()
make_platform('platform_stone.png', 360, 126, hanging=False)
make_platform('platform_hanging.png', 340, 92, hanging=True)
make_door()
make_lamp()
make_spout()
make_chain()
make_enemy_placeholder('placeholder_guard.png', (100, 132), rgba('#263543'), rgba('#f0b44b'))
make_enemy_placeholder('placeholder_drone.png', (120, 90), rgba('#3c4a57'), rgba('#ff5f52'))
make_enemy_placeholder('placeholder_dog.png', (130, 84), rgba('#584b3c'), rgba('#f08f3d'))
make_enemy_placeholder('placeholder_rat.png', (72, 48), rgba('#4c433a'), rgba('#a98f6c'))
