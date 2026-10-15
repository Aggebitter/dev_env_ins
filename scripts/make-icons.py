#!/usr/bin/env python3
"""
make-icons.py — Generate composite desktop icons: VS Code + board badge.
Usage: python3 make-icons.py [board1 board2 ...]
       If no boards given, generates all environments.
"""
import sys
import os
from PIL import Image, ImageDraw, ImageFont

BOARD_CFG = {
    'arduino': {'bg': (0,   151, 157), 'text': 'Ar',  'fg': (255, 255, 255)},
    'esp32':   {'bg': (231,  53,  44), 'text': 'ESP', 'fg': (255, 255, 255)},
    'pico':    {'bg': (197,  26,  74), 'text': 'Pi',  'fg': (255, 255, 255)},
    'teensy':  {'bg': (0,   102, 178), 'text': 'T4',  'fg': (255, 255, 255)},
    'python':  {'bg': (55,  118, 171), 'text': 'Py',  'fg': (255, 212,  59)},
    'node':    {'bg': (51,  153,  51), 'text': 'TS',  'fg': (255, 255, 255)},
    'cpp':     {'bg': (0,    89, 156), 'text': 'C++', 'fg': (255, 255, 255)},
}

VSCODE_ICONS = [
    '/usr/share/code/resources/app/resources/linux/code.png',
    '/usr/share/icons/hicolor/512x512/apps/code.png',
    '/usr/share/icons/hicolor/256x256/apps/code.png',
    '/usr/share/pixmaps/code.png',
]

FONT_PATHS = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
    '/usr/share/fonts/truetype/freefont/FreeSansBold.ttf',
    '/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf',
]

OUTPUT_DIR = os.path.expanduser('~/.local/share/icons')


def find_vscode_icon():
    for p in VSCODE_ICONS:
        if os.path.exists(p):
            return p
    return None


def find_font(size):
    for p in FONT_PATHS:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def make_badge(size, bg, text, fg):
    badge = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(badge)

    # Drop shadow
    shadow_offset = size // 16
    draw.ellipse(
        [shadow_offset, shadow_offset, size - 1, size - 1],
        fill=(0, 0, 0, 120)
    )
    # Main circle
    draw.ellipse(
        [0, 0, size - shadow_offset - 1, size - shadow_offset - 1],
        fill=bg + (255,)
    )
    # White border ring
    border = max(2, size // 24)
    draw.ellipse(
        [border, border, size - shadow_offset - border - 1, size - shadow_offset - border - 1],
        outline=(255, 255, 255, 200),
        width=border
    )
    # Text
    font = find_font(size // (2 if len(text) <= 2 else 3))
    cx = (size - shadow_offset) // 2
    cy = (size - shadow_offset) // 2
    draw.text((cx, cy), text, fill=fg + (255,), font=font, anchor='mm')

    return badge


def make_composite(vscode_path, board, cfg, output_size=256):
    base = Image.open(vscode_path).convert('RGBA')
    base = base.resize((output_size, output_size), Image.LANCZOS)

    badge_size = output_size * 62 // 100   # badge is 62% of icon size
    badge = make_badge(badge_size, cfg['bg'], cfg['text'], cfg['fg'])

    # Place badge bottom-right with slight overlap
    x = output_size - badge_size + badge_size // 8
    y = output_size - badge_size + badge_size // 8
    base.paste(badge, (x, y), badge)

    return base


def main():
    boards = sys.argv[1:] if len(sys.argv) > 1 else list(BOARD_CFG.keys())

    vscode_icon = find_vscode_icon()
    if not vscode_icon:
        print('ERROR: VS Code icon not found. Is VS Code installed?', file=sys.stderr)
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for board in boards:
        if board not in BOARD_CFG:
            print(f'WARNING: unknown board "{board}", skipping', file=sys.stderr)
            continue
        img = make_composite(vscode_icon, board, BOARD_CFG[board])
        out = os.path.join(OUTPUT_DIR, f'dev-env-{board}.png')
        img.save(out, 'PNG')
        print(f'Created icon: {out}')


if __name__ == '__main__':
    main()
