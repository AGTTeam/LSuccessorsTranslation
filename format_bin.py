import codecs
import game
from hacktools import common

pointerranges = [(0xa2a34, 0xba5b4, False), (0x6cb44, 0x786a4, True)]


def extract(data):
    binin = data + "extract/arm9.bin"
    scriptfile = data + "script_output.txt"
    binfile = data + "bin_output.txt"

    common.logMessage("Extracting BIN to", binfile, "...")
    # Read the lines
    strings, positions = common.extractBinaryStrings(binin, game.binrange, game.detectEncodedString)
    pointertostr = {}
    for i in range(len(positions)):
        for pos in positions[i]:
            pointertostr[pos] = i
    # Try to detect the strings in the correct order
    found = []
    with codecs.open(binfile, "w", "utf-8") as out:
        with codecs.open(scriptfile, "w", "utf-8") as script:
            with common.Stream(binin, "rb") as f:
                for pointerrange in pointerranges:
                    f.seek(pointerrange[0])
                    donestr = []
                    while f.tell() < pointerrange[1]:
                        pos = f.tell()
                        pointer = f.readUInt() - 0x02000000
                        if pointer not in pointertostr:
                            pointer += 1
                        if pointer in pointertostr:
                            binstr, pre, post = formatString(strings[pointertostr[pointer]])
                            if binstr.endswith("\\p\\E") or binstr.endswith("\\p\\P"):
                                binstr = binstr[:-4]
                            elif binstr.endswith("\\p"):
                                binstr = binstr[:-2]
                            found.append(pointer)
                            if not pointerrange[2]:
                                donestr.append(binstr)
                                script.write(binstr + "=\n")
                            elif binstr not in donestr:
                                donestr.append(binstr)
                                if binstr.endswith("|"):
                                    binstr = binstr[:-1]
                                out.write(binstr + "=\n")
        # Extract the rest
        donestr = []
        for pointer in pointertostr:
            binstr, pre, post = formatString(strings[pointertostr[pointer]])
            if pointer not in found and binstr != "|" and binstr not in donestr:
                donestr.append(binstr)
                out.write(binstr + "=\n")
    common.logMessage("Done! Extracted", len(strings), "lines")


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
