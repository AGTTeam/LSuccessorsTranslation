import codecs
import game
from hacktools import common, nds

binin = "data/extract/arm9.bin"
scriptfile = "data/script_output.txt"
binfile = "data/bin_output.txt"
pointerranges = [(0xa2a34, 0xba5b4, False), (0x6cb44, 0x786a4, True)]


def run():
    common.logMessage("Extracting BIN to", binfile, "...")
    # Read the lines
    strings, positions = nds.extractBinaryStrings(binin, game.binrange, game.detectEncodedString)
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
                            binstr = strings[pointertostr[pointer]]
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
            binstr = strings[pointertostr[pointer]]
            if pointer not in found and binstr != "|" and binstr not in donestr:
                donestr.append(binstr)
                out.write(binstr + "=\n")
    common.logMessage("Done! Extracted", len(strings), "lines")
