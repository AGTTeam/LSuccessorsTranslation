import os
import click
import game
from hacktools import common, nds, nitro

version = "0.8.0"
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
        nitro.extractIMG(data + "extract_DATA/", data + "out_IMG/", [".NCGR", ".ICHR"], game.readImage)


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
        nitro.repackIMG(data + "work_IMG/", data + "extract_DATA/", data + "repack_DATA/", [".NCGR", ".ICHR"], game.readImage, game.writeImage)
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


if __name__ == "__main__":
    common.setupTool("LSuccessorsTranslation", version, data, romfile, 0x4a620f90)
