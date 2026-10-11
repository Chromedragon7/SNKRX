"""Render the original permitted FatPixelFont into compact GUI rectangle data.

No uploaded assets are needed. The font author allows use in any form:
https://tyemu.itch.io/fatfuckfont (checked 2026-10-11).
Only the title's glyphs are embedded; PixulBrush remains pending license verification.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root = Path(__file__).resolve().parents[2]
font = ImageFont.truetype(str(root / 'assets/fonts/FatPixelFont.ttf'), 8)
im = Image.new('L', (79, 24))
ImageDraw.Draw(im).text((0, -2), 'SNKRX', font=font, fill=255)
rects = []
for y in range(im.height):
    x = 0
    while x < im.width:
        if im.getpixel((x, y)) >= 128:
            start = x
            while x < im.width and im.getpixel((x, y)) >= 128:
                x += 1
            rects.append((start, y, x-start, 1))
        else:
            x += 1
out = '-- Original SNKRX title lettering: FatPixelFont by Tyemu. See ../ASSETS.md.\nreturn {\n'
out += ''.join(' {' + ','.join(map(str, r)) + '},\n' for r in rects)
out += '}\n'
(root / 'roblox/src/TitleGlyphs.luau').write_text(out)
print(f'Preserved SNKRX title lettering in {len(rects)} horizontal runs.')
