.nds

draw_char equ 0x020065d0

.open "LSuccessorsData/repack/arm9.bin",0x021e2600 - 0xd8160
  .orga 0xd8160
  .area 0x300

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
  add r7,r7,0x2
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
  .dw 0
  .dw 0

  .macro reset_vwf
  push {r0-r1}
  mov r0,0x0
  ldr r1,=VWF_BIN_POS
  str r0,[r1]
  str r0,[r1,0x4]
  pop {r0-r1}
  .endmacro

  .macro vwf_line
  push {r0-r1}
  mov r0,0x0
  ldr r1,=VWF_BIN_POS
  str r0,[r1]
  ldr r0,[r1,0x4]
  add r0,r0,0x1
  str r0,[r1,0x4]
  pop {r0-r1}
  .endmacro

  VWF_BIN_RESET:
  reset_vwf
  mov r9,r3
  bx lr
  .pool

  VWF_BIN_LINEBREAK:
  vwf_line
  add r5,r5,0x1
  bx lr
  .pool

  VWF_BIN:
  ;r0 = x position
  ;r1 = y position
  ;r2 = character
  ;r6 = original character if ascii
  ;Load the VWF value
  push {r3-r5}
  ldr r3,=VWF_BIN_POS
  ldr r0,[r3]
  ldr r1,[r3,0x4]
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
  add r6,r6,0x2
  add r4,r0,r6
  str r4,[r3]
  pop {r3-r5}
  b draw_char
  @@sjis:
  ;Add 0xc to the VWF counter and move on
  add r4,r0,0xc
  str r4,[r3]
  pop {r3-r5}
  add r5,r5,0x1
  b draw_char
  .pool

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
  .org 0x0204cd74
  add r0,r0,0x2

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
.close
