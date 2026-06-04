import os
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from PIL import Image, ImageDraw, ImageFont
import shutil
import glob

APK_DIR = r"E:\Visual_Studio_Code\11_Rustdesk\rustdesk-1.4.6-aarch64-signed.apk"
OUTPUT_DIR = r"E:\Visual_Studio_Code\11_Rustdesk\extracted_icons"

FONT_FILES = [
    os.path.join(APK_DIR, "assets", "flutter_assets", "assets", "tabbar.ttf"),
    os.path.join(APK_DIR, "assets", "flutter_assets", "assets", "gestures.ttf"),
    os.path.join(APK_DIR, "assets", "flutter_assets", "assets", "more.ttf"),
    os.path.join(APK_DIR, "assets", "flutter_assets", "assets", "peer_searchbar.ttf"),
    os.path.join(APK_DIR, "assets", "flutter_assets", "assets", "address_book.ttf"),
    os.path.join(APK_DIR, "assets", "flutter_assets", "assets", "device_group.ttf"),
    os.path.join(APK_DIR, "assets", "flutter_assets", "fonts", "MaterialIcons-Regular.otf"),
]

SVG_ASSETS_DIR = os.path.join(APK_DIR, "assets", "flutter_assets", "assets")
RES_DIR = os.path.join(APK_DIR, "res")


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def glyph_to_svg(glyph_name, font, glyph_set, output_path):
    try:
        glyph = glyph_set[glyph_name]
        pen = SVGPathPen(glyph_set)
        glyph.draw(pen)
        path_d = pen.getCommands()

        if not path_d or path_d.strip() == "":
            return False

        try:
            glyf_table = font["glyf"]
            g = glyf_table[glyph_name]
            if g.numberOfContours == 0:
                return False
            x_min = g.xMin
            y_min = g.yMin
            x_max = g.xMax
            y_max = g.yMax
        except Exception:
            x_min, y_min, x_max, y_max = 0, 0, 1000, 1000

        w = x_max - x_min
        h = y_max - y_min
        if w <= 0 or h <= 0:
            return False

        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x_min} {y_min} {w} {h}" width="{w}" height="{h}">
  <path d="{path_d}" fill="black"/>
</svg>'''

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(svg)
        return True
    except Exception as e:
        print(f"  SVG导出失败 {glyph_name}: {e}")
        return False


def glyph_to_png(glyph_name, font, font_path, output_path, size=128):
    try:
        cmap = font.getBestCmap()
        if not cmap:
            return False

        char_code = None
        for code, gname in cmap.items():
            if gname == glyph_name:
                char_code = code
                break

        if char_code is None:
            return False

        pil_font = ImageFont.truetype(font_path, size - 8)
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        char = chr(char_code)
        bbox = draw.textbbox((0, 0), char, font=pil_font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        if tw <= 0 or th <= 0:
            return False
        x = (size - tw) / 2 - bbox[0]
        y = (size - th) / 2 - bbox[1]
        draw.text((x, y), char, fill=(0, 0, 0, 255), font=pil_font)
        img.save(output_path)
        return True
    except Exception as e:
        print(f"  PNG导出失败 {glyph_name}: {e}")
        return False


def extract_font_icons(font_path, output_base):
    font_name = os.path.splitext(os.path.basename(font_path))[0]
    svg_dir = os.path.join(output_base, font_name, "svg")
    png_dir = os.path.join(output_base, font_name, "png")
    ensure_dir(svg_dir)
    ensure_dir(png_dir)

    print(f"\n处理字体: {font_name}")

    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()

    cmap = font.getBestCmap()
    name_map = {}
    if cmap:
        for code, gname in cmap.items():
            name_map[gname] = f"{gname}_U+{code:04X}"

    count = 0
    skip_names = {".notdef", ".null", "null", "CR", "space"}
    for glyph_name in sorted(glyph_set.keys()):
        if glyph_name in skip_names:
            continue

        display_name = name_map.get(glyph_name, glyph_name)
        safe_name = display_name.replace("/", "_").replace("\\", "_").replace(" ", "_")

        svg_path = os.path.join(svg_dir, f"{safe_name}.svg")
        png_path = os.path.join(png_dir, f"{safe_name}.png")

        svg_ok = glyph_to_svg(glyph_name, font, glyph_set, svg_path)
        png_ok = glyph_to_png(glyph_name, font, font_path, png_path)

        if svg_ok or png_ok:
            count += 1
            unicode_info = ""
            if cmap:
                for code, gname in cmap.items():
                    if gname == glyph_name:
                        ch = chr(code) if code > 0x20 else ""
                        unicode_info = f" (U+{code:04X} '{ch}')"
                        break
            print(f"  [{count}] {glyph_name}{unicode_info}")

    font.close()
    print(f"  共提取 {count} 个图标")
    return count


def copy_svg_assets(svg_dir, output_base):
    target_dir = os.path.join(output_base, "svg_assets")
    ensure_dir(target_dir)

    all_files = glob.glob(os.path.join(svg_dir, "*.svg")) + glob.glob(os.path.join(svg_dir, "*.png"))

    count = 0
    for src in all_files:
        dst = os.path.join(target_dir, os.path.basename(src))
        shutil.copy2(src, dst)
        count += 1

    print(f"\n复制了 {count} 个SVG/PNG资源文件到 {target_dir}")
    return count


def copy_res_images(res_dir, output_base):
    target_dir = os.path.join(output_base, "res_images")
    ensure_dir(target_dir)

    count = 0
    for root, dirs, files in os.walk(res_dir):
        for f in files:
            if f.endswith((".png", ".9.png", ".webp")):
                src = os.path.join(root, f)
                rel = os.path.relpath(src, res_dir)
                rel_dir = os.path.dirname(rel)
                dst_dir = os.path.join(target_dir, rel_dir)
                ensure_dir(dst_dir)
                shutil.copy2(src, os.path.join(dst_dir, f))
                count += 1

    print(f"\n复制了 {count} 个res图片文件到 {target_dir}")
    return count


def main():
    ensure_dir(OUTPUT_DIR)
    print("=" * 60)
    print("RustDesk APK 图标提取工具")
    print("=" * 60)

    total = 0
    for font_path in FONT_FILES:
        if os.path.exists(font_path):
            total += extract_font_icons(font_path, OUTPUT_DIR)
        else:
            print(f"\n字体文件不存在: {font_path}")

    total += copy_svg_assets(SVG_ASSETS_DIR, OUTPUT_DIR)
    total += copy_res_images(RES_DIR, OUTPUT_DIR)

    print(f"\n{'=' * 60}")
    print(f"全部完成! 共提取 {total} 个资源")
    print(f"输出目录: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
