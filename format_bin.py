import codecs
import os
import game
from hacktools import common, nds

binrange = [(445000, 884000)]
pointerranges = [(0xa2a34, 0xba5b4, False), (0x6cb44, 0x786a4, True)]
freeranges = [(0xd8160+0x700, 0xd8160+0x8c500, True)]
wordwrap = 190  # used for script lines
wordwrap2 = 160  # used for other lines
wordwrap3 = 152  # used for top-screen lines during gameplay
centering = 200  # used for centering lines starting with <<


def repack(data):
    binin = data + "extract/arm9.bin"
    binfile = data + "translations/en-US.xliff"
    binout = data + "repack/arm9.bin"
    headerin = data + "extract/header.bin"
    headerout = data + "repack/header.bin"

    # Create the font data file and prepare the glyph sizes for wordwrapping
    global glyphs
    glyphs = {}
    with codecs.open(data + "fontconfig.txt", "r", "utf-8") as f:
        section = common.getSection(f, "", inorder=True)
        with common.Stream(data + "fontdata.bin", "wb") as f:
            ascii = 0x20
            for c in section:
                charid = c["name"].replace("～", "〜").encode("cp932")
                if "," in c["value"]:
                    valuesplit = c["value"].split(",")
                    charlen = int(valuesplit[0])
                    glyphs[valuesplit[1]] = common.FontGlyph(0, charlen, charlen)
                else:
                    charlen = int(c["value"])
                f.write(charid)
                f.writeUShort(charlen)
                glyphs[chr(ascii)] = common.FontGlyph(0, charlen, charlen)
                glyphs[charid] = common.FontGlyph(0, charlen, charlen)
                glyphs[c["name"]] = common.FontGlyph(0, charlen, charlen)
                ascii += 1
            f.writeUShort(0)
            f.writeUShort(0xc)

    # Expand and repack the binary file
    nds.expandBIN(binin, binout, headerin, headerout, 0x8c500, 0x021e2700)
    injectoffset = 0x021e2700 - 0xd8160
    updatedranges = nds.repackBIN(binrange, freeranges, game.detectEncodedString, game.writeEncodedString, preformat=preFormatString, postformat=postFormatString, binin=binin, binout=binout, binfile=binfile, injectstart=injectoffset, nocopy=True)
    writeExtraStrings(data, binout, updatedranges, injectoffset)
    common.armipsPatch(common.bundledFile("bin_patch.asm"))


def writeExtraStrings(data, binout, updatedranges, injectoffset):
    extrafile = data + "extrastrings.txt"
    if not updatedranges or not os.path.isfile(extrafile):
        return
    injectrange = None
    for r in updatedranges:
        if len(r) >= 3 and r[2] is True:
            injectrange = r
            break
    if injectrange is None:
        common.logError("No inject freerange found for extra strings")
        return
    common.logMessage("Writing extra strings from", extrafile, "...")
    with codecs.open(extrafile, "r", "utf-8") as ef:
        section = common.getSection(ef, "", inorder=True)
    with common.Stream(binout, "r+b") as f:
        for entry in section:
            hexstr = entry["name"]
            s = postFormatString(entry["value"], "", "")
            ptrloc = int(hexstr.strip(), 16)
            if injectrange[0] >= injectrange[1]:
                common.logError("No room left in inject range for extra string", s)
                return
            f.seek(injectrange[0])
            startpos = f.tell()
            game.writeEncodedString(f, s, 0, "cp932")
            f.seek(-1, 1)
            if f.readByte() != 0:
                f.writeZero(1)
            injectrange[0] = f.tell()
            newptr = startpos + injectoffset
            f.seek(ptrloc - 0x02000000)
            f.writeUInt(newptr)
            common.logDebug("Wrote extra string at", common.toHex(startpos), "pointer at", common.toHex(ptrloc), "->", common.toHex(newptr))
    common.logMessage("Done!")


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


def preFormatString(binstr):
    post = pre = ""
    if binstr.endswith("|"):
        binstr = binstr[:-1]
        post = "|" + post
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


def detectTextCode(s, i=0):
    if s[i] == "<":
        return len(s[i:].split(">", 1)[0]) + 1
    if s[i] == "\\" and (s[i+1] == "T" or s[i+1] == "t"):
        return 6
    if s[i] == "\\" and (s[i+1] == "c" or s[i+1] == "S"):
        return 4
    return 0


def postFormatString(binstr, pre, post):
    global glyphs
    linebreak = "|"
    binstroriginal = binstr
    lbcount = binstr.count("|")
    if len(pre) > 0 and ord(pre[:1]) >= 0x30 and ord(pre[:1]) <= 0x39:
        binstr = common.wordwrap(binstr, glyphs, wordwrap3, detectTextCode, default=0xc)
    elif (binstr + post).endswith(">>") or (binstr + post).endswith("<end>") or (binstr + post).endswith("\\p"):
        binstr = common.wordwrap(binstr, glyphs, wordwrap, detectTextCode, default=0xc)
        binstr = binstr.replace("|", "\\n")
        linebreak = "\\n"
    elif "|" not in binstr and "\\n" not in binstr:
        binstr = common.wordwrap(binstr, glyphs, wordwrap2, detectTextCode, default=0xc, strip=False)
    if binstr.count("<<") > 0:
        binstr = common.centerLines(binstr, glyphs, centering, detectTextCode, default=0xc, linebreak=linebreak, centercode="<<")
        # Replace every 6 spaces with a Japanese one
        binstr = binstr.replace("      ", "　")
    if lbcount > 0 and binstr.count(linebreak) != lbcount:
        common.logWarning(f"Linebreak count mismatch {lbcount}/{binstr.count(linebreak)} {binstroriginal} -> {binstr}")
    binstr = pre + binstr + post
    binstr = binstr.replace(">>", "\\p\\P")
    binstr = binstr.replace("<end>", "\\p\\E")
    # These need to be replaced with other characters since cc/ar/nn/gr might be used in the scripts
    # See bin_patch.asm (;Change code characters cc/ar/nn/gr)
    binstr = binstr.replace("<num>", "\\u")
    binstr = binstr.replace("<group>", "\\o")
    binstr = binstr.replace("<name>", "\\a")
    binstr = binstr.replace("<area>", "\\e")
    common.logDebug(binstr)
    return binstr
