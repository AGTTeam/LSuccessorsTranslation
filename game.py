import struct
import os
from PIL import Image
from hacktools import common, nitro


palettereplace = {
    "file00069.IPAL": "file00069.png",
    "file00093.IPAL": "file00093.png",
    "file00095.IPAL": "file00095.png",
    "file00112.IPAL": "file00112.png",
    "file00136.IPAL": "file00136.png",
    "file00138.IPAL": "file00138.png",
    "file00155.IPAL": "file00154.png",
    "file00179.IPAL": "file00178.png",
    "file00181.IPAL": "file00180.png",
    "file00266.IPAL": "file00266.png",
    "file00722.NCLR": "file00722.png",
    "file00746.NCLR": "file00746.png",
    "file00748.NCLR": "file00748.png",
}


def detectEncodedString(f, encoding):
    return common.detectEncodedString(f, "cp932", [0x25, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x5c, 0x61, 0x63, 0x67, 0x6e])


def writeEncodedString(f, s, maxlen, encoding):
    s = s.replace("—", "ー")
    s = s.replace("…", "...")
    # These characters are replaced with ascii to make more room for translations
    s = s.replace("‘", "[")
    s = s.replace("’", "]")
    s = s.replace("“", "{")
    s = s.replace("”", "}")
    s = s.replace("ï", "$")
    s = s.replace("ç", "+")
    # for name strings, there's actually a lot more space
    if f.tell() >= 0xa0730 and f.tell() < 0xa0a20:
        maxlen = 0xf
    return common.writeEncodedString(f, s, maxlen, "cp932", zerobytes=2)


def readIPAL(file):
    indexedpalettes = {}
    palettes = []
    size = os.path.getsize(file) - 16
    with common.Stream(file, "rb") as f:
        f.seek(4)
        depth = f.readUInt()
        num1 = f.readUShort()
        num2 = f.readUShort()
        pallen = num1 * num2
        if pallen == 0:
            pallen = 0x200
        f.seek(16)
        if size < pallen:
            pallen = size
        colornum = pallen // 2
        for i in range(size // pallen):
            palette = []
            for j in range(colornum):
                palette.append(common.readPalette(f.readUShort()))
            palettes.append(palette)
        indexedpalettes = {i: palettes[i] for i in range(0, len(palettes))}
    common.logDebug("Loaded", len(indexedpalettes), "palettes")
    return indexedpalettes, depth


def readICHR(file, depth):
    common.logDebug("Reading ICHR", file)
    ichr = nitro.NCGR()
    ichr.tiles = []
    with common.Stream(file, "rb") as f:
        f.seek(4)
        ichr.width = f.readUShort() * 8
        ichr.height = f.readUShort() * 8
        unk1 = f.readByte()  # mostly 0
        f.seek(1, 1)  # always 0
        unk2 = f.readByte()
        f.seek(2, 1)  # always 0
        unk3 = f.readByte()
        f.seek(2, 1)  # always 0
        ichr.tileoffset = f.tell()
        tiledata = f.read()
        ichr.bpp = 4 if depth == 0x10 else 8
        ichr.lineal = (unk3 == 0x4 and unk2 != 0x12) or unk3 == 0x1 or unk2 == 0x1
        common.logDebug(vars(ichr))
        common.logDebug(file, "bpp", ichr.bpp, "lineal", ichr.lineal, "unk1", common.toHex(unk1), "unk2", common.toHex(unk2), "unk3", common.toHex(unk3))
    ichr.tilelen = len(tiledata)
    for i in range(ichr.tilelen // (8 * ichr.bpp)):
        singletile = []
        for j in range(ichr.tilesize * ichr.tilesize):
            x = i * (ichr.tilesize * ichr.tilesize) + j
            if ichr.bpp == 4:
                index = (tiledata[x // 2] >> ((x % 2) << 2)) & 0x0f
            else:
                index = tiledata[x]
            singletile.append(index)
        ichr.tiles.append(singletile)
    common.logDebug("Loaded", len(ichr.tiles), "tiles")
    return ichr


def readISCR(file):
    common.logDebug("Reading NSCR", file)
    iscr = nitro.NSCR()
    iscr.maps = []
    with common.Stream(file, "rb") as f:
        f.seek(4)
        iscr.width = f.readUShort() * 8
        iscr.height = f.readUShort() * 8
        common.logDebug(vars(iscr))
        f.seek(16)
        mapdata = f.read()
    for i in range(0, len(mapdata), 2):
        data = struct.unpack("<h", mapdata[i:i+2])[0]
        map = nitro.readMapData(data)
        # map.pal = 0
        iscr.maps.append(map)
    return iscr


def readNitroGraphicICHR(palettefile, tilefile, mapfile):
    if not os.path.isfile(palettefile):
        common.logError("Palette", palettefile, "not found")
        return [], None, None
    palettes, depth = readIPAL(palettefile)
    # Read tiles
    ichr = readICHR(tilefile, depth)
    # Read maps
    iscr = None
    if os.path.isfile(mapfile):
        iscr = readISCR(mapfile)
        ichr.width = iscr.width
        ichr.height = iscr.height
    return palettes, ichr, iscr


def readImage1(infolder, file, extension):
    return readImage(infolder, file, extension, False)

def readImage2(infolder, file, extension):
    return readImage(infolder, file, extension, True)


def readImage(infolder, file, extension, checkpal=False):
    cell = None
    width = height = 0
    i = int(file[4:-5].split("_")[0])
    #if i != 558:
    #    return None, None, None, None, None, None, None, None
    if extension == ".ICHR":
        palettefile = file.replace(extension, ".IPAL")
        if i == 41:
            palettefile = "file00040.IPAL"
        elif i >= 53 and i <= 61:
            palettefile = "file00052.IPAL"
        elif i == 555:
            palettefile = "file00554.IPAL"
        elif i >= 635 and i <= 638:
            palettefile = "file00634.IPAL"
        elif i == 663 or i == 664:
            palettefile = "file00662.IPAL"
        elif i == 666 or i == 667:
            palettefile = "file00665.IPAL"
        elif i == 680 or i == 681:
            palettefile = "file00679.IPAL"
        elif i >= 684 and i <= 686:
            palettefile = "file00683.IPAL"
        elif i == 700 or i == 701:
            palettefile = "file00699.IPAL"
        elif i == 154:
            palettefile = "file00155.IPAL"
        elif i == 178:
            palettefile = "file00179.IPAL"
        elif i == 180:
            palettefile = "file00181.IPAL"
        elif not os.path.isfile(infolder + palettefile) and "_" in file:
            palettefile = file.split("_")[0] + ".IPAL"
        mapfile = ""
        if file == "file00025.ICHR":
            mapfile = "file00025.ISCR"
        elif file == "file00555.ICHR":
            palettefile = "file00554.ISCR"
        cellfile = ""
    elif extension == ".NCGR":
        palettefile = file.replace(extension, ".NCLR")
        if palettefile == "file00000.NCLR":
            palettefile = "file00001.NCLR"
        elif palettefile == "file00025.NCLR":
            palettefile = "file00026.NCLR"
        elif palettefile == "file00052.NCLR":
            palettefile = "file00053.NCLR"
        elif palettefile == "file00061.NCLR":
            palettefile = "file00062.NCLR"
        elif not os.path.isfile(infolder + palettefile) and "_" in file:
            palettefile = file.split("_")[0] + ".NCLR"
        mapfile = file.replace(extension, ".NSCR")
        cellfile = file.replace(extension, ".NCER")
    # Read the image
    palettepath = infolder + palettefile
    if checkpal and palettefile in palettereplace:
        palettepath = infolder.replace("extract_", "repack_") + palettefile
    if extension == ".ICHR":
        palettes, image, map = readNitroGraphicICHR(palettepath, infolder + file, infolder + mapfile)
        if map is not None:
            image.lineal = False
        if image is not None:
            width = image.width
            height = image.height
            if i == 28 or (i >= 260 and i <= 293):
                image.lineal = False
            if i == 558:
                image.lineal = False
            if i == 668:
                image.lineal = True
    elif extension == ".NCGR":
        palettes, image, map, cell, width, height = nitro.readNitroGraphic(palettepath, infolder + file, infolder + mapfile, infolder + cellfile)
    return palettes, image, map, cell, width, height, mapfile, cellfile


def writeImage(workfolder, infolder, outfolder, file, image, palettes, map, cell, width, height):
    extension = os.path.splitext(file)[1]
    i = int(file[4:-5].split("_")[0])
    if extension == ".ICHR":
        pngfile = file.replace(extension, ".png")
        if map is None:
            nitro.writeNCGR(outfolder + file, image, workfolder + pngfile, palettes, width, height)
        else:
            nitro.writeNSCR(outfolder + file, image, map, workfolder + pngfile, palettes, width, height)
    elif extension == ".NCGR":
        return image, palettes, map, cell, width, height, False
    return None, None, None, None, 0, 0, False
