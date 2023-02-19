import codecs
import game
from hacktools import common

pointerranges = [(0xa2a34, 0xba5b4, False), (0x6cb44, 0x786a4, True)]


def extract(data):
    binin = data + "extract/arm9.bin"
    tfile = data + "out_translations/ja-JP.xliff"

    common.logMessage("Extracting BIN to", tfile, "...")
    t = common.TranslationFile()
    # Read the lines
    strings, positions = common.extractBinaryStrings(binin, game.binrange, game.detectEncodedString)
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
                    binstr, pre, post = formatString(strings[pointertostr[pointer]])
                    if binstr.endswith("\\p\\E") or binstr.endswith("\\p\\P"):
                        binstr = binstr[:-4]
                    elif binstr.endswith("\\p"):
                        binstr = binstr[:-2]
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
            binstr, pre, post = formatString(strings[pointertostr[pointer]])
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


def formatString(binstr):
    post = pre = ""
    binstr = binstr.replace("\\p\\P", ">>")
    binstr = binstr.replace("\\p\\E", "<end>")
    binstr = binstr.replace("\\n", "|")
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
    return binstr, pre, post
