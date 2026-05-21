import os
import click
import game
from editor import EditorApp
from hacktools import common, nds, nitro

version = "1.0.0"
data = "LSuccessorsData/"
romfile = "dn2.nds"
rompatch = data + "dn2_patched.nds"
infolder = data + "extract/"
replacefolder = data + "replace/"
outfolder = data + "repack/"
bannerfile = data + "repack/banner.bin"
patchfile = data + "patch.xdelta"


@common.cli.command()
@click.option("--rom", is_flag=True, default=False)
@click.option("--bin", is_flag=True, default=False)
@click.option("--font", is_flag=True, default=False)
@click.option("--img", is_flag=True, default=False)
def extract(rom, bin, font, img):
    all = not rom and not bin and not font and not img
    if all or rom:
        nds.extractRom(romfile, infolder, outfolder)
        import format_archive
        format_archive.extract(data)
    if all or bin:
        import format_bin
        format_bin.extract(data)
    if all or font:
        import format_font
        format_font.extract(data)
    if all or img:
        nitro.extractIMG(data + "extract_DATA/", data + "out_IMG/", [".NCGR", ".ICHR"], game.readImage1)


@common.cli.command()
@click.option("--no-rom", is_flag=True, default=False, hidden=True)
@click.option("--bin", is_flag=True, default=False)
@click.option("--font", is_flag=True, default=False)
@click.option("--img", is_flag=True, default=False)
def repack(no_rom, bin, font, img):
    all = not bin and not img and not font
    if all or font:
        import format_font
        format_font.repack(data)
    if all or img:
        import format_palette
        format_palette.repack(data)
        nitro.repackIMG(data + "work_IMG/", data + "extract_DATA/", data + "repack_DATA/", [".NCGR", ".ICHR"], game.readImage2, game.writeImage)
    if all or img or font:
        import format_archive
        format_archive.repack(data)
    if all or bin or font:
        import format_bin
        format_bin.repack(data)
    if not no_rom:
        if os.path.isdir(replacefolder):
            common.mergeFolder(replacefolder, outfolder)
        nds.editBannerTitle(bannerfile, "DEATH NOTE\n~Successors to L~\nKonami Digital Entertainment")
        nds.repackRom(romfile, rompatch, outfolder, patchfile)


@common.cli.command(hidden=True)
def quantize():
    import format_palette
    workquant = data + "work_IMG/"
    outquant = data + "quantized_TEMP/"

    groups = {}
    group_colors = {}
    for palfile, mainpng in game.palettereplace.items():
        prefix = os.path.splitext(mainpng)[0]
        effective = game.ipal_effective_colors.get(palfile)
        if effective is not None:
            cur = group_colors.get(prefix)
            group_colors[prefix] = effective if cur is None else min(cur, effective)
        if prefix in groups:
            continue
        files = format_palette.collectImageVariants(workquant, mainpng)
        if files:
            groups[prefix] = files

    if not os.path.isdir(outquant):
        os.makedirs(outquant)

    for prefix, files in groups.items():
        group_n = group_colors.get(prefix, 256)
        common.logMessage("Quantizing group " + prefix + " (" + str(len(files)) + " images, " + str(group_n) + " colors)")
        temp_combined = outquant + "_tmp_combined_" + prefix + ".png"
        temp_palette = outquant + "_tmp_palette_" + prefix + ".png"
        try:
            quoted_files = " ".join('"' + f + '"' for f in files)
            common.execute('magick convert -append ' + quoted_files + ' "' + temp_combined + '"', show=False)
            common.execute('pngquant --speed 3 ' + str(group_n) + ' "' + temp_combined + '" --output "' + temp_palette + '" --force', show=False)
            for filepath in files:
                outpath = outquant + os.path.basename(filepath)
                common.execute('magick convert "' + filepath + '" +dither -remap "' + temp_palette + '" "' + outpath + '"', show=False)
        finally:
            if os.path.isfile(temp_combined):
                os.remove(temp_combined)
            if os.path.isfile(temp_palette):
                os.remove(temp_palette)

    common.logMessage("Done!")


@common.cli.command(hidden=True)
def editor():
    app = EditorApp(version)
    app.mainloop()


if __name__ == "__main__":
    common.setupTool("LSuccessorsTranslation", version, data, romfile, 0x4a620f90)
