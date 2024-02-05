//===============================================================
// KERNAL : C64 Kernal usefull calls and OS specific values
//===============================================================

#importonce

//---------------------------------------------------------------
// C64 Kernal usefull calls and OS specific values
//---------------------------------------------------------------

.label CHROUT = $FFD2
.label GETIN  = $FFE4
.label SETNAM = $FFBD
.label SETLFS = $ffba
.label LOAD   = $ffd5
.label SECOND = $ff93
.label TKSA   = $ff96
.label acptr  = $ffa5
.label CIOUT  = $ffa8
.label UNTALK = $ffab
.label UNLSTN = $ffae
.label LISTEN = $ffb1
.label TALK   = $ffb4
.label READST = $ffb7
.label OPEN   = $ffc0
.label CLOSE  = $ffc3
.label CHKIN  = $ffc6
.label CHKOUT = $ffc9
.label CLRCHN = $ffcc
.label CHRIN  = $ffcf
.label SAVE   = $ffd8
.label CLALL  = $ffe7
.label IECIN  = $ffa5
.label UNTLK  = $FFAB
.label CLEARSCREEN = $E544

.label STATUS       = $90
.label MEMIO        = $35
.label MEMSTD       = $37
.label MEMIOKERNAL  = $36
.label ST           = $90
.label CURSOR_ONOFF = 204
.label CURSOR_STATUS = 207
.label CURSOR_COLOR = 646
