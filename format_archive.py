import codecs
import filecmp
import os
import game
from hacktools import common, nds

knownformats = {"RNAN": "NANR", "RECN": "NCER", "RGCN": "NCGR", "RLCN": "NCLR", "ICHR": "ICHR", "IPAL": "IPAL", "ISCR": "ISCR"}


def repack(data, no_recolor=False):
    infile = data + "extract/data/data/data.bin"
    outfile = data + "repack/data/data/data.bin"
    filelist = data + "filelist.txt"
    outfolder = data + "extract_DATA/"
    workfolder = data + "repack_DATA/"
    replacefolder = data + "replace_DATA/"

    common.logMessage("Repacking DATA ...")
    if os.path.isdir(replacefolder):
        common.mergeFolder(replacefolder, workfolder)
    excluded = set(game.recolorFiles(outfolder)) if no_recolor else set()
    if excluded:
        common.logMessage("Skipping recolor for " + str(len(excluded)) + " files (--no-recolor)")
    filenum = 0x3cf9
    with codecs.open(filelist, "rb", "utf-8") as f:
        files = f.readlines()
    with common.Stream(infile, "rb") as fin:
        with common.Stream(outfile, "wb") as f:
            f.writeUInt(filenum)
            f.seek(0x1e7cc)
            for i in common.showProgress(range(filenum)):
                filename = files[i].split(",")[0]
                compressed = files[i].split(",")[1].strip() == "1"
                srcfolder = outfolder if filename in excluded else workfolder
                filepos = f.tell()
                with common.Stream(srcfolder + filename, "rb") as subf:
                    uncompdata = subf.read()
                    if compressed:
                        # Check if the file is different first to speed up things
                        if filecmp.cmp(srcfolder + filename, outfolder + filename, shallow=False):
                            fin.seek(4 + i * 8)
                            offset = fin.readUInt() * 4
                            length = fin.readUInt()
                            fin.seek(offset)
                            f.write(fin.read(length))
                        else:
                            f.write(nds.compress(uncompdata, nds.CompressionType.LZ10))
                        filesize = f.tell() - filepos
                    else:
                        f.write(uncompdata)
                        filesize = len(uncompdata)
                if f.tell() % 4 > 0:
                    f.writeZero(4 - (f.tell() % 4))
                f.writeUIntAt(4 + i * 8, filepos // 4)
                f.writeUIntAt(4 + i * 8 + 4, filesize)
    common.logMessage("Done!")


def extract(data):
    infile = data + "extract/data/data/data.bin"
    filelist = data + "filelist.txt"
    outfolder = data + "extract_DATA/"
    workfolder = data + "repack_DATA/"

    common.logMessage("Extracting DATA ...")
    common.makeFolder(outfolder)
    files = []
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
            if i != 5:
                # This is pretty messy and mostly guess-work
                if extension == "NCLR" or extension == "bin":
                    if i != 84 and i != 195:
                        filei += 1
                if extension == "NANR" and (i == 81 or i == 192):
                    filei += 1
                if extension == "IPAL" and ((i >= 196 and i < 2399) or (i > 2427 and i < 14865)):
                    if i != 14634:
                        filei += 1
                if extension == "ICHR" and ((i < 196) or (i >= 2399 and i < 2427) or (i == 14633) or (i >= 14865)):
                    filei += 1
            orig = filename = "file" + str(filei).zfill(5) + "." + extension
            if os.path.isfile(outfolder + filename):
                if extension == "NCGR" or extension == "ICHR" or extension == "ISCR" or extension == "NANR" or extension == "NCER":
                    j = 0
                    while os.path.isfile(outfolder + filename):
                        j += 1
                        filename = orig.replace("." + extension, "_" + str(j).zfill(4) + "." + extension)
                if os.path.isfile(outfolder + filename):
                    common.logWarning("Filename conflict:", i, filei, filename)
                    filename = filename.replace(".", "_conflict.")
                    if os.path.isfile(outfolder + filename):
                        filename = filename.replace(".", "2.")
                        if os.path.isfile(outfolder + filename):
                            common.logError("Filename conflict:", i, filei, filename)
            # Extract the file
            files.append(filename + (",1" if compbyte == 0x10 else ",0") + "\n")
            with common.Stream(outfolder + filename, "wb") as fout:
                fout.write(filedata)
    with codecs.open(filelist, "wb", "utf-8") as f:
        f.writelines(files)
    common.copyFolder(outfolder, workfolder)
    common.logMessage("Done!")
