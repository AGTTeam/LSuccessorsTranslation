import os
import click
import archive
import game
from hacktools import common, nds, nitro

version = "0.1.0"
romfile = "data/dn2.nds"
rompatch = "data/dn2_patched.nds"
infolder = "data/extract/"
replacefolder = "data/replace/"
outfolder = "data/repack/"
bannerfile = "data/repack/banner.bin"
patchfile = "data/patch.xdelta"


@common.cli.command()
@click.option("--rom", is_flag=True, default=False)
@click.option("--bin", is_flag=True, default=False)
@click.option("--img", is_flag=True, default=False)
def extract(rom, bin, img):
    all = not rom and not bin and not img
    if all or rom:
        nds.extractRom(romfile, infolder, outfolder)
        archive.extract()
    if all or bin:
        import extract_bin
        extract_bin.run()
    if all or img:
        # nitro.extractIMG("data/extract_DATA/", "data/out_IMG/", [".NCGR", ".ICHR"], game.readImage)
        nitro.extractIMG("data/extract_DATA/", "data/out_IMG/", ".ICHR", game.readImage)


@common.cli.command()
@click.option("--no-rom", is_flag=True, default=False)
@click.option("--bin", is_flag=True, default=False)
@click.option("--img", is_flag=True, default=False)
def repack(no_rom, bin, img):
    # all = not bin and not img
    if not no_rom:
        if os.path.isdir(replacefolder):
            common.mergeFolder(replacefolder, outfolder)
        nds.editBannerTitle(bannerfile, "DEATH NOTE\n~Successors to L~\nKonami Digital Entertainment")
        nds.repackRom(romfile, rompatch, outfolder, patchfile)


if __name__ == "__main__":
    click.echo("LSuccessorsTranslation version " + version)
    if not os.path.isdir("data"):
        common.logError("data folder not found.")
        quit()
    common.cli()
