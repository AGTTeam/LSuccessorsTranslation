.nds

draw_char equ 0x020065d0
;This can be set to a lower value for English to speed up text rendering
;by only rendering the left half of a glyph. The original value is 0x10
MAX_GLYPH_WIDTH equ 0x10

.open "LSuccessorsData/repack/arm9.bin",0x021e2600 - 0xd8160
  .orga 0xd8160
  .area 0x600

  ;ASCII to SJIS lookup table, also includes VWF values
  SJIS_LOOKUP:
  .import "LSuccessorsData/fontdata.bin"
  .align

  LOAD_ASCII:
  push {r3-r4}
  ldrb r3,[r2,r0]
  ;If the character is ASCII and different from \, convert it to SJIS
  cmp r3,0x7f
  bgt @@sjis
  cmp r3,0x20
  blt @@sjis
  cmp r3,0x5c
  beq @@sjis
  ldr r0,=SJIS_LOOKUP
  sub r3,r3,0x20
  lsl r3,r3,0x2
  add r0,r0,r3
  ldrb r3,[r0]
  ldrb r4,[r0,0x1]
  ;Load the char length in r7
  ldrb r7,[r0,0x2]
  mov r0,r3,lsl 8
  orr r0,r0,r4
  ;Increase the script counter by 1
  add r1,r1,0x1
  ldr r3,[r9,0x20]
  add r3,r3,0x1
  str r3,[r9,0x20]
  pop {r3-r4}
  b DRAW_SCRIPT_CHARACTER
  @@sjis:
  ;Load the sjis character in r2, but backwards
  add r0,r0,0x1
  ldrb r2,[r2,r0]
  lsl r2,r2,0x8
  orr r2,r2,r3
  ;Set char length to 0xc
  mov r7,0xc
  ;Increase the script counter by 2
  add r1,r1,0x2
  ldr r3,[r9,0x20]
  add r3,r3,0x2
  str r3,[r9,0x20]
  pop {r3-r4}
  b LOAD_ASCII_RET

  READ_CHARCODE:
  push {r2}
  ldrb r2,[r1,r0]
  add r0,r0,0x1
  ldrb r0,[r1,r0]
  lsl r0,r0,0x8
  orr r0,r0,r2
  pop {r2}
  bx lr

  VWF_BIN_POS:
  .dw 0 ;xpos
  .dw 0 ;ypos
  .dw 0 ;type
  ;repeat again for print_game_top_str since this prints at the same time
  ;and one character at a time
  .dw 0 :: .dw 0 :: .dw 0

  .macro bin_reset,type
  push {r0-r1}
  mov r0,0x0
  ldr r1,=VWF_BIN_POS
  .if type == 0x2
    add r1,r1,0x4*3
  .endif
  str r0,[r1]
  str r0,[r1,0x4]
  pop {r0-r1}
  bx lr
  .pool
  .endmacro

  .macro bin_line,type
  push {r0-r1}
  mov r0,0x0
  ldr r1,=VWF_BIN_POS
  .if type == 0x2
    add r1,r1,0x4*3
  .endif
  str r0,[r1]
  ldr r0,[r1,0x4]
  add r0,r0,0x10
  str r0,[r1,0x4]
  pop {r0-r1}
  bx lr
  .pool
  .endmacro

  .macro vwf_bin_call,type
  push {r1-r2}
  ldr r1,=VWF_BIN_POS
  mov r2,type
  str r2,[r1,0x8]
  ;store the type in both
  .if type == 0x2
    str r2,[r1,0x8+(0x4*3)]
  .endif
  pop {r1-r2}
  b VWF_BIN_FUNC
  .pool
  .endmacro

  VWF_BIN_RESET_FUNC:
  bin_reset 0

  VWF_BIN_LINE_FUNC:
  bin_line 0

  VWF_BIN_FUNC:
  ;r0 = x position
  ;r1 = y position
  ;r2 = character
  ;script index by type: r5 / r6 / r7? / r7 / r6
  ;Load the VWF value
  push {r3-r6}
  ldr r3,=VWF_BIN_POS
  ldr r0,[r3,0x8]
  cmp r0,0x2
  addeq r3,r3,0x4*3
  ldr r0,[r3]
  ldr r1,[r3,0x4]
  ;Get the original character ((r2 >> 8) & 0xf)
  mov r6,r2
  lsr r6,0x8
  cmp r6,0x7f
  bgt @@sjis
  ;If the character is ascii, convert it to sjis
  ldr r5,=SJIS_LOOKUP
  sub r6,r6,0x20
  lsl r6,r6,0x2
  add r5,r5,r6
  ldrb r4,[r5]
  ldrb r6,[r5,0x1]
  mov r2,r4,lsl 8
  orr r2,r2,r6
  ;Load the correct VWF value and add it to the VWF counter
  ldrb r6,[r5,0x2]
  add r4,r0,r6
  str r4,[r3]
  ;TODO: type 2?
  ;ldr r4,[r3,0x8]
  ;cmp r4,0x2
  ;subeq r7,r7,0x1
  pop {r3-r6}
  b draw_char
  @@sjis:
  ;Add 0xc to the VWF counter and move on
  add r4,r0,0xc
  str r4,[r3]
  pop {r3-r6}
  ;Use r0 to increase the script counter depending on the type
  ;We only need to do this for sjis characters
  push {r0}
  ldr r0,=VWF_BIN_POS
  ldr r0,[r0,0x8]
  cmp r0,0x0
  addeq r5,r5,0x1
  beq @@ret
  cmp r0,0x1
  addeq r6,r6,0x1
  beq @@ret
  ;TODO: type 2?
  ;cmpne r0,0x2
  ;addeq r7,r7,0x1
  ;beq @@ret
  cmp r0,0x3
  addeq r7,r7,0x1
  beq @@ret
  cmp r0,0x4
  addeq r6,r6,0x1
  @@ret:
  pop {r0}
  b draw_char
  .pool

  ;0x020067b8/parse_string calls
  VWF_BIN_RESET:
  mov r9,r3
  b VWF_BIN_RESET_FUNC

  VWF_BIN_LINEBREAK:
  add r5,r5,0x1
  b VWF_BIN_LINE_FUNC

  VWF_BIN:
  vwf_bin_call 0x0


  ;0x020073bc/print_game_str calls
  VWF_BIN_RESET2:
  mov r10,r0
  b VWF_BIN_RESET_FUNC

  VWF_BIN_LINEBREAK2:
  add r6,r6,0x1
  b VWF_BIN_LINE_FUNC

  VWF_BIN2:
  vwf_bin_call 0x1


  ;0x02006ff0/print_game_top_str calls
  ;This one uses a separate struct
  VWF_BIN_RESET3:
  bin_reset 0x2

  VWF_BIN_LINEBREAK3:
  add r7,r7,0x1
  bin_line 0x2

  VWF_BIN3:
  vwf_bin_call 0x2

  ;This is an additional check we do here since the
  ;next character might be 0
  VFW_CHECK_BIN3:
  push {r0-r1,lr}
  ;call read_byte
  mov r0,r4
  mov r1,r7
  bl 0x02006f98
  ;If it's 0xa we also need to check the next one
  cmp r0,0xa
  bne @@check_zero
  mov r0,r4
  add r1,r7,0x1
  bl 0x02006f98
  @@check_zero:
  cmp r0,0x0
  bleq VWF_BIN_RESET3
  pop {r0-r1,lr}
  cmp r8,0x1
  bx lr
  .pool


  ;0x02014e38/print_pre_game_str calls
  VWF_BIN_RESET4:
  mov r10,r0
  b VWF_BIN_RESET_FUNC

  VWF_BIN_LINEBREAK4:
  add r7,r7,0x1
  b VWF_BIN_LINE_FUNC

  VWF_BIN4:
  vwf_bin_call 0x3


  ;0x02035050/unk_print_str calls
  VWF_BIN_RESET5:
  mov r10,r0
  b VWF_BIN_RESET_FUNC

  VWF_BIN_LINEBREAK5:
  add r6,r6,0x1
  b VWF_BIN_LINE_FUNC

  VWF_BIN5:
  vwf_bin_call 0x4

  .endarea
.close

.open "LSuccessorsData/repack/arm9.bin",0x02000000
  ;Load 2 bytes at a time, possibly unaligned, instead of using ldrh
  .org 0x0204c9c8
  ;mov r0,r1,lsl 0x1
  mov r0,r1
  ;ldrh r2,[r2,r0]
  b LOAD_ASCII
  LOAD_ASCII_RET:

  .org 0x0204cd80
  DRAW_SCRIPT_CHARACTER:

  ;Increase char limit for count_lines
  .org 0x0201445c
  ;cmp r2,0x72
  cmp r2,0xff

  ;Increase char limit for parse_string
  .org 0x0200682c
  ;mul r0,r4,r0
  mov r0,0xff

  ;Increase char limit for print_pre_game_str
  .org 0x02014f84
  ;cmp r6,0x3c
  cmp r6,0xff

  ;Replace the BIN rendering function
  .org 0x0200646c
  .area 0x11c,0x0
    push {r3-r11,lr}
    ;Load font_vram in r8
    ldr r5,=0x020d859c ;font_ptr
    ldr r6,[r5,0x4]
    ldr r6,[r6]
    ldr r5,[r13,0x28] ;char_index
    mov r8,0x1a
    mla r8,r5,r8,r6
    add r8,r8,0x2
    ;Load the byte we need to write in r10
    mov r10,0xe
    .macro render_text
    ;Load ypos_vram in r12
    add r12,r3,r4,lsr 0x1d
    mov r12,r12,asr 0x3
    mov r12,r12,lsl 0x4
    mul r4,r1,r12
    add r12,r0,r4,lsl 0x1
    ;Load xpos_vram in r11 (=r2/8*32)
    mov r11,r2,lsr 0x3
    mov r11,r11,lsl 0x5
    ;Register setup
    ;r0 = vram ptr
    ;r1 = row counter
    ;r2 = col counter
    ;r3 = font data
    ;r4 = current shifted bits
    ;r5 = amount of cols to skip in the first tile (xpos % 8)
    ;r6 = amount of rows to skip in the first tile (ypos % 8)
    mov r1,0x0
    mov r5,0b111
    and r5,r2,r5
    mov r6,0b111
    and r6,r3,r6
    @@row_loop:
      ;Reset the vram ptr and add row*4
      add r0,r12,r11
      lsl r2,r1,0x2
      add r0,r0,r2
      ;If row >= 8-r6, go to the tile below (+0x400)
      mov r7,0x8
      sub r7,r7,r6
      cmp r1,r7
      addge r0,r0,0x400
      ;-4*r7 to start back from the first row
      subge r0,r0,r7,lsl 0x2
      ;If we're in the first vertical tile, skip r6*4 rows
      addlt r0,r0,r6,lsl 0x2
      ;Prepare r4 and shift left by r5*4
      mov r4,r10
      lsl r2,r5,0x2
      lsl r4,r4,r2
      ;Load the font data and start looping columns
      ldrb r3,[r8],0x1
      mov r2,0x0
        @@col_loop:
        ;Check if we need to move to the next tile
        add r7,r5,r2
        cmp r7,0x8
        addeq r0,r0,0x20
        moveq r4,r10
        cmp r7,0x10
        addeq r0,r0,0x20
        moveq r4,r10
        ;Check if the font bit is filled in
        tst r3,0b10000000
        ldrne r9,[r0]
        orrne r9,r4
        strne r9,[r0]
        ;Shift r4/r3 and move to the next column
        ;If r2 == 8 load more font bits
        lsl r4,r4,0x4
        lsl r3,r3,0x1
        add r2,r2,0x1
        cmp r2,0x8
        ldreqb r3,[r8],0x1
        cmp r2,MAX_GLYPH_WIDTH
        blt @@col_loop
      add r1,r1,0x1
      cmp r1,0xc
      blt @@row_loop
    .endmacro
    render_text
    pop {r3-r11,lr}
    bx lr
    .pool
  .endarea
  
  ;Replace the script rendering function
  .org 0x0204c7a0
  .area 0x16c,0x0
    ;We don't really need to re-invent the wheel, we can just adjust registers and call the bin macro
    ;r2 is a ptr to a struct containing most of the info we need
    mov r10,r2
    ;r1 = const 0x20
    mov r1,0x20
    ;r8 = font_vram
    mov r8,r3
    ;r0 = r4 = vram_ptr
    ldr r0,[r10,0x14]
    mov r4,r0
    ;r3 = ypos
    ldr r3,[r10,0x28]
    ;r2 = xpos
    ldr r2,[r10,0x24]
    ;r10 = bytes we need to write (handles colors)
    ldr r10,[r10,0x3c]
    ;Call the macro and return
    render_text
    add sp,sp,0x24
    pop {r4-r11,pc}
    .pool
  .endarea

  ;There's several places where the code reads codes supposing they're aligned, so we need to edit them all
  ;As well as increasing the script counter by 2
  .org 0x0204ccc0
  add r0,r0,0x2
  .org 0x0204cccc
  sub r0,r0,0x2
  bl READ_CHARCODE

  .org 0x0204cce8
  add r0,r0,0x2
  .org 0x0204ccf4
  sub r0,r0,0x2
  bl READ_CHARCODE

  .org 0x0204cc90
  add r0,r0,0x2
  .org 0x0204cc9c
  sub r0,r0,0x2
  bl READ_CHARCODE

  .org 0x0204cb38
  add r0,r0,0x2
  .org 0x0204cb44
  sub r0,r0,0x2
  bl READ_CHARCODE

  .org 0x0204cbe0
  add r0,r0,0x2
  .org 0x0204cbec
  sub r0,r0,0x2
  bl READ_CHARCODE

  .org 0x0204cd18
  add r0,r1,0x2 ;this is different from the other ones
  .org 0x0204cd24
  sub r0,r0,0x2
  bl READ_CHARCODE

  .org 0x0204cd40
  add r0,r0,0x2
  .org 0x0204cd4c
  sub r0,r0,0x2
  bl READ_CHARCODE

  ;Don't increase here
  .org 0x0204cd74
  ;add r0,r0,0x1
  nop

  ;Don't increase the counter here since we're already doing it in LOAD_ASCII
  .org 0x0204cdec
  ;add r0,r0,0x1
  nop

  ;This is the check for the line end, don't increase the counter here
  .org 0x0204d248
  ;add r0,r0,0x2
  nop
  ;But increase it here to check the next one, only reading 1 byte since it's just checking for 0
  .org 0x0204d268
  ;mov r0,r0,lsl 0x1
  add r0,r0,0x2
  ;ldrh r1,[r1,r0]
  ldrb r1,[r1,r0]


  ;BIN print function at 0x020067b8 (parse_string)
  .org 0x020067c8
  ;mov r9,r3
  bl VWF_BIN_RESET

  .org 0x02006878
  ;add r5,r5,0x1
  bl VWF_BIN_LINEBREAK

  .org 0x020068d8
  ;bl draw_char
  bl VWF_BIN
  ;add r5,r5,0x2
  add r5,r5,0x1

  ;Break only on r6 being 0, don't check r0
  .org 0x0200685c
  ;cmpne r0,0x0
  nop

  ;BIN print function at 0x020073bc (print_game_str)
  .org 0x020073c8
  ;mov r10,r0
  bl VWF_BIN_RESET2

  .org 0x02007458
  ;add r6,r6,0x1
  bl VWF_BIN_LINEBREAK2

  .org 0x020074f0
  ;bl draw_char
  bl VWF_BIN2
  ;add r6,r6,0x2
  add r6,r6,0x1

  ;Break only on r7 being 0, don't check r8
  .org 0x02007434
  ;cmpne r8,0x0
  nop


  ;BIN print function at 0x02006ff0 (print_game_top_str)
  .org 0x0200710c
  ;add r7,r7,0x1
  ;bl VWF_BIN_LINEBREAK3

  .org 0x020072c4
  ;bl draw_char
  ;bl VWF_BIN3
  ;cmp r8,0x1
  ;bl VFW_CHECK_BIN3
  .org 0x02007138
  ;add r7,r7,0x2
  ;add r7,r7,0x1

  ;Break only on r9 being 0, don't check r10, jump to reset instead
  .org 0x020070e0
  ;cmpne r10,0x0
  ;bleq VWF_BIN_RESET3


  ;BIN print function at 0x02014e38 (print_pre_game_str)
  .org 0x02014e44
  ;mov r10,r0
  bl VWF_BIN_RESET4

  .org 0x02014e90
  ;add r7,r7,0x1
  bl VWF_BIN_LINEBREAK4

  .org 0x02014ef8
  ;bl draw_char
  bl VWF_BIN4
  ;add r7,r7,0x2
  add r7,r7,0x1

  ;Break only on r1 being 0, don't check r0
  .org 0x02014e64
  ;cmpne r0,0x0
  nop


  ;BIN print function at 0x02035050 (unk_print_str)
  .org 0x0203505c
  ;mov r10,r0
  bl VWF_BIN_RESET5

  .org 0x020350a0
  ;add r6,r6,0x1
  bl VWF_BIN_LINEBREAK5

  .org 0x02035100
  ;bl draw_char
  bl VWF_BIN5
  ;add r6,r6,0x2
  add r6,r6,0x1

  ;Braek only on r1 being 0, don't check r0
  .org 0x02035078
  ;cmpne r0,0x0
  nop


  ;Move menu BIN lines a bit up
  CENTERING_TWEAK equ 0x5
  ;Function at 0x020144a4
  .org 0x020144b8
  ;mvn r4,0x61
  mvn r4,0x61-CENTERING_TWEAK
  ;Function at 0x020149d0
  .org 0x020149e0
  ;mvn r4,0x61
  mvn r4,0x61-CENTERING_TWEAK
  ;Function at 0x02015000
  .org 0x02015018
  ;mvn r5,0x61
  mvn r5,0x61-CENTERING_TWEAK
  ;Function at 0x0202fc70
  .org 0x0202fc7c
  ;mvn r4,0x61
  mvn r4,0x61-CENTERING_TWEAK
  ;Function at 0x02039c68
  .org 0x02039df0
  ;mvn r0,0x2f
  mvn r0,0x2f-CENTERING_TWEAK
  ;Function at 0x0203a040
  .org 0x0203a04c
  ;mvn r0,0x2f
  mvn r0,0x2f-CENTERING_TWEAK
  ;Function at 0x0203a5d4
  .org 0x0203a5e0
  ;mvn r0,0x3b
  mvn r0,0x3b-CENTERING_TWEAK
  ;Function at 0x0203b57c
  .org 0x0203b67c
  ;mvn r0,0x2f
  mvn r0,0x2f-CENTERING_TWEAK
  ;Function at 0x0203b57c
  .org 0x0203b8a0
  ;mvn r0,0x2f
  mvn r0,0x2f-CENTERING_TWEAK


  ;Change code characters cc/ar/nn/gr
  ;cc (0x63 0x63) -> \a (0x5c 0x61)
  .org 0x020148ac
  ;cmp r3,0x63
  cmp r3,0x5c
  .skip 4
  ;cmpeq r2,0x63
  cmpeq r2,0x61
  .org 0x02014d5c
  ;cmp r2,0x63
  cmp r2,0x5c
  .skip 4
  ;cmpeq r0,0x63
  cmpeq r0,0x61

  ;ar (0x61 0x72) -> \e (0x5c 0x65)
  .org 0x020148d0
  ;cmp r3,0x61
  cmp r3,0x5c
  .skip 4
  ;cmpeq r2,0x72
  cmpeq r2,0x65
  .org 0x02014d84
  ;cmp r1,0x61
  cmp r1,0x5c
  .skip 4
  ;cmpeq r0,0x72
  cmpeq r0,0x65

  ;nn (0x6e 0x6e) -> \u (0x5c 0x75)
  .org 0x02014918
  ;cmp r3,0x6e
  cmp r3,0x5c
  .skip 4
  ;cmpeq r0,0x6e
  cmpeq r0,0x75
  .org 0x02014dd4
  ;cmp r1,0x6e
  cmp r1,0x5c
  .skip 4
  ;cmpeq r0,0x6e
  cmpeq r0,0x75

  ;gr (0x67 0x72) -> \o (0x5c 0x6f)
  .org 0x02014dac
  ;cmp r1,0x67
  cmp r1,0x5c
  .skip 4
  ;cmpeq r0,0x72
  cmpeq r0,0x6f
.close
