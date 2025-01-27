import codecs
import game
from hacktools import common, nds

binrange = [(445000, 884000)]
pointerranges = [(0xa2a34, 0xba5b4, False), (0x6cb44, 0x786a4, True)]
freeranges = [(0xd8160+0x300, 0xd8160+0x8c500, True)]


def repack(data, jp=False):
    binin = data + "extract/arm9.bin"
    binfile = data + "translations/en-US.xliff"
    binout = data + "repack/arm9.bin"
    headerin = data + "extract/header.bin"
    headerout = data + "repack/header.bin"

    # Create the font data file
    with codecs.open(data + "fontconfig.txt", "r", "utf-8") as f:
        section = common.getSection(f, "", inorder=True)
        with common.Stream(data + "fontdata.bin", "wb") as f:
            for c in section:
                f.write(c["name"].replace("～", "〜").encode("shift_jis"))
                f.writeUShort(int(c["value"]))
            f.writeUShort(0)
            f.writeUShort(0xc)
    # Expand and repack the binary file
    nds.expandBIN(binin, binout, headerin, headerout, 0x8c500, 0x021e2600)
    nds.repackBIN(binrange, freeranges, game.detectEncodedString, game.writeEncodedString, preformat=preFormatString, postformat=postFormatString, binin=binin, binout=binout, binfile=binfile, injectstart=0x021e2600-0xd8160, nocopy=True)
    common.armipsPatch(common.bundledFile("bin_patch.asm"))


def extract(data):
    binin = data + "extract/arm9.bin"
    tfile = data + "out_translations/ja-JP.xliff"

    common.logMessage("Extracting BIN to", tfile, "...")
    t = common.TranslationFile()
    # Read the lines
    strings, positions = common.extractBinaryStrings(binin, binrange, game.detectEncodedString)
    pointertostr = {}
    for i in range(len(positions)):
        for pos in positions[i]:
            pointertostr[pos] = i
    # Try to detect the strings in the correct order
    found = []
    with common.Stream(binin, "rb") as f:
        for pointerrange in pointerranges:
            f.seek(pointerrange[0])
            while f.tell() < pointerrange[1]:
                pos = f.tell()
                pointer = f.readUInt() - 0x02000000
                if pointer not in pointertostr:
                    pointer += 1
                if pointer in pointertostr and pointer not in found:
                    binstr, pre, post = preFormatString(strings[pointertostr[pointer]])
                    found.append(pointer)
                    if binstr == "" or binstr == "|":
                        continue
                    if not pointerrange[2]:
                        t.addEntry(binstr, "script", pointer)
                    else:
                        if binstr.endswith("|"):
                            binstr = binstr[:-1]
                        t.addEntry(binstr, "bin", pointer)
        # Extract the rest
        donestr = []
        for pointer in pointertostr:
            binstr, pre, post = preFormatString(strings[pointertostr[pointer]])
            if pointer not in found and binstr != "|":
                donestr.append(binstr)
                t.addEntry(binstr, "bin", pointer)
    t.save(tfile)
    common.logMessage("Done! Extracted", len(strings), "lines")


def merge(data):
    tfile = data + "out_translations/ja-JP.xliff"
    t = common.TranslationFile(tfile)
    t.mergeSection(data + "bin_input.txt")
    t.mergeSection(data + "script_input.txt")
    t.save(tfile.replace("ja-JP", "en-US"))


def preFormatString(binstr):
    post = pre = ""
    binstr = binstr.replace("\\p\\P", ">>")
    binstr = binstr.replace("\\p\\E", "<end>")
    binstr = binstr.replace("\\n", "|")
    binstr = binstr.replace("nn", "<num>")
    binstr = binstr.replace("gr", "<group>")
    binstr = binstr.replace("cc", "<name>")
    binstr = binstr.replace("ar", "<area>")
    if binstr.endswith("<end>"):
        binstr = binstr[:-5]
        post = "<end>" + post
    if binstr.endswith(">>"):
        binstr = binstr[:-2]
        post = ">>" + post
    if binstr.startswith("\\N"):
        pre = pre + binstr[:4]
        binstr = binstr[4:]
    if binstr.startswith("\\S"):
        pre = pre + binstr[:4]
        binstr = binstr[4:]
    if binstr.startswith("\\c"):
        pre = pre + binstr[:4]
        binstr = binstr[4:]
    if binstr.startswith("\\t"):
        pre = pre + binstr[:6]
        binstr = binstr[6:]
    if binstr.endswith("\\p"):
        binstr = binstr[:-2]
        post = "\\p" + post
    if len(binstr) > 0 and ord(binstr[:1]) >= 0x30 and ord(binstr[:1]) <= 0x39:
        pre = pre + binstr[:1]
        binstr = binstr[1:]
    return binstr, pre, post


def postFormatString(binstr, pre, post):
    binstr = pre + binstr + post
    binstr = binstr.replace(">>", "\\p\\P")
    binstr = binstr.replace("<end>", "\\p\\E")
    binstr = binstr.replace("|", "\\n")
    binstr = binstr.replace("<num>", "nn")
    binstr = binstr.replace("<group>", "gr")
    binstr = binstr.replace("<name>", "cc")
    binstr = binstr.replace("<area>", "ar")
    return binstr
