import os
from PIL import Image
from hacktools import common

glyphwidth = 16
glyphheight = 12
charnum = 0x1ca4


def repack(data):
    fontin = data + "extract_DATA/file00024.bin"
    fontout = data + "repack_DATA/file00024.bin"
    workfolder = data + "work_FONT/"

    common.logMessage("Repacking FONT from", workfolder)
    with common.Stream(fontin, "rb", False) as fin:
        with common.Stream(fontout, "wb", False) as fout:
            for i in range(charnum):
                fin.seek(i * 0x1a)
                fout.seek(i * 0x1a)
                charid = fin.readUShort()
                fout.writeUShort(charid)
                imgfile = workfolder + str(i).zfill(4) + "_" + common.toHex(charid)  + ".png"
                if os.path.isfile(imgfile):
                    currbit = 0
                    data = 0
                    img = Image.open(imgfile)
                    img = img.convert("RGBA")
                    pixels = img.load()
                    for y in range(glyphheight):
                        for x in range(glyphwidth):
                            if currbit == 8:
                                fout.writeByte(data)
                                data = 0
                                currbit = 0
                            if pixels[x, y] == (255, 255, 255, 255):
                                data |= 1 << (7 - currbit)
                            currbit += 1
                    fout.writeByte(data)
                else:
                    fout.write(fin.read(0x19))
    common.logMessage("Done!")


def extract(data):
    fontin = data + "extract_DATA/file00024.bin"
    fontfolder = data + "extract_FONT/"

    common.logMessage("Extracting FONT to", fontfolder)
    common.makeFolder(fontfolder)
    with common.Stream(fontin, "rb", False) as f:
        for i in range(charnum):
            f.seek(i * 0x1a)
            char = str(i).zfill(4) + "_" + common.toHex(f.readUShort())
            currbit = 8
            data = 0
            img = Image.new("RGBA", (glyphwidth, glyphheight), (0, 0, 0, 255))
            pixels = img.load()
            for y in range(glyphheight):
                for x in range(glyphwidth):
                    if currbit == 8:
                        data = f.readByte()
                        currbit = 0
                    if (data >> (7 - currbit)) & 0x1 == 1:
                        pixels[x, y] = (255, 255, 255, 255)
                    currbit += 1
            img.save(fontfolder + char + ".png", "PNG")
    common.logMessage("Done!")
