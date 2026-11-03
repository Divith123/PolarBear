#!/usr/bin/env python3
"""Builds the PolarBear installer: dist/PolarBear.dmg.

    python3 Scripts/make_dmg.py            # builds a Release app first
    python3 Scripts/make_dmg.py --app X.app  # uses an app you already built

Set SIGN_IDENTITY to sign the disk image (Scripts/release.sh does).

The disk image opens to the polar bear artwork as its backdrop, with the app on the left and
the Applications folder on the right. The artwork is only read (never modified); the
backdrop is generated from Design/polarbear-original.png at 1x and 2x.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Design", "polarbear-original.png")
DIST = os.path.join(ROOT, "dist")
VOLUME = "PolarBear"

# Window content size in points; icons sit left and right of the bear.
WIDTH, HEIGHT = 660, 400
BAND = 56
APP_POS = (150, 195)
APPS_POS = (510, 195)
ICON_SIZE = 104


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def font(size):
    for path in ("/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def backdrop(scale):
    """The bear artwork, cropped to cover the window, with a solid caption band at the bottom."""
    art = Image.open(SOURCE).convert("RGB")
    w, h = WIDTH * scale, HEIGHT * scale
    ratio = max(w / art.width, h / art.height)
    art = art.resize((round(art.width * ratio), round(art.height * ratio)), Image.LANCZOS)
    left = (art.width - w) // 2
    top = (art.height - h) // 2
    art = art.crop((left, top, left + w, top + h))

    draw = ImageDraw.Draw(art)
    band_top = h - BAND * scale
    draw.rectangle((0, band_top, w, h), fill=(245, 245, 247))
    draw.line((0, band_top, w, band_top), fill=(220, 220, 225), width=scale)

    text = "Drag PolarBear into the Applications folder"
    f = font(15 * scale)
    box = draw.textbbox((0, 0), text, font=f)
    draw.text(((w - (box[2] - box[0])) / 2, band_top + (BAND * scale - (box[3] - box[1])) / 2 - box[1]),
              text, font=f, fill=(60, 60, 66))

    # A small arrow between the two icons, under the bear.
    cy = APP_POS[1] * scale
    x0, x1 = (APP_POS[0] + 78) * scale, (APPS_POS[0] - 78) * scale
    ay = band_top - 22 * scale
    draw.line((x0 + 40 * scale, ay, x1 - 40 * scale, ay), fill=(255, 255, 255), width=3 * scale)
    tip = x1 - 40 * scale
    draw.polygon([(tip, ay - 9 * scale), (tip + 16 * scale, ay), (tip, ay + 9 * scale)], fill=(255, 255, 255))
    return art


def write_backdrop(folder):
    one = os.path.join(folder, "bg.png")
    two = os.path.join(folder, "bg@2x.png")
    backdrop(1).save(one, dpi=(72, 72))
    backdrop(2).save(two, dpi=(144, 144))
    tiff = os.path.join(folder, "background.tiff")
    run("tiffutil", "-cathidpicheck", one, two, "-out", tiff)
    return tiff


def build_app():
    """The Release app with the PolarBear Engine inside it (see Scripts/build_release.sh)."""
    script = os.path.join(ROOT, "Scripts", "build_release.sh")
    out = run(script, os.path.join(tempfile.gettempdir(), "polarbear-dmg-build"), stdout=subprocess.PIPE).stdout
    return out.strip().splitlines()[-1]


def folder_size_mb(path):
    out = run("du", "-sk", path, stdout=subprocess.PIPE).stdout.split()[0]
    return int(out) // 1024 + 1


LAYOUT = """
tell application "Finder"
  tell disk "{volume}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {{200, 120, {right}, {bottom}}}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to {icon}
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "PolarBear.app" of container window to {{{ax}, {ay}}}
    set position of item "Applications" of container window to {{{bx}, {by}}}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
"""


# What macOS drops on a mounted volume. None of it belongs in the finished image.
SYSTEM_FOLDERS = (".fseventsd", ".Trashes", ".Spotlight-V100", ".TemporaryItems", ".DocumentRevisions-V100", ".VolumeIcon.icns")


def tidy(mount):
    """Leaves only what the window needs: the app, the Applications link, the layout (.DS_Store) and the
    backdrop (.background). Those two stay but are flagged hidden, so they never show in Finder."""
    subprocess.run(["mdutil", "-i", "off", mount], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for name in SYSTEM_FOLDERS:
        path = os.path.join(mount, name)
        if os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path, ignore_errors=True)
        elif os.path.exists(path):
            os.remove(path)
    for name in (".background", ".DS_Store"):
        path = os.path.join(mount, name)
        if os.path.exists(path):
            subprocess.run(["chflags", "hidden", path], check=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", help="an already built PolarBear.app")
    args = parser.parse_args()

    app = args.app or build_app()
    if not os.path.isdir(app):
        sys.exit(f"No app at {app}")

    os.makedirs(DIST, exist_ok=True)
    final = os.path.join(DIST, "PolarBear.dmg")
    work = tempfile.mkdtemp(prefix="polarbear-dmg-")
    rw = os.path.join(work, "rw.dmg")
    mount = f"/Volumes/{VOLUME}"
    if os.path.exists(mount):
        run("hdiutil", "detach", mount, "-force")

    try:
        tiff = write_backdrop(work)
        # APFS has none of the visible bookkeeping folders HFS+ images carry.
        run("hdiutil", "create", "-size", f"{folder_size_mb(app) + 60}m", "-fs", "APFS",
            "-volname", VOLUME, "-ov", rw, stdout=subprocess.DEVNULL)
        run("hdiutil", "attach", rw, "-readwrite", "-noverify", "-noautoopen", stdout=subprocess.DEVNULL)

        shutil.copytree(app, os.path.join(mount, "PolarBear.app"), symlinks=True)
        os.symlink("/Applications", os.path.join(mount, "Applications"))
        os.makedirs(os.path.join(mount, ".background"))
        shutil.copy(tiff, os.path.join(mount, ".background", "background.tiff"))

        script = LAYOUT.format(volume=VOLUME, right=200 + WIDTH, bottom=120 + HEIGHT + 28, icon=ICON_SIZE,
                               ax=APP_POS[0], ay=APP_POS[1], bx=APPS_POS[0], by=APPS_POS[1])
        run("osascript", "-e", script)
        run("sync")
        run("hdiutil", "detach", mount, stdout=subprocess.DEVNULL)

        # Mounted again without Finder or Spotlight, so nothing recreates what is removed.
        quiet = os.path.join(work, "mount")
        os.makedirs(quiet)
        run("hdiutil", "attach", rw, "-readwrite", "-noverify", "-nobrowse", "-noautoopen", "-mountpoint", quiet,
            stdout=subprocess.DEVNULL)
        tidy(quiet)
        run("sync")
        run("hdiutil", "detach", quiet, stdout=subprocess.DEVNULL)

        if os.path.exists(final):
            os.remove(final)
        run("hdiutil", "convert", rw, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", final,
            stdout=subprocess.DEVNULL)
        identity = os.environ.get("SIGN_IDENTITY")
        if identity:
            # The disk image itself is signed too, so Gatekeeper can check it before it is opened.
            run("codesign", "--force", "--timestamp", "--sign", identity, final)
        print(final)
    finally:
        if os.path.exists(mount):
            subprocess.run(["hdiutil", "detach", mount, "-force"], check=False)
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
