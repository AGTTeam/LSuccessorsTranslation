import os
from hacktools import common, nitro

binrange = (445000, 884000)


def detectEncodedString(f, encoding):
    return common.detectEncodedString(f, "cp932", [0x25, 0x5c])


def readImage(infolder, file, extension):
    cell = None
    if extension == ".ICHR":
        palettefile = file.replace(extension, ".IPAL")
        mapfile = file.replace(extension, ".ISCR")
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
        palettes, image, map = nitro.readNitroGraphicNBFC(infolder + palettefile, infolder + file, infolder + mapfile)
        width = image.width
        height = image.height
    elif extension == ".NCGR":
        palettes, image, map, cell, width, height = nitro.readNitroGraphic(infolder + palettefile, infolder + file, infolder + mapfile, infolder + cellfile)
    return palettes, image, map, cell, width, height, mapfile, cellfile
