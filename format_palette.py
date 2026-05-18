import os
from PIL import Image
from hacktools import common
import game


def packBGR555(color):
    r, g, b = color[0] >> 3, color[1] >> 3, color[2] >> 3
    return (b << 10) | (g << 5) | r


def extractUniqueColors(pngpath):
    img = Image.open(pngpath).convert("RGBA")
    pixels = img.load()
    seen = set()
    ordered = []
    for y in range(img.height):
        for x in range(img.width):
            c = pixels[x, y]
            key = (c[0] & 0xF8, c[1] & 0xF8, c[2] & 0xF8)
            if key in seen:
                continue
            seen.add(key)
            ordered.append((c[0], c[1], c[2], 0xFF))
    return ordered


def repack(data):
    palin = data + "extract_DATA/"
    palout = data + "repack_DATA/"
    workfolder = data + "work_IMG/"

    common.logMessage("Replacing palettes ...")
    for palfile in game.palettereplace:
        srcpal = palin + palfile
        dstpal = palout + palfile
        pngpath = workfolder + game.palettereplace[palfile]
        if not os.path.isfile(pngpath):
            common.logWarning("PNG missing for " + palfile + " -> " + pngpath)
            continue
        common.copyFile(srcpal, dstpal)
        colors = extractUniqueColors(pngpath)

        if palfile.endswith(".IPAL"):
            # Some IPALs pack multiple sub-palettes into one 256-color block; the trailing
            # regions are read by other files for unrelated rendering
            ipal_effective_colors = {
                "file00266.IPAL": 128,
            }
            with common.Stream(dstpal, "rb+") as f:
                f.seek(4)
                f.readUInt()  # depth
                num1 = f.readUShort()
                num2 = f.readUShort()
                pallen = num1 * num2 or 0x200
                filesize = os.path.getsize(dstpal)
                if pallen > filesize - 16:
                    pallen = filesize - 16
                colornum = pallen // 2
                if palfile in ipal_effective_colors:
                    colornum = ipal_effective_colors[palfile]
                f.seek(16 + 2)
                wrote = 1
                for c in colors:
                    if wrote >= colornum:
                        break
                    f.writeUShort(packBGR555(c))
                    wrote += 1
                while wrote < colornum:
                    f.writeUShort(0)
                    wrote += 1
                if len(colors) > colornum - 1:
                    common.logWarning(palfile + " has " + str(len(colors)) + " unique colors, truncated to " + str(colornum - 1))
        else:
            with common.Stream(dstpal, "rb+") as f:
                f.seek(20)
                length = f.readUInt()
                bpp = 8 if f.readUShort() == 0x04 else 4
                f.seek(6, 1)
                pallen = f.readUInt()
                offset = f.readUInt()
                if pallen == 0 or pallen > length:
                    pallen = length - 0x18
                colornum = 0x100 if bpp == 8 else 0x10
                if pallen // 2 < colornum:
                    colornum = pallen // 2
                numpals = pallen // (colornum * 2)
                paldata_start = 0x18 + offset
                # Preserve color 0 of each palette; fill the rest with PNG colors.
                f.seek(paldata_start)
                origcolor0s = []
                for p in range(numpals):
                    origcolor0s.append(f.readUShort())
                    f.seek(2 * (colornum - 1), 1)
                f.seek(paldata_start)
                for p in range(numpals):
                    f.writeUShort(origcolor0s[p])
                    wrote = 1
                    for c in colors:
                        if wrote >= colornum:
                            break
                        f.writeUShort(packBGR555(c))
                        wrote += 1
                    while wrote < colornum:
                        f.writeUShort(0)
                        wrote += 1
                if len(colors) > colornum - 1:
                    common.logWarning(palfile + " has " + str(len(colors)) + " unique colors, truncated to " + str(colornum - 1))
    common.logMessage("Done!")


def _readPaletteColors(palpath):
    # Mirrors the color-reading parts of game.readIPAL / nitro.readNCLR.
    if palpath.endswith(".IPAL"):
        size = os.path.getsize(palpath) - 16
        with common.Stream(palpath, "rb") as f:
            f.seek(4)
            depth = f.readUInt()
            num1 = f.readUShort()
            num2 = f.readUShort()
            pallen = num1 * num2 or 0x200
            if size < pallen:
                pallen = size
            colornum = pallen // 2
            f.seek(16)
            palettes = []
            for _ in range(size // pallen):
                palettes.append([common.readPalette(f.readUShort()) for _ in range(colornum)])
        bpp = 4 if depth == 0x10 else 8
        return palettes, bpp
    with common.Stream(palpath, "rb") as f:
        f.seek(20)
        length = f.readUInt()
        bpp = 8 if f.readUShort() == 0x04 else 4
        f.seek(6, 1)
        pallen = f.readUInt()
        offset = f.readUInt()
        if pallen == 0 or pallen > length:
            pallen = length - 0x18
        colornum = 0x10 if bpp == 4 else 0x100
        if pallen // 2 < colornum:
            colornum = pallen // 2
        f.seek(0x18 + offset)
        palettes = []
        for _ in range(pallen // (colornum * 2)):
            palettes.append([common.readPalette(f.readUShort()) for _ in range(colornum)])
    return palettes, bpp
