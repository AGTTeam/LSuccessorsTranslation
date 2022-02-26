import os
from hacktools import common, nds

knownformats = {"RNAN": "NANR", "RECN": "NCER", "RGCN": "NCGR", "RLCN": "NCLR", "ICHR": "ICHR", "IPAL": "IPAL", "ISCR": "ISCR"}


def extract(data):
    infile = data + "extract/data/data/data.bin"
    outfolder = data + "extract_DATA/"

    common.logMessage("Extracting DATA ...")
    common.makeFolder(outfolder)
    with common.Stream(infile, "rb") as f:
        filenum = f.readUInt()
        filei = 0
        for i in common.showProgress(range(filenum)):
            # Read offset and length
            f.seek(4 + i * 8)
            offset = f.readUInt() * 4
            length = f.readUInt()
            # Extract the file
            f.seek(offset)
            compbyte = f.peek(1)[0]
            if compbyte == 0x10:
                filedata = nds.decompress(f, length)
            else:
                filedata = f.read(length)
            # Read magic
            try:
                magic = filedata[:4].decode()
            except UnicodeDecodeError:
                magic = ""
            # Try to figure out the filename
            extension = "bin"
            if magic in knownformats:
                extension = knownformats[magic]
            if i == 4:
                filei += 1
            if extension == "NCLR" or (extension == "IPAL" and i >= 196) or (extension == "ICHR" and i < 196) or extension == "bin":
                if i != 5:
                    filei += 1
            orig = filename = "file" + str(filei).zfill(5) + "." + extension
            if os.path.isfile(outfolder + filename):
                if extension == "NCGR" or extension == "ICHR" or extension == "ISCR":
                    j = 0
                    while os.path.isfile(outfolder + filename):
                        j += 1
                        filename = orig.replace("." + extension, "_" + str(j).zfill(4) + "." + extension)
                if os.path.isfile(outfolder + filename):
                    common.logWarning("Filename conflict:", i, filei, filename)
                    continue
            # Extract the file
            with common.Stream(outfolder + filename, "wb") as fout:
                fout.write(filedata)
    common.logMessage("Done!")
