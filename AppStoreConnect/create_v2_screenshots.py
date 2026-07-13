from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "screenshots"
OUTPUT = SOURCE / "iphone-6-5-1284x2778-v2"
OUTPUT.mkdir(parents=True, exist_ok=True)

WIDTH, HEIGHT = 1284, 2778
BACKGROUND = (5, 7, 9)
WHITE = (246, 248, 250)
MUTED = (155, 164, 174)
CYAN = (89, 209, 255)
FONT = "/System/Library/Fonts/SFNS.ttf"


def font(size: int) -> ImageFont.FreeTypeFont:
    selected = ImageFont.truetype(FONT, size=size)
    selected.set_variation_by_name("Bold")
    return selected


def centered_text(draw: ImageDraw.ImageDraw, text: str, y: int, size: int, fill, max_width=1120):
    selected = font(size)
    while draw.textbbox((0, 0), text, font=selected)[2] > max_width and size > 38:
        size -= 2
        selected = font(size)
    box = draw.textbbox((0, 0), text, font=selected)
    draw.text(((WIDTH - (box[2] - box[0])) / 2, y), text, font=selected, fill=fill)


def rounded_screenshot(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGB")
    target_width = 1090
    target_height = 2368
    image.thumbnail((target_width, target_height), Image.Resampling.LANCZOS)

    mask = Image.new("L", image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, image.width, image.height), radius=72, fill=255)
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.paste(image, (0, 0), mask)
    return result


def render(index: int, source_name: str, title: str, subtitle: str):
    canvas = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    centered_text(draw, "LASTMAN", 42, 30, MUTED)
    centered_text(draw, title, 95, 72, WHITE)
    centered_text(draw, subtitle, 190, 34, CYAN)
    draw.rounded_rectangle((530, 263, 754, 273), radius=5, fill=CYAN)

    screenshot = rounded_screenshot(SOURCE / source_name)
    x = (WIDTH - screenshot.width) // 2
    y = 320
    draw.rounded_rectangle(
        (x - 3, y - 3, x + screenshot.width + 3, y + screenshot.height + 3),
        radius=76,
        outline=(82, 91, 101),
        width=6,
    )
    canvas.paste(screenshot, (x, y), screenshot)
    canvas.save(OUTPUT / f"{index:02d}.png", optimize=True)


SCREENS = [
    (1, "v2-menu-clean.png", "UN NOUVEAU DÉFI CHAQUE JOUR", "Même règle. Même arène. Ton meilleur score."),
    (2, "v2-daily-gameplay.png", "LE BATTLE ROYALE DE 90 SECONDES", "Bouge d'un pouce. Vise quand tu veux."),
    (3, "v2-result.png", "BATS TES AMIS", "Partage ton score et lance le défi."),
    (4, "v2-result.png", "PROGRESSE À CHAQUE PARTIE", "Niveaux, missions, séries et maîtrise."),
    (5, "v2-daily-gameplay.png", "JOUE PARTOUT, MÊME HORS LIGNE", "Aucun compte. Aucune publicité."),
]

for spec in SCREENS:
    render(*spec)

print(OUTPUT)
