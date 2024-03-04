//===============================================================
// MACROS : ZP pseudo registers macros
//===============================================================

#importonce

//---------------------------------------------------------------
// ZP pseudo registers
// $39 -> $48 = r0 à r7
// ztmp en b0/b1 pour swap
//---------------------------------------------------------------

.label zr0 = $39
.label zr0l = zr0
.label zr0h = zr0+1
.label zr1 = zr0+2
.label zr1l = zr1
.label zr1h = zr1+1
.label zr2 = zr1+2
.label zr2l = zr2
.label zr2h = zr2+1
.label zr3 = zr2+2
.label zr3l = zr3
.label zr3h = zr3+1
.label zr4 = zr3+2
.label zr4l = zr4
.label zr4h = zr4+1
.label zr5 = zr4+2
.label zr5l = zr5
.label zr5h = zr5+1
.label zr6 = zr5+2
.label zr6l = zr6
.label zr6h = zr6+1
.label zr7 = zr6+2
.label zr7l = zr7
.label zr7h = zr7+1

.label zsrc=zr6
.label zdest=zr7
.label reg_zsrc=6
.label reg_zdest=7

.print "zsrc=$"+toHexString(zsrc)
.print "zdest=$"+toHexString(zdest)

.label ztmp = $b0
.label zsave = $b2

//===============================================================
// macros pour pstring, plist, ppath
//===============================================================

//---------------------------------------------------------------
// pstring : chaine de type pascal, avec 1er octet = longueur
//---------------------------------------------------------------

.macro pstring(chaine)
{
 .byte chaine.size()
 .text chaine
 //.print "pstring =[" + chaine + "] lgr=" + chaine.size()
}

//---------------------------------------------------------------
// plist : objet liste, manipule des éléments pstring
//---------------------------------------------------------------

.macro plist(ptr_work)
{
 nb_elem:     // nb d'éléments dans la liste
    .byte 0
 ptr_data:    // début des données
    .word ptr_work+1
 ptr_free:    // libre = après les données
    .word ptr_work+1
 ptr_last:    // dernier élément
    .word ptr_work+1
}

//---------------------------------------------------------------
// ppath : objet path après parsing
//
// format path :
// [<device>:][[<partition>][/ ou //<path>/]][:<filename>]
// device et partition à 0 si absent
// type path : présence des différents éléments dans le path
// bit 0 = présence device, bit 1 = présence partition
// bit 2 = présence path,   bit 3 = présence nom
//---------------------------------------------------------------

.namespace PPATH
{
    .label WITH_DEVICE=1
    .label WITH_PARTITION=2
    .label WITH_PATH=4
    .label WITH_NAME=8
}

.macro ppath(lgr_path)
{
type:
    .byte 0
    // device et partition
device:
    .byte 0
partition:
    .byte 0
    // path et nom
path:
    .byte 0
filename:
    .byte 0
    .fill (lgr_path - 5),0
}

//===============================================================
// Pseudo register macros
//---------------------------------------------------------------
// R0 -> R7 in ZP, starting at zr0 address
// Y is not always preserved, X is always preserved
//
// Parameters rule : 
//      destination = source 
// Naming rule : 
//      ST<ore>[R<egister>/W<ord>] to [R<egister>/W<ord>]
//===============================================================

//---------------------------------------------------------------
// <instruction>_<destination><source>
//
// instructions : mov, add, swp, inc
//
// destination / source :
//
// r = registre
// w = word
// a = accumumateur
// i = indirect
//
// mov_rw
// mov_wr
// add_ra
//---------------------------------------------------------------

//---------------------------------------------------------------
// stw_r(reg, word) : reg = word
// preserves Y
//
// mov r<n>, addr
//---------------------------------------------------------------

.macro stw_r(reg, word_param)
{
    lda #<word_param
    sta zr0l+2*reg
    lda #>word_param
    sta zr0h+2*reg
}

//---------------------------------------------------------------
// str_w(word, reg) : (word) = reg
// preserves Y
//
// mov addr, r<n>
//---------------------------------------------------------------

.macro str_w(word, reg)
{
 lda zr0l+2*reg
 sta word
 lda zr0h+2*reg
 sta word+1
}

//---------------------------------------------------------------
// getbyte(reg)   : A = byte(reg)
// getbyte_r(reg) : A = byte(reg), reg++
// Y should be 0
// devrait être getnextbyte / getbyte
// préprocesseur à voir : mov a,(r0) / mov a,(r0++)
//---------------------------------------------------------------

.macro getbyte_r(reg)
{
    lda (zr0+2*reg),y
    inc zr0l+2*reg
    bne pas_inc
    inc zr0h+2*reg
pas_inc:
}

.macro getbyte(reg)
{
    lda (zr0+2*reg),y
}

//---------------------------------------------------------------
// setbyte(reg)   : byte(reg) = A
// setbyte_r(reg) : byte(reg) = A, reg++
// Y should be 0
// devrait être setbyte / setnextbyte
// mov (r0), a et mov (r0++), a
//---------------------------------------------------------------

.macro setbyte_r(reg)
{
    sta (zr0+2*reg),y
    inc zr0l+2*reg
    bne pas_inc
    inc zr0h+2*reg
pas_inc:
}

.macro setbyte(reg)
{
    sta (zr0+2*reg),y
}

//---------------------------------------------------------------
// addi_r(reg) : reg += 8 bits immediate value
// Y preserved
// add reg, #<value>
//---------------------------------------------------------------

.macro addi_r(reg, value)
{
    clc
    lda #value
    adc zr0l+2*reg
    sta zr0l+2*reg
    bcc pas_inc
    inc zr0h+2*reg
pas_inc:    
}

//---------------------------------------------------------------
// addw_r(reg) : reg += 16 bits immediate value
// Y preserved
// add reg, #<value>
//---------------------------------------------------------------

.macro addw_r(reg, value)
{
    clc
    lda #<value
    adc zr0l+2*reg
    sta zr0l+2*reg
    lda zr0h+2*reg
    adc #>value
    sta zr0h+2*reg    
}

//---------------------------------------------------------------
// add_r(reg) : reg += A
// Y preserved
// add reg, a
//---------------------------------------------------------------

.macro add_r(reg)
{
    clc
    adc zr0l+2*reg
    sta zr0l+2*reg
    bcc pas_inc
    inc zr0h+2*reg
pas_inc:    
}

//---------------------------------------------------------------
// addr_r(regdest, reg) : regdest += reg
// Y preserved
// add regdest, reg
//---------------------------------------------------------------

.macro addr_r(regdest, reg)
{
    clc
    lda zr0l+2*regdest
    adc zr0l+2*reg
    sta zr0l+2*regdest
    lda zr0l+2*regdest+1
    adc zr0l+2*reg+1
    sta zr0l+2*regdest+1
}

//---------------------------------------------------------------
// add8(adr) : (adr) = (adr)+A
// Y preserved
//---------------------------------------------------------------

.macro add8(adr)
{
    clc
    adc adr
    sta adr
    bcc pas_inc
    inc adr+1
pas_inc:    
}

//---------------------------------------------------------------
// stc(dest) : store carry to dest
// X, Y preserved
//---------------------------------------------------------------

.macro stc(dest)
{
    lda #0
    rol
    sta dest
}

//---------------------------------------------------------------
// push_r(reg) : push reg on stack
// Y preserved
//---------------------------------------------------------------

.macro push_r(reg)
{
    lda zr0l+2*reg
    pha
    lda zr0h+2*reg
    pha
}

//---------------------------------------------------------------
// pop_r(reg) : pop reg from stack
// Y preserved
//---------------------------------------------------------------

.macro pop_r(reg)
{
    pla
    sta zr0h+2*reg
    pla
    sta zr0l+2*reg
}

//---------------------------------------------------------------
// str_r(reg_dest, reg) : reg_dest = reg
// Y preserved
//---------------------------------------------------------------

.macro str_r(reg_dest, reg)
{
    lda zr0l+2*reg
    sta zr0l+2*reg_dest
    lda zr0h+2*reg
    sta zr0h+2*reg_dest
}

//---------------------------------------------------------------
// sts_r(reg_dest, reg) : reg_dest = word at the address in reg
// Y not preserved
// mov r0, (r1)
//---------------------------------------------------------------

.macro sts_r(reg_dest, reg)
{
    ldy #0
    lda (zr0+2*reg),y
    sta ztmp
    iny
    lda (zr0+2*reg),y
    sta zr0+2*reg_dest+1
    lda ztmp
    sta zr0+2*reg_dest
}

//---------------------------------------------------------------
// str_s(reg_dest, reg) : (reg_dest) = reg
// stores reg at address in reg_dest
// Y not preserved
// mov (r1), r0
//---------------------------------------------------------------

.macro str_s(reg_dest, reg)
{
    ldy #0
    lda (zr0+2*reg_dest),y
    sta ztmp
    iny
    lda (zr0+2*reg_dest),y
    sta ztmp+1
    dey
    lda zr0l+2*reg
    sta (ztmp),y
    iny
    lda zr0h+2*reg
    sta (ztmp),y
}

//---------------------------------------------------------------
// str_rind(reg_dest, reg) : (reg_dest) = reg
// stores reg at address in reg_dest
// Y not preserved
//---------------------------------------------------------------

.macro str_rind(reg_dest, reg)
{
    ldy #0
    lda (zr0+2*reg_dest),y
    sta ztmp
    iny
    lda (zr0+2*reg_dest),y
    sta ztmp+1
    dey
    lda zr0l+2*reg
    sta (ztmp),y
    iny
    lda zr0h+2*reg
    sta (ztmp),y
}

//---------------------------------------------------------------
// swapr_r(reg1, reg2) : swaps reg1, reg2
// Y preserved
//---------------------------------------------------------------

.macro swapr_r(reg1, reg2)
{
 lda zr0l+2*reg1
 pha
 lda zr0l+2*reg2
 sta zr0l+2*reg1
 pla
 sta zr0l+2*reg2

 lda zr0h+2*reg1
 pha
 lda zr0h+2*reg2
 sta zr0h+2*reg1
 pla
 sta zr0h+2*reg2
}

//---------------------------------------------------------------
// dec_r(reg) : reg--
// Y preserved
//---------------------------------------------------------------

.macro dec_r(reg)
{
    lda zr0l+2*reg
    bne pas_zero
    dec zr0h+2*reg
pas_zero:
    dec zr0l+2*reg
}

//---------------------------------------------------------------
// inc_r(reg) : reg++
// Y preserved
//---------------------------------------------------------------

.macro inc_r(reg)
{
    inc zr0l+2*reg
    bne pas_zero
    inc zr0h+2*reg
pas_zero:
}

//===============================================================
// General purpose macros
//===============================================================

//---------------------------------------------------------------
// swn : swap nybbles
//---------------------------------------------------------------

.macro swn()
{
    asl
    adc #$80
    rol
    asl
    adc #$80
    rol
}

//---------------------------------------------------------------
// breakpoint : wait
//---------------------------------------------------------------

.macro breakpoint()
{
wait:
    inc $d020
    jmp wait    
}
