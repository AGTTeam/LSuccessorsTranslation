import codecs
import customtkinter
import json
import os
import tkinter
from PIL import Image
from hacktools import common
import format_bin


class CustomTextBox(customtkinter.CTkTextbox):
    def insert(self, index, text, tags=None):
        if not hasattr(self, "oldtext"):
            self.oldtext = text.strip()
            self.callback(self.lbl, self.oldtext)
        return super().insert(index, text, tags)

    def _check_if_scrollbars_needed(self, event=None, continue_loop: bool = False):
        super()._check_if_scrollbars_needed(event, continue_loop)
        if not hasattr(self, "oldtext") or not hasattr(self, "lbl"):
            return
        currenttext = self._textbox.get(1.0, tkinter.END).strip()
        if currenttext != self.oldtext:
            self.oldtext = currenttext
            self.callback(self.lbl, currenttext)


class EditorOptions:
    def __init__(self, cursor="bin///605461", usebg=2):
        self.cursor = cursor
        self.usebg = usebg


class EditorFrame(customtkinter.CTkScrollableFrame):
    def __init__(self, master, **kwargs):
        super().__init__(master, **kwargs)
        self.usebg = 0
        self.currentoff = -1
        self.alltexts = []
        self.chartolen = {}
        self.chartosjis = {}
        self.glyphs = {}
        self.font = {}
        self.backgrounds = []
        self.start = []
        self.wordwrap = []
        self.lineheight = []
        
        originalfontpath = "LSuccessorsData/extract_FONT/"
        workfontpath = "LSuccessorsData/work_FONT/"
        fontconfig = "LSuccessorsData/fontconfig.txt"

        self.backgrounds.append(Image.open("backgrounds/story_00.png").convert("RGBA"))
        self.start.append((30, 31))
        self.wordwrap.append(format_bin.wordwrap)
        self.lineheight.append(0xc)
        self.backgrounds.append(Image.open("backgrounds/menu_00.png").convert("RGBA"))
        self.start.append((48, 37))
        self.wordwrap.append(format_bin.wordwrap2)
        self.lineheight.append(0x10)
        self.backgrounds.append(Image.open("backgrounds/gametop_00.png").convert("RGBA"))
        self.start.append((72, 20))
        self.wordwrap.append(format_bin.wordwrap3)
        self.lineheight.append(0x10)
        self.backgrounds.append(Image.open("backgrounds/gamebottom_00.png").convert("RGBA"))
        self.start.append((16, 25))
        self.wordwrap.append(format_bin.wordwrap3)
        self.lineheight.append(0x10)
        self.backgrounds.append(Image.open("backgrounds/fullscreen_00.png").convert("RGBA"))
        self.start.append((28, 20))
        self.wordwrap.append(format_bin.wordwrap)
        self.lineheight.append(0xc)

        with codecs.open(fontconfig, "r", "utf-8") as input:
            section = common.getSection(input, "", inorder=True)
            currentchar = 0x20
            for fontlen in section:
                charid = fontlen["name"].replace("～", "〜")
                charlen = int(fontlen["value"])
                self.chartolen[charid] = charlen
                self.chartosjis[chr(currentchar)] = charid
                self.glyphs[chr(currentchar)] = common.FontGlyph(0, charlen, charlen)
                self.glyphs[charid] = common.FontGlyph(0, charlen, charlen)
                currentchar += 1

        for fontimg in common.getFiles(originalfontpath, ".png"):
            char = common.codeToChar(int(fontimg.replace(".png", "").split("_")[1], 16), "cp932", False)
            fontpng = originalfontpath + fontimg
            if os.path.isfile(workfontpath + fontimg):
                fontpng = workfontpath + fontimg
            self.font[char] = Image.open(fontpng).convert("RGBA")
            pixels = self.font[char].load()
            for y in range(self.font[char].height):
                for x in range(self.font[char].width):
                    if pixels[x, y] == (0, 0, 0, 255):
                        pixels[x, y] = (0, 0, 0, 0)
    
    def extendImage(self, img):
        old_img = img
        img = Image.new("RGBA", (old_img.width, old_img.height + self.backgrounds[self.usebg].height))
        img.paste(old_img, (0, 0))
        img.paste(self.backgrounds[self.usebg], (0, old_img.height))
        return img

    def generateImage(self, lbl, text):
        img = self.backgrounds[self.usebg].copy()
        startx = self.start[self.usebg][0]
        starty = self.start[self.usebg][1]
        currentx = startx
        currenty = starty
        if "#" in text:
            text = text.split("#")[0]
        wordwrapped = common.wordwrap(text, self.glyphs, self.wordwrap[self.usebg], format_bin.detectTextCode, strip=False)
        if wordwrapped.count("<<") > 0:
            wordwrapped = common.centerLines(wordwrapped, self.glyphs, format_bin.centering, format_bin.detectTextCode, default=0xc, linebreak="|", centercode="<<")
        if wordwrapped.count(">>") == 0:
            if wordwrapped.count("|") > 1 and self.usebg == 2:
                img = self.extendImage(img)
            if wordwrapped.count("|") > 3 and self.usebg == 2:
                img = self.extendImage(img)
        i = 0
        while i < len(wordwrapped):
            c = wordwrapped[i]
            c = c.replace("ï", "$")
            c = c.replace("‘", "[")
            c = c.replace("’", "]")
            c = c.replace("“", "{")
            c = c.replace("”", "}")
            c = c.replace("～", "〜")
            if c == "#":
                break
            if c == ">" and wordwrapped[i+1] == ">":
                i += 2
                currentx = startx
                currenty = img.height + starty
                img = self.extendImage(img)
                continue
            if c == "<":
                textcode = wordwrapped[i:].split(">", 1)[0]
                i += len(textcode) + 1
                continue
            if c == "\\" and (wordwrapped[i+1] == "T" or wordwrapped[i+1] == "t"):
                i += 6
                continue
            if c == "\\" and (wordwrapped[i+1] == "c" or wordwrapped[i+1] == "S"):
                i += 4
                continue
            if c == "|":
                currentx = startx
                if self.usebg == 2 and currenty == starty + self.lineheight[self.usebg]:
                    currenty = self.backgrounds[self.usebg].height + starty
                elif self.usebg == 2 and currenty == self.backgrounds[self.usebg].height + starty + self.lineheight[self.usebg]:
                    currenty = self.backgrounds[self.usebg].height * 2 + starty
                else:
                    currenty += self.lineheight[self.usebg]
                i += 1
                continue
            if c in self.chartosjis:
                # ASCII character, use VWF
                c = self.chartosjis[c]
                charwidth = self.chartolen[c]
            else:
                charwidth = 0xc
            c = c.replace("～", "〜")
            if c not in self.font:
                common.logMessage("Char not found", c)
                currentx += 0xc
                i += 1
                continue
            charglyph = self.font[c]
            img.paste(charglyph, (currentx, currenty), charglyph)
            currentx += charwidth
            i += 1
        ctkimg = customtkinter.CTkImage(dark_image=img, size=(img.width, img.height))
        lbl.configure(image=ctkimg)
        lbl.image = ctkimg


    def loadLines(self, section, id):
        for child in self.winfo_children():
            child.destroy()
        self.alltexts = []
        row = 0
        self.idfile = id.split("///")[0]
        self.idoff = int(id.split("///")[1])
        try:
            self.currentoff = section.offsets[self.idfile].index(self.idoff)
        except ValueError:
            self.currentoff = -1
            return
        for i in range(10):
            original = section.offlookup[section.offsets[self.idfile][self.currentoff + i]]
            frame = customtkinter.CTkFrame(self)
            frame.grid(row=row, column=0, padx=10, pady=2)
            lbl = customtkinter.CTkLabel(frame, text="")
            lbl.grid(row=0, column=0, padx=10, pady=5)
            text = CustomTextBox(frame, width=400, height=65)
            text.lbl = lbl
            text.callback = self.generateImage
            text.insert(tkinter.END, section.getEntry(original, self.idfile, section.offsets[self.idfile][self.currentoff + i]))
            text.grid(row=0, column=1, padx=10, pady=5)
            text2 = customtkinter.CTkTextbox(frame, width=400, height=65)
            text2.insert(tkinter.END, original)
            text2.grid(row=0, column=2, padx=10, pady=5)
            text2.configure(state="disabled")  
            self.alltexts.append((text, text2))
            row += 1


class EditorApp(customtkinter.CTk):
    def __init__(self, version):
        super().__init__()
        self.title("LSuccessorsTranslation v" + version + " Editor")
        self.choices = ["story", "menu", "gametop", "gamebottom", "fullscreen"]
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=0)
        self.grid_rowconfigure(1, weight=1)
        self.options = EditorOptions()
        self.configdir = os.path.expanduser("~/.hacktools/")
        self.appname = "LSuccessorsTranslationEditor"
        if not os.path.isdir(self.configdir):
            common.makeFolder(self.configdir)
        if not os.path.isfile(self.configdir + self.appname + ".json"):
            self.saveOptions()
        else:
            self.loadOptions()

        self.section = common.TranslationFile("LSuccessorsData/translations/en-US.xliff")
        self.section.preloadLookup("#ignore#comments")
        self.section.preloadOffsets()

        self.topframe = customtkinter.CTkFrame(self, height=35, corner_radius=0)
        self.topframe.grid(row=0, column=0, padx=10, pady=0, sticky="nw")
        self.topframe.grid_columnconfigure(0, weight=1)
        self.loadtext = customtkinter.CTkLabel(self.topframe, text="Load lines from:")
        self.loadtext.grid(row=0, column=0, padx=10, pady=2)
        self.loadid = customtkinter.CTkTextbox(self.topframe, width=120, height=35)
        self.loadid.grid(row=0, column=1, padx=10, pady=2)
        self.loadid.insert(tkinter.END, self.options.cursor)
        self.loadbutton = customtkinter.CTkButton(self.topframe, border_width=2, width=70, text="Load", command=self.load)
        self.loadbutton.grid(row=0, column=2, padx=10, pady=2)
        self.savebutton = customtkinter.CTkButton(self.topframe, border_width=2, width=70, text="Save", command=self.save)
        self.savebutton.grid(row=0, column=3, padx=10, pady=2)
        self.prevbutton = customtkinter.CTkButton(self.topframe, border_width=2, width=70, text="Prev", command=self.prev)
        self.prevbutton.grid(row=0, column=4, padx=10, pady=2)
        self.nextbutton = customtkinter.CTkButton(self.topframe, border_width=2, width=70, text="Next", command=self.next)
        self.nextbutton.grid(row=0, column=5, padx=10, pady=2)
        self.texttype = customtkinter.CTkLabel(self.topframe, text="Line type:")
        self.texttype.grid(row=0, column=6, padx=10, pady=2)
        self.bgcombo = customtkinter.CTkOptionMenu(self.topframe, values=self.choices, command=self.changebg)
        self.bgcombo.grid(row=0, column=7, padx=10, pady=0)
        self.editorframe = EditorFrame(master=self, width=256+400+400+50, height=600, corner_radius=0, fg_color="transparent")
        self.editorframe.grid(row=1, column=0, sticky="nsew")
        self.load()

    def loadOptions(self):
        with open(self.configdir + self.appname + ".json", "r") as f:
            data = f.read()
        try:
            options = json.loads(data)
            self.options = EditorOptions(**options)
        except (json.decoder.JSONDecodeError, TypeError):
            self.options = EditorOptions()
            self.saveOptions()

    def saveOptions(self):
        with open(self.configdir + self.appname + ".json", "w") as f:
            f.write(json.dumps(self.options.__dict__, indent=2))

    def load(self):
        self.save()
        newcursor = self.loadid.get(1.0, tkinter.END).strip()
        self.editorframe.loadLines(self.section, newcursor)
        self.options.cursor = newcursor
        self.saveOptions()

    def prev(self):
        if self.editorframe.currentoff == -1 or self.editorframe.currentoff < 10:
            return
        self.save()
        offset = self.section.offsets[self.editorframe.idfile][self.editorframe.currentoff - 10]
        self.loadid.delete(1.0, tkinter.END)
        self.loadid.insert(tkinter.END, self.editorframe.idfile + "///" + str(offset))
        self.load()

    def next(self):
        if self.editorframe.currentoff == -1 or self.editorframe.currentoff + 10 > len(self.section.offsets[self.editorframe.idfile]):
            return
        self.save()
        offset = self.section.offsets[self.editorframe.idfile][self.editorframe.currentoff + 10]
        self.loadid.delete(1.0, tkinter.END)
        self.loadid.insert(tkinter.END, self.editorframe.idfile + "///" + str(offset))
        self.load()

    def save(self):
        if len(self.editorframe.alltexts) > 0:
            for i in range(10):
                offset = self.section.offsets[self.editorframe.idfile][self.editorframe.currentoff + i]
                original = self.section.offlookup[offset]
                self.section.setEntry(original, self.editorframe.idfile, offset, self.editorframe.alltexts[i][0]._textbox.get(1.0, tkinter.END).strip().replace("\r\n", "|").replace("\n", "|"))
            self.section.save("LSuccessorsData/translations/en-US.xliff")

    def changebg(self, choice):
        self.editorframe.usebg = self.choices.index(choice)
        self.options.usebg = self.editorframe.usebg
        self.load()
