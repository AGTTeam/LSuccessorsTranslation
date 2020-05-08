import struct
import os
from hacktools import common, nitro

binrange = (445000, 884000)


def detectEncodedString(f, encoding):
    return common.detectEncodedString(f, "cp932", [0x25, 0x5c])


def readIPAL(file):
    indexedpalettes = {}
    palettes = []
    size = os.path.getsize(file) - 16
    with common.Stream(file, "rb") as f:
        # f.seek(4)
        # pallen = f.readUShort()
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
    return indexedpalettes


def readICHR(file):
    ichr = nitro.NCGR()
    ichr.tiles = []
    with common.Stream(file, "rb") as f:
        f.seek(4)
        ichr.width = f.readUShort() * 8
        ichr.height = f.readUShort() * 8
        f.seek(2, 1)
        unk1 = f.readByte()
        ichr.bpp = 4 if unk1 == 0xe else 8
        f.seek(2, 1)
        unk2 = f.readByte()
        ichr.lineal = (unk2 == 0x4 and unk1 != 0x20) or unk1 == 0x1
        f.seek(2, 1)
        tiledata = f.read()
    tilelen = len(tiledata)
    for i in range(tilelen // (8 * ichr.bpp)):
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
    iscr = nitro.NSCR()
    iscr.maps = []
    with common.Stream(file, "rb") as f:
        f.seek(4)
        iscr.width = f.readUShort() * 8
        iscr.height = f.readUShort() * 8
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
    palettes = readIPAL(palettefile)
    # Read tiles
    ichr = readICHR(tilefile)
    # Read maps
    iscr = None
    if os.path.isfile(mapfile):
        iscr = readISCR(mapfile)
        ichr.width = iscr.width
        ichr.height = iscr.height
    return palettes, ichr, iscr


def readImage(infolder, file, extension):
    cell = None
    width = height = 0
    if extension == ".ICHR":
        palettefile = file.replace(extension, ".IPAL")
        i = int(file[4:-5])
        if i == 41:
            palettefile = "file00040.IPAL"
        elif i >= 53 and i <= 61:
            palettefile = "file00052.IPAL"
        elif not os.path.isfile(infolder + palettefile) and "_" in file:
            palettefile = file.split("_")[0] + ".IPAL"
        mapfile = ""
        if file == "file00025.ICHR":
            mapfile = "file00025.ISCR"
        if file == "file00027.ICHR":
            mapfile = "file00028_0001.ISCR"
        cellfile = ""
    elif extension == ".NCGR":
        palettefile = file.replace(extension, ".NCLR")
        if palettefile == "file00000.NCLR":
            palettefile = "file00001.NCLR"
        elif palettefile == "file00026.NCLR":
            palettefile = "file00027.NCLR"
        elif palettefile == "file00052.NCLR":
            palettefile = "file00053.NCLR"
        elif not os.path.isfile(infolder + palettefile) and "_" in file:
            palettefile = file.split("_")[0] + ".NCLR"
        mapfile = file.replace(extension, ".NSCR")
        cellfile = file.replace(extension, ".NCER")
    # Read the image
    if extension == ".ICHR":
        palettes, image, map = readNitroGraphicICHR(infolder + palettefile, infolder + file, infolder + mapfile)
        if map is not None:
            image.lineal = False
        if image is not None:
            width = image.width
            height = image.height
    elif extension == ".NCGR":
        palettes, image, map, cell, width, height = nitro.readNitroGraphic(infolder + palettefile, infolder + file, infolder + mapfile, infolder + cellfile)
    return palettes, image, map, cell, width, height, mapfile, cellfile
