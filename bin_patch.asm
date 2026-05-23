.nds

draw_char equ 0x020065d0
;This can be set to a lower value for English to speed up text rendering
;by only rendering the left half of a glyph. The original value is 0x10
MAX_GLYPH_WIDTH equ 0x10
;The new length for string buffers
BUFFER_MEM_SIZE equ 0x200
BUFFER_DIFF equ 0xd0
BUFFER_LENGTH equ 0x90

.open "LSuccessorsData/repack/arm9.bin",0x021e2700 - 0xd8160
  .orga 0xd8160
  .area 0x700

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
  ;repeat again 2 times for print_game_top_str
  ;this function can be called with a 0 or 1 parameter, to print on top or bottom screen
  ;this can actually happen at the same time as another normal print call
  ;or you can have both print_game_top_str(0) print_game_top_str(1) at the same time
  ;drawing 1 character at a time. This ensures there is no overlap for the VWF code
  .dw 0 :: .dw 0 :: .dw 0
  .dw 0 :: .dw 0 :: .dw 0

  .macro bin_reset,type,only_y
  push {r0-r1}
  mov r0,0x0
  ldr r1,=VWF_BIN_POS
  .if type == 0x2
    add r1,r1,0x4*3
    cmp r4,0x1
    addeq r1,r1,0x4*3
  .endif
  .if only_y == 0x0
    str r0,[r1]
  .endif
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
    cmp r4,0x1
    addeq r1,r1,0x4*3
  .endif
  str r0,[r1]
  ldr r0,[r1,0x4]
  add r0,r0,0x10
  str r0,[r1,0x4]
  pop {r0-r1}
  .endmacro

  .macro vwf_bin_call,type
  push {r1-r2}
  ldr r1,=VWF_BIN_POS
  mov r2,type
  str r2,[r1,0x8]
  ;store the type in both
  .if type == 0x2
    str r2,[r1,0x8+(0x4*3)]
    str r2,[r1,0x8+(0x4*6)]
  .endif
  pop {r1-r2}
  b VWF_BIN_FUNC
  .pool
  .endmacro

  VWF_BIN_RESET_FUNC:
  bin_reset 0x0,0x0

  VWF_BIN_LINE_FUNC:
  bin_line 0x0
  bx lr
  .pool

  VWF_BIN_FUNC:
  ;r0 = x position
  ;r1 = y position
  ;r2 = character
  ;script index by type: r5 / r6 / none / r7 / r6
  ;Load the VWF value
  push {r3-r6}
  ldr r3,=VWF_BIN_POS
  ldr r0,[r3,0x8]
  cmp r0,0x2
  addeq r3,r3,0x4*3
  cmpeq r4,0x1
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
  ;This one uses two separate structs
    ;We keep the counter for characters to print separated from the
    ;string pointer (r7) to correctly handle mixed ASCII/SJIS characters
    VWF_STOP_CHECK:
    .dw 0
    ;Count of newlines consumed in current print_game_top_str call
    ;Used to bail before drawing chars past the 2nd \n (textbox is 2 lines)
    VWF_NEWLINE_COUNT:
    .dw 0
    .macro increase_stop_check,amount
      push {r0-r1}
      ldr r0,=VWF_STOP_CHECK
      .if amount == 0x0
        mov r1,0x0
      .else
        ldr r1,[r0]
        add r1,r1,amount
      .endif
      str r1,[r0]
      pop {r0-r1}
    .endmacro

    VWF_BIN_START3:
    add r0,r2,r0
    increase_stop_check 0x0
    push {r0-r1}
    ldr r0,=VWF_NEWLINE_COUNT
    mov r1,0x0
    str r1,[r0]
    pop {r0-r1}
    cmp r2,0x0
    bxgt lr
    bin_reset 0x2,0x0
    .pool

    ;After consuming a \n, increment newline count. If we've seen 2, skip the
    ;rest of this frame's draw by jumping to LAB_0200735c so the extra
    ;byte after the 2nd \n never renders
    NL_END:
    push {r0-r1}
    ldr r0,=VWF_NEWLINE_COUNT
    ldr r1,[r0]
    add r1,r1,0x1
    str r1,[r0]
    cmp r1,0x2
    pop {r0-r1}
    blt @@cont
    b 0x0200735c
    @@cont:
    b 0x020071c4
    .pool

    VWF_BIN_LINEBREAK3:
    bin_line 0x2
    cmp r9,0xa
    bx lr
    .pool

    VWF_BIN3:
    vwf_bin_call 0x2

    VWF_INCREASE_STOP_CHECK:
    add r7,r7,0x1
    increase_stop_check 0x1
    bx lr
    .pool

    VWF_GET_STOP_CHECK:
    push {r0}
    ldr r0,=VWF_STOP_CHECK
    ldr r2,[r0]
    pop {r0}
    bx lr
    .pool

    ;Here we need to check r9, if it's ascii add 1 to r7 otherwise 2
    VWF_ADVANCE3:
    cmp r9,0x7f
    addgt r7,r7,0x2
    addle r7,r7,0x1
    increase_stop_check 0x1
    bx lr
    .pool

    ;Here we're breaking from the char reading loop, we need to decrease r7 by 1 if char is sjis
    VWF_CHECK_LIMIT3:
    cmp r9,0x7f
    subgt r7,r7,0x1
    b 0x020071f4


  ;0x02014e38/print_pre_game_str calls
    VWF_BIN_RESET4:
    mov r10,r0
    b VWF_BIN_RESET_FUNC

    VWF_BIN_LINEBREAK4:
    add r7,r7,0x1
    b VWF_BIN_LINE_FUNC

    VWF_BIN4:
    vwf_bin_call 0x3


  ;0x02035050/print_history_str calls
    VWF_BIN_RESET5:
    mov r10,r0
    b VWF_BIN_RESET_FUNC

    VWF_BIN_LINEBREAK5:
    add r6,r6,0x1
    b VWF_BIN_LINE_FUNC

    VWF_BIN5:
    vwf_bin_call 0x4
  
  ;Add a space when adding an extra letter in replace_cc_code
  REPLACE_CC_SPACE:
  mov r14,0x20
  strb r14,[r0,r1]
  add r1,r1,0x1
  mov r14,0x0
  b REPLACE_CC_SPACE_RET
  ;Same code for another location
  REPLACE_CC_SPACE2:
  mov r14,0x20
  strb r14,[r0,r1]
  add r1,r1,0x1
  mov r14,0x0
  b REPLACE_CC_SPACE_RET2

  ;check_text_codes4's final-copy path (LAB_02016238) copies bytes plainly
  ;and doesn't substitute \a, so <name> renders literally when parse_line_strings
  ;returns 0 (English strings with <2 newlines). This replaces that copy
  ;and calls FUN_02015e8c on 0x5c 0x61, mirroring path B's substitution
  CHECK_CODES4_FINAL_COPY:
  ldr r0,=0x020d8af4
  ldrb r0,[r0]
  cmp r0,0x2
  bne @@fallback
  ldr r0,=0x020d9af4
  ldrb r0,[r0,0x335]
  cmp r0,0x0
  bne @@fallback
  cmp r8,0x8
  bne @@fallback
  ;Substituting copy: src=r9+r10, dest=sp+8
  add r4,r9,r10
  add r5,sp,0x8
  mov r6,0x0
  @@loop:
  ldrb r0,[r4]
  strb r0,[r5,r6]
  cmp r0,0x0
  beq @@done
  cmp r0,0x5c
  bne @@advance
  ldrb r0,[r4,0x1]
  cmp r0,0x61
  bne @@advance
  ;FUN_02015e8c(dest_base=r5, dest_offset=r6, context_byte=DAT_020d8af6)
  mov r0,r5
  mov r1,r6
  ldr r12,=0x020d8af4
  ldrb r2,[r12,0x2]
  bl 0x02015e8c
  mov r6,r0
  add r4,r4,0x2
  b @@check_limit
  @@advance:
  add r6,r6,0x1
  add r4,r4,0x1
  @@check_limit:
  cmp r6,BUFFER_LENGTH
  blt @@loop
  @@done:
  b 0x02016268
  @@fallback:
  b 0x02016238
  .pool

  ;Path B in check_text_codes4 eagerly writes dest[r1+1] = src[r4+1] as a
  ;look-ahead each iteration. When the loop exits on r5 >= 2 (2 newlines), the
  ;last look-ahead byte is the first char of the next line, zero it here
  PATHB_NL_EXIT:
  mov r0,0x0
  strb r0,[r9,r1]
  b 0x02016210
  .pool

  ;strlen function that takes VWF into account
  ;r0 = pointer to string
  VWF_STRLEN:
  mov r2,0
  @@loop:
  ldrb r1,[r0],0x1
  cmp r1,0x0
  beq @@ret
  cmp r1,0x7f
  bgt @@sjis
  cmp r1,0x20
  blt @@sjis
  ldr r3,=SJIS_LOOKUP
  sub r1,r1,0x20
  lsl r1,r1,0x2
  add r1,r1,r3
  ldrb r1,[r1,0x2]
  add r2,r2,r1
  b @@loop
  @@sjis:
  add r2,r2,0xc
  add r0,r0,0x1
  b @@loop
  @@ret:
  mov r0,r2
  bx lr
  .pool


  ;History string, let's just hardcode it
  HISTORY_STR:
  mov r12,0x54 ;"T"
  strb r12,[r13,0x0]
  mov r12,0x75 ;"u"
  strb r12,[r13,0x1]
  mov r12,0x72 ;"r"
  strb r12,[r13,0x2]
  mov r12,0x6e ;"n"
  strb r12,[r13,0x3]
  mov r12,0x20 ;" "
  strb r12,[r13,0x4]
  mov r12,0xa ;line break at the end
  strb r12,[r13,0x7]
  bx lr

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

  ;This allocates space for 3 strings buffer, make it bigger
  .org 0x0200698c
    ;mov r0,0x130
    mov r0,BUFFER_MEM_SIZE
  ;These portion of memory decide how long a string buffer is
  ;The first 3 numbers are the max amount of (fixed-width) chars in a line
  ;The other numbers are the max amount of lines
  ;The max length ends up being (max_chars * max_lines + 3) * 2 + 2
  ;For example the 1st one is (0xd * 0x3 + 3) * 2 + 2 = 0x56
  ;The other ones are 0x38 and 0x78
  ;Let's set them all to BUFFER_LENGTH
  .org 0x0206ca90
    ;.dh 0xd
    .dh (BUFFER_LENGTH - 8) / 2
    ;.dh 0xc
    .dh (BUFFER_LENGTH - 8) / 2
    ;.dh 0xd
    .dh (BUFFER_LENGTH - 8) / 2
    ;.dh 0x3
    .dh 0x1
    ;.dh 0x2
    .dh 0x1
    ;.dh 0x4
    .dh 0x1
  ;Of course, these original lengths are also hardcoded in other places
  ;prepare_buffer
    .org 0x02006a6c
    ;cmp r6,0x5a
    cmp r6,BUFFER_LENGTH
    .org 0x02006a88
    ;strb r5,[r2,0x5a]
    strb r5,[r2,BUFFER_LENGTH]
    .org 0x02006a8c
    ;cmp r3,0x38
    cmp r3,BUFFER_LENGTH
    .org 0x02006aa8
    ;strb r2,[r3,0x92]
    strb r2,[r3,BUFFER_LENGTH*2]
    .org 0x02006aac
    ;cmp r5,0x78
    cmp r5,BUFFER_LENGTH
  ;copy_str
    .org 0x02006d78
    ;strb r8,[r1,0x5a]
    strb r8,[r1,BUFFER_LENGTH]
    .org 0x02006dcc
    ;strb r7,[r1,0x5a]
    strb r7,[r1,BUFFER_LENGTH]
    .org 0x02006e44
    ;strb r8,[r1,0x92]
    strb r8,[r1,BUFFER_LENGTH*2]
    .org 0x02006e98
    ;strb r14,[r1,0x92]
    strb r14,[r1,BUFFER_LENGTH*2]
  ;read_byte
    .org 0x02006fc4
    ;ldrsb r0,[r0,0x5a]
    ldrb r0,[r0,BUFFER_LENGTH]
    .org 0x02006fe4
    ;ldrsb r0,[r0,0x92]
    ldrb r0,[r0,BUFFER_LENGTH*2]
  ;02006af8
    .org 0x02006b84
    ;strb r3,[r1,0x5a]
    strb r3,[r1,BUFFER_LENGTH]
    .org 0x02006bdc
    ;strb r3,[r1,0x92]
    strb r3,[r1,BUFFER_LENGTH*2]
  ;There's also several places that point at the end of this buffer
  ;These are the indexes and what we'll change them to:
  ;0x10a 2*3 bytes -> 0x1da
  ;0x110 2*3 bytes -> 0x1e0
  ;0x116 2*3 bytes -> 0x1e6
  ;0x11c 2*3 bytes -> 0x1ec
  ;0x122 1*3 bytes -> 0x1f2
  ;0x125 1*3 bytes -> 0x1f5
  ;0x128 1*3 bytes -> 0x1f8
  ;There's also an additional 4 bytes set at 0x12c -> 0x1fc  -- ends at 0x130 / 0x200
  ;Since the opcodes are generally divided in "add r,r,0x100" and "strh r,[r,0xa]" for example
  ;We can just change the first opcode to "add r,r,0x1d0"
  ;prepare_buffer
    .org 0x020069b8
    str r5,[r3,0x12c+BUFFER_DIFF]
    .org 0x020069e0
    add r7,r7,0x100+BUFFER_DIFF
    .org 0x02006a00
    add r7,r7,0x100+BUFFER_DIFF
    .org 0x02006a10
    add r7,r7,0x100+BUFFER_DIFF
    .org 0x02006a20
    add r7,r7,0x100+BUFFER_DIFF
    .org 0x02006a30
    strb r6,[r7,0x122+BUFFER_DIFF]
    .org 0x02006a3c
    strb r6,[r7,0x125+BUFFER_DIFF]
    .org 0x02006a4c
    strb r2,[r7,0x128+BUFFER_DIFF]
  ;copy_str
    .org 0x02006c98
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006cc0
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006cd4
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006d30
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006d5c
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006d88
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006d9c
    add r12,r6,0x100+BUFFER_DIFF
    .org 0x02006dfc
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006e28
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006e54
    add r14,r7,0x100+BUFFER_DIFF
    .org 0x02006e68
    add r12,r6,0x100+BUFFER_DIFF
    .org 0x02006ec8
    add r14,r14,0x100+BUFFER_DIFF
    .org 0x02006eec
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x02006f00
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006f14
    strb r6,[r1,0x122+BUFFER_DIFF]
    .org 0x02006f24
    strb r0,[r1,0x125+BUFFER_DIFF]
    .org 0x02006f34
    strb r2,[r1,0x128+BUFFER_DIFF]
  ;02006af8
    .org 0x02006b14
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006b3c
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006b68
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006b94
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006bc0
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006bec
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02006c10
    add r2,r2,0x100+BUFFER_DIFF
    .org 0x02006c24
    add r2,r2,0x100+BUFFER_DIFF
    .org 0x02006c34
    strb r1,[r2,0x122+BUFFER_DIFF]
    .org 0x02006c40
    strb r1,[r2,0x125+BUFFER_DIFF]
    .org 0x02006c4c
    strb r12,[r0,0x128+BUFFER_DIFF]
  ;print_game_top_str
    .org 0x0200700c
    ldrb r1,[r1,0x122+BUFFER_DIFF]
    .org 0x02007024
    add r2,r1,0x100+BUFFER_DIFF
    .org 0x02007044
    add r3,r0,0x11c+BUFFER_DIFF
    .org 0x0200704c
    ldr r0,[r0,0x12c+BUFFER_DIFF]
    .org 0x02007064
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x02007104
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02007140
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x0200719c
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x020071d0
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x0200726c
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x0200729c
    ldrb r3,[r1,0x128+BUFFER_DIFF]
    .org 0x02007304
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x02007330
    ldrb r3,[r1,0x128+BUFFER_DIFF]
  ;02007370
    .org 0x0200737c
    ldrb r1,[r1,0x122+BUFFER_DIFF]
    .org 0x02007390
    add r0,r0,0x100+BUFFER_DIFF
  ;print_game_str
    .org 0x020073d4
    ldrb r0,[r1,0x125+BUFFER_DIFF]
    .org 0x020073e4
    ldrb r0,[r1,0x122+BUFFER_DIFF]
    .org 0x020073f8
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x02007450
    add r1,r1,0x100+BUFFER_DIFF
    .org 0x02007490
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x020074c8
    ldrb r3,[r1,0x128+BUFFER_DIFF]
    .org 0x02007524
    add r2,r2,0x100+BUFFER_DIFF
    .org 0x0200754c
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x0200757c
    ldrb r2,[r1,0x128+BUFFER_DIFF]
    .org 0x020075c4
    add r0,r0,0x100+BUFFER_DIFF
    .org 0x020075e4
    strb r1,[r0,0x125+BUFFER_DIFF]
    

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
  ;Increase char limit for print_history_str
    .org 0x0203515c
    ;cmp r5,0x90
    cmp r5,0xff

  ;Increase char limit for check_text_codes1
    .org 0x02014860
    ;sub r13,r13,0x74
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x02014950
    ;cmp r5,0x37
    cmp r5,BUFFER_LENGTH
    .org 0x02014974
    ;add r13,r13,0x74
    add r13,r13,BUFFER_LENGTH+0x10

  ;Increase char limit for check_text_codes2
    .org 0x02014b78
    ;sub r13,r13,0x44
    sub r13,r13,BUFFER_LENGTH
    .org 0x02014ba0
    ;cmp r2,0x44
    cmp r2,BUFFER_LENGTH
    .org 0x02014e10
    ;cmp r8,0x22
    cmp r8,BUFFER_LENGTH
    .org 0x02014e24
    ;add r13,r13,0x44
    add r13,r13,BUFFER_LENGTH

  ;Increase char limit for check_text_codes3
    .org 0x02015708
    ;sub r13,r13,0x58
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x020158e4
    ;cmp r8,0x29
    cmp r8,BUFFER_LENGTH
    .org 0x0201591c
    ;add r13,r13,0x58
    add r13,r13,BUFFER_LENGTH+0x10

  ;Increase char limit for check_text_codes4
    .org 0x02015f84
    ;sub r13,r13,0x40
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x02015fac
    ;cmp r1,0x36
    cmp r1,BUFFER_LENGTH
    .org 0x020161d8
    ;cmp r6,0x1b
    cmp r6,BUFFER_LENGTH
    .org 0x02016258
    ;cmp r3,0x36
    cmp r3,BUFFER_LENGTH
    .org 0x02016338
    ;add r13,r13,0x40
    add r13,r13,BUFFER_LENGTH+0x10

  ;Increase char limit for 020159fc
    .org 0x02015a00
    ;sub r13,r13,0x58
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x02015aa4
    ;cmp r2,0x53
    cmp r2,BUFFER_LENGTH
    .org 0x02015acc
    ;add r13,r13,0x58
    add r13,r13,BUFFER_LENGTH+0x10
  ;Increase char limit for 020155dc
    .org 0x020155e0
    ;sub r13,r13,0x58
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x020156bc
    ;cmp r2,0x53
    cmp r2,BUFFER_LENGTH
    .org 0x020156e8
    ;add r13,r13,0x58
    add r13,r13,BUFFER_LENGTH+0x10
  ;Increase char limit for 02015464
    .org 0x02015468
    ;sub r13,r13,0x58
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x02015540
    ;cmp r2,0x53
    cmp r2,BUFFER_LENGTH
    .org 0x02015564
    ;add r13,r13,0x58
    add r13,r13,BUFFER_LENGTH+0x10
  ;Increase char limit for 020153e0
    .org 0x020153e4
    ;sub r13,r13,0x58
    sub r13,r13,BUFFER_LENGTH+0x10
    .org 0x02015438
    ;cmp r2,0x53
    cmp r2,BUFFER_LENGTH
    .org 0x0201545c
    ;add r13,r13,0x58
    add r13,r13,BUFFER_LENGTH+0x10

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

  ;The function at 02015f28 checks strings 2 bytes at a time and checks for a line break only on the first char
  ;Since it assumes 2-bytes characters. Check just 1 byte at a time
  .org 0x02015f70
  ;add r1,r1,0x2
  add r1,r1,0x1
  ;Same for check_text_codes1
  .org 0x02014944
  ;add r1,r1,0x2
  add r1,r1,0x1
  ;add r6,r6,0x2
  add r6,r6,0x1
  ;Same for check_text_codes2
  .org 0x02014e04
  ;add r6,r6,0x2
  add r6,r6,0x1
  ;add r7,r7,0x2
  add r7,r7,0x1
  ;Same for check_text_codes3
  .org 0x020158d4
  ;add r6,r6,0x2
  add r6,r6,0x1
  ;add r7,r7,0x2
  add r7,r7,0x1
  ;Same for check_text_codes4
  .org 0x020161cc
  ;add r1,r1,0x2
  add r1,r1,0x1
  ;add r4,r4,0x2
  add r4,r4,0x1

  ;Redirect the parse_line_strings==0 branch in check_text_codes4 from the
  ;plain final-copy at LAB_02016238 to our function
  .org 0x02016128
  ;beq 0x02016238
  beq CHECK_CODES4_FINAL_COPY

  ;Path B's look-ahead leaves a stale byte (first char of next line) in the
  ;chunk buffer when exiting on 2 newlines, handle it here
  .org 0x02016194
  ;bge 0x02016210
  bge PATHB_NL_EXIT

  ;Patch strlen call for nameplates to call our function
  .org 0x0204cb90
  ;bl 0x02067084
  bl VWF_STRLEN
  ;Don't multiply by 0xc here, we already return the adjusted length
  .org 0x0204cba4
  ;mov r0,0xc
  mov r0,0x1
  ;Also don't divide by 2 here
  .org 0x0204cba0
  ;mov r1,r0,asr 0x1
  mov r1,r0

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
  
    ;Multiply by 4 in this check for max length
    .org 0x020075cc
    ;cmp r5,r0
    cmp r5,r0,lsl 0x2


  ;BIN print function at 0x02006ff0 (print_game_top_str)
    ;Set r8 to 0 here to avoid skipping characters at line end
    .org 0x0200712c
    ;mov r8,0x2
    mov r8,0x0

    .org 0x020072c4
    ;bl draw_char
    bl VWF_BIN3
    .org 0x02007138
    ;add r7,r7,0x2
    add r7,r7,0x1

    ;Break only on r9 being 0, don't check r10
    .org 0x020070e0
    ;cmpne r10,0x0
    nop
    ;Here if r9 is 0xa we need to line break, also don't check r10
    .org 0x0200724c
    ;cmpne r9,0x0
    bleq VWF_BIN_LINEBREAK3
    ;cmpne r10,0x0
    cmpne r9,0x0

    ;Don't divide by 2 in these 2 checks
    .org 0x0200715c
    ;cmp r0,r2,asr 0x1
    cmp r0,r2
    .org 0x020071ec
    ;cmp r0,r2,asr 0x1
    cmp r0,r2

    ;These hooks are for keeping the str pointer separated from the char
    ;counter and correctly handle mixed ASCII/SJIS characters
    .org 0x02007050
    ;add r0,r2,r0
    bl VWF_BIN_START3
    .org 0x02007138
    ;add r7,r7,0x2
    bl VWF_ADVANCE3
    .org 0x0200710c
    ;add r7,r7,0x1
    bl VWF_INCREASE_STOP_CHECK
    .org 0x0200714c
    ;add r2,r7,r7,lsr 0x1f
    bl VWF_GET_STOP_CHECK
    .org 0x020071d8
    ;add r2,r7,r7,lsr 0x1f
    bl VWF_GET_STOP_CHECK
    .org 0x02007164
    ;ble 0x020071f4
    ble VWF_CHECK_LIMIT3
    .org 0x02007200
    ;sub r1,r7,0x2
    sub r1,r7,0x1
    .org 0x02007210
    ;sub r1,r7,0x1
    mov r1,r7

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


  ;BIN print function at 0x02035050 (print_history_str)
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

  
  ;Change this strcpy function so it doesn't divide the result by 2
    .org 0x02006ee4
    ;mov r2,r0,asr 0x1
    mov r2,r0

  ;Move menu BIN lines a bit down
    CENTERING_TWEAK equ -0x2
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
  

  ;Tweak replace_cc_code to copy more bytes
  .org 0x020145f0
  ;cmp r14,0xb
  cmp r14,0x10
  ;Jump here to add a space
  .org 0x02014614
  ;mov r14,0x0
  b REPLACE_CC_SPACE
  REPLACE_CC_SPACE_RET:
  ;Same but for a different location
  .org 0x02015ee8
  ;mov r14,0x0
  b REPLACE_CC_SPACE2
  REPLACE_CC_SPACE_RET2:

  ;Change code characters cc/ar/nn/gr
  ;cc (0x63 0x63) -> \a (0x5c 0x61)
    .org 0x020148ac
    ;cmp r3,0x63
    cmp r3,0x5c
    .skip 4
    ;cmpeq r2,0x63
    cmpeq r2,0x61
    .org 0x02014d5c
    ;cmp r1,0x63
    cmp r1,0x5c
    .skip 4
    ;cmpeq r0,0x63
    cmpeq r0,0x61
    .org 0x020158a4
    ;cmp r2,0x63
    cmp r2,0x5c
    .skip 4
    ;cmpeq r0,0x63
    cmpeq r0,0x61
    .org 0x0201619c
    ;cmp r3,0x63
    cmp r3,0x5c
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
    .org 0x020148f4
    ;cmp r3,0x67
    cmp r3,0x5c
    .skip 4
    ;cmpeq r2,0x72
    cmpeq r2,0x6f
    .org 0x02014dac
    ;cmp r1,0x67
    cmp r1,0x5c
    .skip 4
    ;cmpeq r0,0x72
    cmpeq r0,0x6f
  
  ;Change replacements for nn -> \u code to ASCII
    .org 0x0206cadc
    .asciiz "0_"
    .org 0x0206caa4
    .asciiz "1_"
    .org 0x0206cab8
    .asciiz "2_"
    .org 0x0206cac8
    .asciiz "3_"
    .org 0x0206cacc
    .asciiz "4_"
    .org 0x0206cad8
    .asciiz "5_"
    .org 0x0206cae4
    .asciiz "6_"
    .org 0x0206cab4
    .asciiz "7_"
    .org 0x0206cae0
    .asciiz "8_"
    .org 0x0206caec
    .asciiz "9_"
  
  ;Change replacements for ar -> \e and cc -> \a code to ASCII
    .org 0x0206cad0
    .asciiz "A_"
    .org 0x0206caf0
    .asciiz "B_"
    .org 0x0206cabc
    .asciiz "C_"
    .org 0x0206cab0
    .asciiz "D_"
    .org 0x0206caa0
    .asciiz "E_"
    .org 0x0206caf8
    .asciiz "F_"
    .org 0x0206ca9c
    .asciiz "G_"
    .org 0x0206caa8
    .asciiz "H_"
    .org 0x0206caf4
    .asciiz "I_"
    .org 0x0206cac4
    .asciiz "J_"
  

  ;Change print_history_turn to use ASCII
  ;The new one will be "Turn xx|"
    .org 0x02035200
    ;strb r3,[r13]
    strb r3,[r13,0x5]
    .org 0x02035210
    ;strb r0,[r13,0x1]
    nop
    .org 0x0203521c
    ;strb r4,[r13,0x2]
    strb r4,[r13,0x6]
    .org 0x02035224
    ;strb r12,[r13,0x3]
    nop
    ;strb r3,[r13,0x4]
    nop
    ;strb r2,[r13,0x5]
    nop
    ;strb r14,[r13,0x6]
    bl HISTORY_STR
  ;Change replacements to ASCII
    .org 0x0209b904
    .asciiz "0"
    .org 0x0209b900
    .asciiz "1"
    .org 0x0209b8fc
    .asciiz "2"
    .org 0x0209b8f8
    .asciiz "3"
    .org 0x0209b8f4
    .asciiz "4"
    .org 0x0209b8f0
    .asciiz "5"
    .org 0x0209b8ec
    .asciiz "6"
    .org 0x0209b8e8
    .asciiz "7"
    .org 0x0209b8e4
    .asciiz "8"
    .org 0x0209b8e0
    .asciiz "9"

.close
