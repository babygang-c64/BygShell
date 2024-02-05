//===============================================================
// BYG BIOS : BIOS functions for BYG Shell system
//---------------------------------------------------------------
// Calling rules : command # in A, parameter in R0,
// returns C=0 if OK, C=1 if KO
//===============================================================

#importonce

* = * "bios vectors"

.namespace bios 
{
// liste des fonctions du BIOS

.label reset=0
.label pprint=1
.label pprintnl=2
.label setvar=3
.label getvar=4
.label rmvar=5
.label input=6
.label count_vars=7
.label list_add=8
.label list_get=9
.label file_load=10
.label set_device=11
.label add_str=12
.label copy_str=13
.label list_rm=14
.label list_print=15
.label list_size=16
.label error=17
.label list_reset=18
.label str_empty=19
.label prep_path=20
.label lsblk=21
.label pprinthex=22
.label pprinthex8a=23
.label hex2int=24
.label file_open=25
.label get_device_status=26
.label file_close=27
.label build_path=28
.label set_device_from_path=29
.label read_buffer=30
.label write_buffer=31
.label eval_str=32
.label filter=33
.label print_path=34

bios_jmp:
    .word do_reset
    .word do_pprint
    .word do_pprintnl
    .word do_setvar
    .word do_getvar
    .word do_rmvar
    .word do_input
    .word do_count_vars
    .word do_list_add
    .word do_list_get
    .word do_file_load
    .word do_set_device
    .word do_add_str
    .word do_copy_str
    .word do_list_rm
    .word do_list_print
    .word do_list_size
    .word do_error
    .word do_list_reset
    .word do_str_empty
    .word do_prep_path
    .word do_lsblk
    .word do_pprinthex
    .word do_pprinthex8a
    .word do_hex2int
    .word do_file_open
    .word do_get_device_status
    .word do_file_close
    .word do_build_path
    .word do_set_device_from_path
    .word do_read_buffer
    .word do_write_buffer
    .word do_eval_str
    .word do_filter
    .word do_print_path

* = * "BIOS code"

bios_reset:
    lda #bios.reset
bios_exec:
    php
    asl
    sta bios_jmpl
    plp
    jmp bios_jmpl:(bios_jmp)

//===============================================================
// bios functions et variables
//===============================================================

//---------------------------------------------------------------
// reset : démarrage
//
// raz des variables
// affiche le message de départ
//---------------------------------------------------------------

do_reset:
{
    // memory : all except kernal and IO
    lda #MEMIOKERNAL
    sta $01

    // lowercase and colors, then clear screen
    lda #23
    sta $d018
    lda bios.screen_bg
    sta $d020
    lda bios.screen_fg
    sta $d021
    lda bios.color_text
    sta CURSOR_COLOR
    lda #$1e
    jsr CHROUT
    jsr CLEARSCREEN

    call_bios(pprintnl, text_reset)
    call_bios(pprintnl, text_version)

    call_bios(count_vars, var_names)
    sta nb_variables

    call_bios(count_vars, internal_commands)
    sta nb_cmd

    sec
    bios(bios.lsblk)
    stx bios.device
    // ici A = nb devices et X = 1er device

    // tente de sélectionner le device dans variable device
    bios(bios.set_device)
    bcc device_ok

    // si KO essaye le 1er device trouvé
    ldx bios.device
    jsr bios.do_set_device_from_int

device_ok:
    // start shell
    clc
    jmp shell.toplevel

text_reset:
    pstring("BYG SHELL")

text_version:
    .byte 5
    .text "V0.1"
    .byte 13
}

//---------------------------------------------------------------
// filter : test filtre vs contenu
// * = n'importe quelle suite de caractères
// ? = un caractère
// entrée : R0 = filtre, R1 = contenu à tester
// sortie : C=1 KO, C=0 OK
//---------------------------------------------------------------

do_filter:
{
    push_r(0)
    push_r(1)
    ldy #0
    getbyte_r(0)
    beq vide
    sta lgr_filtre
    getbyte_r(1)
    beq vide
    sta lgr_contenu

process:
    getbyte_r(0)
    cmp #'?'
    bne pas_single
    getbyte_r(1)
    jmp continue_process
pas_single:
    cmp #'*'
    bne pas_multi
    jsr do_multi
    bcc vide
    jmp continue_process
pas_multi:
    sta lu
    getbyte_r(1)
    cmp lu
    bne ko
continue_process:
    dec lgr_filtre
    dec lgr_contenu
    beq test_fin
    lda lgr_filtre
    bne process
test_fin:
    lda lgr_contenu
    bne ko
    lda lgr_filtre
    beq vide
ko:
    pop_r(1)
    pop_r(0)
    sec
    rts
vide:
    pop_r(1)
    pop_r(0)
    clc
    rts

do_multi:
    lda lgr_filtre
    cmp #1
    bne pas_fin_filtre
    clc
    rts
pas_fin_filtre:
    sec
    rts

lgr_filtre:
    .byte 0
lgr_contenu:
    .byte 0
lu:
    .byte 0
}

//---------------------------------------------------------------
// lstrip : enleve les espaces en début de chaine
// entrée : R0, sortie : R0 modifié
//---------------------------------------------------------------

do_lstrip:
{
    ldy #0
    lda (zr0),y
    sta longueur

check_zero:
    iny
    lda (zr0),y
    cmp #$30
    bne trouve
    cpy longueur
    bne check_zero
    beq fini
trouve:
    dey
    sty longueur
    sec
    ldy #0
    lda (zr0),y
    sbc longueur
    ldy longueur
    sta (zr0),y
    tya
    add_r(0)
fini:
    clc
    rts

longueur:
    .byte 0
}

//---------------------------------------------------------------
// int2str : int r0 vers buffer pstring pointée par r1
// le buffer cible doit faire 6 octets
//---------------------------------------------------------------

do_int2str:
{
    jsr int2bcd
    ldy #0
    lda #6
    sta (zr1),y
    iny
    lda bcd_buffer+2
    jsr conv_bcd
    lda bcd_buffer+1
    jsr conv_bcd
    lda bcd_buffer+0
    jsr conv_bcd
    rts

conv_bcd:
    tax
    lsr
    lsr
    lsr
    lsr
    ora #$30
    sta (zr1),y
    iny
    txa
    and #$0f
    ora #$30
    sta (zr1),y
    iny
    rts

int2bcd:
    lda #0
    sta bcd_buffer
    sta bcd_buffer+1
    sta bcd_buffer+2
    sed
    ldy #0
    ldx #6
calc1:
    asl zr0l
    rol zr0h
    adc bcd_buffer+0
    sta bcd_buffer+0
    dex
    bne calc1

    ldx #7
cbit7:
    asl zr0l
    rol zr0h
    lda bcd_buffer+0
    adc bcd_buffer+0
    sta bcd_buffer+0
    lda bcd_buffer+1
    adc bcd_buffer+1
    sta bcd_buffer+1
    dex
    bne cbit7

    ldx #3
cbit13:
    asl zr0l
    rol zr0h
    lda bcd_buffer+0
    adc bcd_buffer+0
    sta bcd_buffer+0
    lda bcd_buffer+1
    adc bcd_buffer+1
    sta bcd_buffer+1
    lda bcd_buffer+2
    adc bcd_buffer+2
    sta bcd_buffer+2
    dex
    bne cbit13
    cld
    rts

bcd_buffer:
    .byte 0,0,0
}

int_conv:
    pstring("000000")

//---------------------------------------------------------------
// str2int : chaine r0 vers r1, partie basse dans A
// 8 bits seulement pour l'instant
// préserve r0 / x / y
//---------------------------------------------------------------

do_str2int:
{
    push_r(0)
    ldy #0
    sty zr1l
    sty zr1h
    getbyte_r(0)
    sta lgr_str
    cmp #0
    bne next_char
    pop_r(0)
    tya
    clc
    rts
next_char:
    getbyte_r(0)
    cmp #$30
    bmi pas_int
    cmp #$39
    beq ok_int
    bpl pas_int
ok_int:
    and #15
    clc
    adc zr1l
    sta zr1l
    bcc pas_inc
    inc zr1h
pas_inc:
    dec lgr_str
    beq fin_transfo
    lda zr1l
    asl
    sta ztmp
    asl
    asl
    clc
    adc ztmp
    sta zr1l
    jmp next_char

fin_transfo:
    pop_r(0)
    lda zr1l
    clc
    rts
pas_int:
    pop_r(0)
    sec
    rts
lgr_str:
    .byte 0    
}

//----------------------------------------------------
// do_count_vars : compte le nombre de variables ou de
// commandes dispos, en entrée r0 = source
// en sortie : A = nb variables
//----------------------------------------------------

do_count_vars:
{
    ldy #0
    sty nb_variables

boucle:
    getbyte_r(0)
    cmp #0
    beq fin

    add_r(0)
    lda #2
    add_r(0)
    inc nb_variables
    bne boucle

fin:
    lda nb_variables
    clc
    rts

nb_variables:
    .byte 0
}

//---------------------------------------------------------------
// error : affiche message d'erreur
// adresse message en R0
//---------------------------------------------------------------

do_error:
{
    lda bios.color_error
    sta CURSOR_COLOR
    str_r(1, 0)
    call_bios(bios.pprint, msg_error)
    str_r(0, 1)
    lda #pprintnl
    jsr bios_exec
    lda bios.color_text
    sta CURSOR_COLOR
    sec
    rts
}

//---------------------------------------------------------------
// hex2int : conversion pstring 16bits hexa en entier
// entrée : pstring dans R0, sortie : R0 = valeur
//---------------------------------------------------------------

do_hex2int:
{
    ldy #0
    getbyte_r(0)
    cmp #4
    bne pas4car

    jsr conv_hex_byte
    pha
    jsr conv_hex_byte
    sta zr0l
    pla
    sta zr0h
    clc
    rts
pas4car:
    sec
    rts

conv_hex_byte:
    jsr conv_hex_nibble
    asl
    asl
    asl
    asl
    sta ztmp
    jsr conv_hex_nibble
    ora ztmp
    rts

conv_hex_nibble:
    getbyte_r(0)
    sec
    sbc #$30
    cmp #10
    bcc pasAF
    sec
    sbc #7
pasAF:
    rts
}

//---------------------------------------------------------------
// set_device : sélectionne device en fonction de la valeur dans
// la variable DEVICE
//---------------------------------------------------------------


// en entrée device dans X

do_set_device_from_int:
{
    push_r(0)
    stx zr0l
    lda #0
    sta zr0h
    stw_r(1, int_conv)
    jsr do_int2str
    stw_r(0, int_conv)
    jsr do_lstrip
    .print "int_conv=$"+toHexString(int_conv)
    str_r(1, 0)
    call_bios(setvar, do_set_device.text_device)
    pop_r(0)
    rts
}

do_set_device:
{
    // lecture variable device
    call_bios(bios.getvar, text_device)
    str_r(0, 1)
    jsr do_str2int
    // si pas int, no device
    bcs no_device
    tay
    lda devices,y
    // si pas dans la liste des devices OK = no device
    beq no_device

    tya
    sta bios.device
    clc
    rts

no_device:
    call_bios(error, msg_error.device_not_present)
    rts

text_device:
    pstring("DEVICE")
}

//---------------------------------------------------------------
// add_str : ajoute une chaine
// r0 = r0 + r1
//---------------------------------------------------------------

do_add_str:
{
    // pos_new = écriture = lgr + 1
    ldy #0    
    lda (zr0),y
    tay
    iny
    sty pos_new

    // pos_copie = lecture = 1
    // lgr_ajout = nb de caractères à copier
    ldy #0
    lda (zr1),y
    sta lgr_ajout
    iny
    sty pos_copie

copie:
    ldy pos_copie
    lda (zr1),y
    ldy pos_new
    sta (zr0),y
    inc pos_new
    inc pos_copie
    dec lgr_ajout
    bne copie

    // mise à jour longueur = position écriture suivante - 1
    dec pos_new
    lda pos_new
    ldy #0
    sta (zr0),y
    clc
    rts

pos_copie:
    .byte 0
pos_new:
    .byte 0
lgr_ajout:
    .byte 0
}

//---------------------------------------------------------------
// file_load : charge un fichier et execute code en $080d
// r0 = nom fichier A = présence séparateur
//---------------------------------------------------------------

do_file_load:
{
    sta avec_separateur
    str_r(2, 0) // sauvegarde nom
    jsr test_load    
    bcc load_ok

    // test avec PATH + NOM

    call_bios(bios.getvar, text_path)
    str_r(0, 1)
    stw_r(1, work_buffer)
    // 0 : dest = work buffer, 1 = path, 2 = filename

    jsr bios.do_copy_str

    stw_r(0, work_buffer)
    str_r(1, 2)
    jsr bios.do_add_str
    
    stw_r(0, work_buffer)
    jsr test_load
    bcc load_ok

erreur:
    call_bios(bios.error, msg_error.command_not_found)
    rts

load_ok:

    // vérifie présence SYS XXXX
    lda $0805
    cmp #$9e
    bne erreur
    lda $080a
    bne erreur

    // récupère les infos des paramètres avant le saut
    // A = présence paramètre si pas 0
    // paramètres en r0 = workbuffer + lgr commande

    lda work_buffer
    sta zr0l
    lda #>work_buffer
    sta zr0h

    lda avec_separateur
    clc
    jsr $080d
    clc
    rts

test_load:
    
    ldy #0
    getbyte_r(0)
    ldx zr0l
    ldy zr0h
    jsr SETNAM

    jsr bios.do_set_device
    lda bios.device

    lda #0  // 0 = fixed address, 1 = source address
    ldy #2
    ldx bios.device
    jsr SETLFS

    // load file to $0801
    lda #0
    ldx #1
    ldy #8
    jsr LOAD
    rts

text_path:
    pstring("PATH")
avec_separateur:
    .byte 0
}

.print "do_file_load=$"+toHexString(do_file_load)

//---------------------------------------------------------------
// list_print : affiche liste
// entrée : r0 = ptr objet liste
//---------------------------------------------------------------

do_list_print:
{
    // r2 = ptr data, r3 = ptr new, A = nb elements
    jsr setup_list
    sta nb_elem
    cmp #0
    beq fin
    
boucle:
    ldy #0
    lda (zr0+2*2),y
    clc
    adc #1
    sta lgr_elem

    str_r(0, 2)
    jsr do_pprintnl

    lda lgr_elem
    add_r(2)
    dec nb_elem
    bne boucle
fin:
    clc
    rts

nb_elem:
    .byte 0
lgr_elem:
    .byte 0
}

//---------------------------------------------------------------
// list_rm : supprime une entrée dans une liste
// entrée : r0 = ptr objet liste, X = numéro entrée à supprimer
// retour : r0 = ptr objet liste à jour
//---------------------------------------------------------------

do_list_rm:
{
    stx pos_elem
    jsr setup_list
    sta nb_elem

    // future taille = nb_elem - 1
    // ptr_data ne bougera pas, juste ptr_new
    sec
    sbc #1
    ldy #0
    sta (zr0),y

    // r2 : ptr data, r3 : ptr new

    // r5 = nouveau pour écriture
    // r1 = pour lecture

    str_r(5, 2)
    str_r(1, 2)
    ldy #0
    ldx #0

process_elem:

    // copie : octet longueur sauf si elem à supprimer
    getbyte_r(1)
    sta nb_copie
    cpx pos_elem
    beq recopie_elem
    setbyte_r(5)

    // et data, pareil sauf si elem à supprimer
recopie_elem:
    getbyte_r(1)
    cpx pos_elem
    beq pas_copie
    setbyte_r(5)
pas_copie:
    dec nb_copie
    bne recopie_elem

    // traitement suivant
suivant:
    inx
    dec nb_elem
    bne process_elem

    // fin, écriture nouvelles données ptr_new = r5
    ldy #3
    lda zr0l+2*5
    sta (zr0),y
    iny
    lda zr0h+2*5
    sta (zr0),y

    // fin, écriture nouvelles données ptr_last = r4
    ldy #5
    lda zr0l+2*4
    sta (zr0),y
    iny
    lda zr0h+2*4
    sta (zr0),y

    clc
    rts

pos_elem:
    .byte 0
nb_elem:
    .byte 0
nb_copie:
    .byte 0
}

//---------------------------------------------------------------
// list_size : renvoie la taille de la liste dans R0 dans A
//---------------------------------------------------------------

do_list_size:
{
    ldy #0
    lda (zr0),y
    clc
    rts
}

//---------------------------------------------------------------
// list_get : renvoie la nème valeur de pstring de la liste
// entrée : r0 = ptr objet liste, X = numéro valeur
// sortie = trouvé C=1 et R0 = valeur, sinon C=0 et R0 = NIL
//---------------------------------------------------------------

do_list_get:
{
    stx pos_elem
    jsr setup_list

    // si 0 éléments ou nb demandé >= taille : non trouvé
    cmp #0
    beq fin_get_non_trouve
    cmp pos_elem
    beq fin_get_non_trouve
    bmi fin_get_non_trouve

    // parcours pour trouver element

    str_r(0, 2)
    ldy #0
    ldx #0

boucle_elem:
    cpx pos_elem
    beq fin_get_trouve

    getbyte_r(0)
    sta lgr_elem
    cmp #0
    beq elem_suivant
passe_elem:
    getbyte_r(0)
    dec lgr_elem
    bne passe_elem
elem_suivant:
    inx
    bne boucle_elem

fin_get_trouve:
    clc
    ldx pos_elem
    rts

fin_get_non_trouve:
    sec
    stw_r(0, do_getvar.msg_pas_var)
    ldx pos_elem
    rts

pos_elem:
    .byte 0
lgr_elem:
    .byte 0
}

//---------------------------------------------------------------
// list_reset : remet à zero une liste
// paramètres : r0 = ptr objet liste, r1 = ptr data liste
//---------------------------------------------------------------

do_list_reset:
{
    //-- nb elements = 0
    ldy #0
    tya
    sta (zr0),y
    inc_r(0)

    lda zr1l
    sta (zr0),y
    lda zr1h
    iny
    sta (zr0),y
    iny
    lda zr1l
    sta (zr0),y
    lda zr1h
    iny
    sta (zr0),y
    iny
    lda zr1l
    sta (zr0),y
    lda zr1h
    iny
    sta (zr0),y
    iny
    lda #0
    sta (zr0),y
    rts
}

//---------------------------------------------------------------
// list_add : ajoute pstring dans une liste
// paramètres : r0 = ptr objet liste, r1 = pstring
// renvoie le numéro de l'item dans la liste dans A
//---------------------------------------------------------------

do_list_add:
{   
    push_r(4) // sauvegarde r4

    jsr setup_list
    sta num_elem

    push_r(0)

    // copie r0 vers r3 = ptr new
    // ptr last = r1
    str_r(0, 1)
    str_r(1, 3)
    str_r(4, 1)
    jsr do_copy_str
    tay
    pop_r(0)
    tya
    jsr addelem_list
    lda num_elem

    pop_r(4) // récupère r4
    clc
    rts

num_elem:
    .byte 0
}

//---------------------------------------------------------------
// setup_list : récupère les éléments pour travail sur plist
// r2 = ptr data, r3 = ptr new, A = nb elements, r4 = ptr last
//---------------------------------------------------------------

setup_list:
{
    ldy #5
do_setup:
    lda (zr0),y
    sta zr0+3,y
    dey
    bne do_setup
    lda (zr0),y
    rts
}

//---------------------------------------------------------------
// addelem_list : comptabilise ajout dans liste 
// r0 = objet liste, A = longueur ajoutée
//---------------------------------------------------------------

addelem_list:
{
    // ajout longueur
    ldy #3
    clc
    adc (zr0),y
    sta (zr0),y
    bcc pas_inc
    iny
    lda #0
    adc (zr0),y
    sta (zr0),y
pas_inc:
    // et nb elements + 1
    ldy #0
    clc
    lda (zr0),y
    adc #1
    sta (zr0),y
    rts
}

//---------------------------------------------------------------
// input : saisie chaine, retour dans r0 et stockage dans
//         input_buffer
//---------------------------------------------------------------

.label BACKSPACE=$14
.label RIGHT=$1D
.label UP=$91
.label LEFT=$9D
.label DOWN=$11
.label INS=$94
.label CTRLA=1      // unix style home
.label CTRLE=5      // unix style end
.label RUNSTOP=$03
.label CTRLK=$0b    // delete to end of line
.label CTRLO=$0f    // end key
.label CTRLU=$15    // home key
.label CTRLX=$18    

do_input:
{
    // position de lecture dans l'historique = 
    // nb éléments car sera décrémenté à chaque
    // appuis de CURSOR UP
    ldx shell.nb_history
    stx pos_history

    lda #0
    sta CURSOR_ONOFF

    ldx #0
    stx write_x
    stx max_x

get_next:
    jsr GETIN
    beq get_next

    cmp #$0d
    bne pas_fin_input
    jmp fin_input

pas_fin_input:

    //-- INS -----
    cmp #INS
    bne pas_ins

    ldx write_x
    //cmp max_x
    cpx max_x
    beq get_next

    jsr key_ins

    // insère espace
    lda #32
    ldx write_x
    sta input_buffer+1,x
    lda #INS
    jmp print_et_next

pas_ins:
    //-- BACKSPACE -----
    cmp #BACKSPACE
    bne pas_backspace
    
    ldx write_x
    beq get_next
    cpx max_x
    beq backspace_fin_de_chaine

    jsr key_backspace

    // effectue le backspace
backspace_fin_de_chaine:
    dec write_x
    dec max_x
    lda #BACKSPACE
    jmp print_et_next

    //-- RUNSTOP -----
pas_backspace:
    cmp #RUNSTOP
    bne pas_runstop
    lda #0
    sta max_x
    sta write_x
    jmp fin_input

    //-- CURSOR LEFT -----
pas_runstop:
    cmp #LEFT
    bne pas_left

    ldx write_x
    beq get_next
    dec write_x
    jmp print_et_next

    //-- CURSOR RIGHT --
pas_left:
    cmp #RIGHT
    bne pas_right

    ldx write_x
    cpx max_x
    beq get_next
    inc write_x
    jmp print_et_next

    //-- CURSOR UP -----
pas_right:
    cmp #UP
    bne pas_up

    jsr clear_line
    jsr get_prev_history
    jmp get_next

    //-- CURSOR DOWN -----
pas_up:
    cmp #DOWN
    bne pas_down

    jsr clear_line
    jsr get_next_history
    jmp get_next

    //-- CTRL-K : clear to end -----
pas_down:
    cmp #CTRLK
    bne pas_ctrlk

    jsr clear_to_end
    jmp get_next

    //-- CTRL-E et CTRL-U : move to end -----
pas_ctrlk:
    cmp #CTRLE
    beq do_ctrlk
    cmp #CTRLU
    bne pas_ctrle

do_ctrlk:
    jsr cursor_end
    jmp get_next

    //-- CTRL-A et CTRL-O : move to start -----
pas_ctrle:
    cmp #CTRLA
    beq do_ctrla
    cmp #CTRLO
    bne normal

do_ctrla:
    jsr cursor_start
    jmp get_next

    //-- OTHER : écriture normale -----
normal:

    ldx write_x
    cpx max_x
    beq normal_end

    // insère caractère

    jsr key_ins
    pha
    lda #INS
    jsr write_char
    pla

normal_end:
    ldx write_x
    sta input_buffer+1,x
    inc write_x
    inx
    cpx max_x
    bmi print_et_next
    inc max_x

print_et_next:
    jsr write_char
    jmp get_next

write_char:
    ldy CURSOR_STATUS
    bne write_char
    jmp CHROUT

fin_input:
    jsr wait_cursor_ok
    lda #1
    sta CURSOR_ONOFF
    lda #$0d
    jsr CHROUT
    ldx max_x
    stx input_buffer

    stw_r(0, input_buffer)
    clc
    rts

    //-------------------------------------------------------
    // get_prev_history et get_next_history : récupère un 
    // élément dans l'historique
    //-------------------------------------------------------

get_next_history:
{
    // si pas d'historique -> suite
    ldx shell.nb_history
    beq get_prev_history.pas_history
    
    ldx pos_history
    cpx shell.nb_history
    beq reboucle

boucle_history:
    inc pos_history
    ldx pos_history
    cpx shell.nb_history
    beq reboucle
    bne get_prev_history.copie_history
reboucle:
    lda #$ff
    sta pos_history
    bne boucle_history // always
}

get_prev_history:
{
    // si pas d'historique -> suite
    ldx shell.nb_history
    beq pas_history
    
    // sinon prend l'élément n-1 et
    // boucle si début atteint

boucle_history:
    dec pos_history
    ldx pos_history
    cpx #$ff
    bne copie_history
    ldx shell.nb_history
    stx pos_history
    jmp boucle_history

    // récupère l'élément d'historique et sa
    // longueur et effectue la copie
copie_history:
    call_bios(list_get, shell.history_list)
    ldy #0
    lda (zr0),y
    sta nb_copie
    sta input_buffer
    iny

copie_chaine_history:
    ldy write_x
    iny
    lda (zr0),y
    ldx write_x
    sta input_buffer+1,x
    inc write_x
    inc max_x
    jsr write_char
    iny
    dec nb_copie
    bne copie_chaine_history
    sec
    rts

pas_history:
    clc
    rts
}

    //-------------------------------------------------------
    // key_backspace : décalage pour backspace
    //-------------------------------------------------------

key_backspace:
    sec
    lda max_x
    sbc write_x
    tax
    ldy write_x
    iny
    
    // décale les caractères à droite
do_backspace:
    lda input_buffer,y
    dey
    sta input_buffer,y
    iny
    iny
    dex
    bne do_backspace
    rts

    //-------------------------------------------------------
    // key_ins : décalage pour insertion
    //-------------------------------------------------------
key_ins:
{
    pha
    sec
    lda max_x
    sbc write_x
    tax
    ldy max_x

    // décale les caractères à droite
do_ins:
    lda input_buffer,y
    iny
    sta input_buffer,y
    dey
    dey
    dex
    bne do_ins
    inc max_x
    pla
    rts
}

    //-------------------------------------------------------
    // cursor_end : déplace le curseur en fin de ligne
    //-------------------------------------------------------

cursor_end:
{
    lda write_x
    cmp max_x
    bne cont_cursor_end
    rts

cont_cursor_end:
    ldy CURSOR_STATUS
    bne cont_cursor_end
    lda #RIGHT
    jsr CHROUT
    inc write_x
    bne cursor_end
}

    //-------------------------------------------------------
    // cursor_start : déplace le curseur en début de ligne
    //-------------------------------------------------------

cursor_start:
{
    lda write_x
    cmp #0
    bne cont_cursor_start
    rts

cont_cursor_start:
    ldy CURSOR_STATUS
    bne cont_cursor_start
    lda #LEFT
    jsr CHROUT
    dec write_x
    bne cursor_start
    rts
}

    //-------------------------------------------------------
    // clear_line : efface complètement la ligne
    //-------------------------------------------------------

clear_line:
{
    lda write_x
    beq fin_clear

    jsr cursor_end

fin_go_max:
    ldy CURSOR_STATUS
    bne fin_go_max
    lda #BACKSPACE
    jsr CHROUT
    dec write_x
    bne fin_go_max
fin_clear:
    lda #0
    sta max_x
    rts
}

    //-------------------------------------------------------
    // clear_to_end : efface de la position actuelle 
    // à la fin de ligne
    //-------------------------------------------------------

clear_to_end:
{
    lda write_x
    cmp max_x
    beq fin_clear_to_end
    sta target_x

move_to_end:
    ldy CURSOR_STATUS
    bne move_to_end
    lda #RIGHT
    jsr CHROUT
    inc write_x
    lda write_x
    cmp max_x
    bne move_to_end

go_back_clear:
    ldy CURSOR_STATUS
    bne go_back_clear
    lda #BACKSPACE
    jsr CHROUT
    dec write_x
    lda write_x
    cmp target_x
    bne go_back_clear

fin_clear_to_end:
    ldx write_x
    stx max_x
    dex
    stx input_buffer
    rts
}

// wait_cursor_ok : attend status curseur OK

wait_cursor_ok:
    lda CURSOR_STATUS
    bne wait_cursor_ok
    rts

write_x:
    .byte 0
max_x:
    .byte 0
pos_history:
    .byte 0
target_x:
nb_copie:
    .byte 0

.print "write_x=$"+toHexString(write_x)
.print "max_x=$"+toHexString(max_x)
.print "input_buffer=$"+toHexString(input_buffer)
.print "nb_history=$"+toHexString(shell.nb_history)
.print "pos_history=$"+toHexString(pos_history)
}

//---------------------------------------------------------------
// eval_str : expanse une pstring
// entrée : R0, sortie : R1
//---------------------------------------------------------------

do_eval_str:
{
    ldy #0
    tya
    sta (zr1),y
    lda (zr0),y
    bne pas_vide
    clc
    rts

pas_vide:
    push_r(1)
    lda #0
    setbyte_r(1)
    getbyte_r(0)
    sta lgr_input
    sty lgr_output
process:
    getbyte_r(0)
    cmp #'%'
    beq special

    // traitement caractère normal, ajout dans la chaine en
    // sortie dans R1
process_normal:
    setbyte_r(1)
    inc lgr_output
    dec lgr_input

process_suite:
    lda lgr_input
    bne process

fin_process:
    pop_r(1)
    lda lgr_output
    ldy #0
    sta (zr1),y
    clc
    rts

    // caractères spéciaux
special:
    jsr consomme_car

    getbyte_r(0)
    cmp #'%'
    bne pas_pct
    jmp process_normal

pas_pct:
    cmp #'R'
    bne pas_registre

    // registre : récupère la valeur d'un registre
    jsr consomme_car
    dec lgr_input
    getbyte_r(0)
    and #$0f
    asl
    tay

    push_r(0)
    lda zr0l,y
    sta zr0l
    lda zr0h,y
    sta zr0h
    ldy #0

    lda zr0h
    jsr a2hex
    lda hexl
    setbyte_r(1)
    lda hexh
    setbyte_r(1)
    lda zr0l
    jsr a2hex
    lda hexl
    setbyte_r(1)
    lda hexh
    setbyte_r(1)

    clc
    lda lgr_output
    adc #4
    sta lgr_output

    pop_r(0)
    jmp process_suite

pas_registre:
    cmp #'V'
    beq process_variable
    jmp pas_variable
process_variable:
    jsr consomme_car

    // V = variable : récupère la valeur d'une variable

    push_r(1)
    stw_r(1, work_name)
    lda #0
    setbyte_r(1)

copie_nom_var:
    getbyte_r(0)
    
    cmp #'%'
    beq fin_copie_nom
    setbyte_r(1)
    inc work_name
    jsr consomme_car
    jmp copie_nom_var

fin_copie_nom:
    dec lgr_input

    // nom variable dans work_name, suite dans r0
    // recherche contenu variable -> r1 -> r2 et copie
    // la valeur

    push_r(0)
    stw_r(0, work_name)
    jsr do_getvar
    str_r(2, 1)
    pop_r(0)
    pop_r(1)

do_copy_var:
    ldy #0
    getbyte_r(2)
    sta lgr_copie
copie_var:
    getbyte_r(2)
    setbyte_r(1)
    inc lgr_output
    dec lgr_copie
    bne copie_var
    jmp process_suite

pas_variable:
    cmp #'P'
    bne pas_pstring
    jsr consomme_car

    // P = pstring, copie la pstring à l'adresse du registre fourni

    getbyte_r(0)
    dec lgr_input
    and #15
    asl
    tay

    lda zr0l,y
    sta zr2l
    lda zr0h,y
    sta zr2h
    jmp do_copy_var

pas_pstring:
    clc
    rts

consomme_car:
    dec lgr_input
    beq fin_erreur
    rts
fin_erreur:
    inc $d020
    jmp fin_erreur
    pla
    pla
    sec
    rts
* = * "longueurs"
lgr_copie:
    .byte 0
lgr_input:
    .byte 0
lgr_output:
    .byte 0
}

//---------------------------------------------------------------
// pprint : affiche une chaine de type pascal en r0
// pprintnl : idem avec retour à la ligne
// 
// valeurs expansées :
//
// %% = %
// %P<n°> = affiche la chaîne à l'adresse de R<n°>
// %R<n°> = affiche la valeur en hexa $AAAA de R<n°> 
// %V<var>% = affiche la valeur de la variable <var>
//---------------------------------------------------------------

do_pprint:
{
    push_r(1)
    tya
    pha
    stw_r(1, work_pprint)
    jsr do_eval_str
    lda work_pprint
    beq est_vide
    ldy #0
aff:
    lda work_pprint+1,y
    jsr CHROUT
    iny
    cpy work_pprint
    bne aff
est_vide:
    pla
    tay
    pop_r(1)
    clc
    rts
}

do_pprintnl:
{
    jsr do_pprint
    lda #13
    jsr CHROUT
    clc
    rts
}

//---------------------------------------------------------------
// do_pprinthex : affiche en hexa format $xxxx la valeur en r0
//---------------------------------------------------------------

do_pprinthex:
{
    stx ztmp
    lda #'$'
    jsr CHROUT
    lda zr0h
    jsr do_pprinthex8a
    jsr do_pprinthex8
    ldx ztmp
    rts
}

//---------------------------------------------------------------
// a2hex : conversion 8 bits en hexa
// entrée : A, sortie hexl / hexh
//---------------------------------------------------------------

hexl:
    .byte 0
hexh:
    .byte 0

a2hex:
{
    pha
    lsr
    lsr
    lsr
    lsr
    jsr process_nibble
    sta hexl
    pla
    and #15
process_nibble:
    cmp #10
    clc
    bmi pas_add
    adc #7
pas_add:
    adc #$30
    sta hexh
    clc
    rts
}

//---------------------------------------------------------------
// do_pprinthex8 : affiche en hexa la valeur dans r0l
//---------------------------------------------------------------

do_pprinthex8:
    lda zr0l
do_pprinthex8a:
{
    jsr a2hex
    lda hexl
    jsr CHROUT
    lda hexh
    jsr CHROUT
    clc
    rts
}

.print "do_pprinthex8a=$"+toHexString(do_pprinthex8a)
.print "do_pprinthex=$"+toHexString(do_pprinthex)

//---------------------------------------------------------------
// getvar : lecture variable
// r0 : nom variable -> r1 : contenu et C = 1
// pas trouvé => C = 0 et contenu = NIL
//---------------------------------------------------------------

do_getvar:
{
    jsr lookup_var
    bcc pas_var
    clc
    rts

pas_var:
    stw_r(1, msg_pas_var)
    sec
    rts

msg_pas_var:
    pstring("NIL")
}

//---------------------------------------------------------------
// setvar : crée une variable, affecte une valeur
// r0 : nom variable, r1 : nouveau contenu
//---------------------------------------------------------------

do_setvar:
{
    push_r(1)
    jsr lookup_var
    bcc creation
    jmp pas_creation

creation:
    // création : 
    // copie nom variable
    stw_r(1, ptr_last_variable)
    ldself_r(1)
    jsr do_copy_str
    add8(ptr_last_variable)
    stw_r(3, ptr_last_variable)

    // copie valeur variable
    pop_r(1)
    str_r(0, 1) 
    stw_r(1, ptr_last_value)
    ldself_r(1)
    str_r(4, 1)
    jsr do_copy_str
    add8(ptr_last_value)

    // ecriture adresse valeur à la suite du nom
    str_rind(3, 4)

    // ajoute longueur adresse valeur à ptr_last_variable
    lda #2
    add8(ptr_last_variable)

    // incrémente le nb de variables
    inc nb_variables
    clc
    rts

    // si update, supprime la variable et rappelle setvar
pas_creation:
    tax
    push_r(0)
    txa
    jsr do_rmvar
    pop_r(0)
    pop_r(1)
    jmp do_setvar
}

.print "ptr_last_variable=$"+toHexString(ptr_last_variable)
.print "ptr_last_value=$"+toHexString(ptr_last_value)
.print "nb_variables=$"+toHexString(nb_variables)

//---------------------------------------------------------------
// do_rmvar : supprime une variable
// A = numéro variable à supprimer
//---------------------------------------------------------------

do_rmvar:
{
    sta to_supp

    // source
    stw_r(0, var_names)
    stw_r(2, var_values)
    // destination
    stw_r(1, var_names)
    stw_r(3, var_values)

    // recopie des noms, sauf si numéro à supprimer
    ldy #0
    ldx #0

copies:
    cpx to_supp
    bne copies_ok

    // à supprimer = passe nom et adresse valeur
    getbyte_r(0)
    cmp #0
    bne ok_suite
    jmp fin_copies

ok_suite:
    clc
    adc #3
    sta nb_to_copy

    sec
    lda ptr_last_variable
    sbc nb_to_copy
    sta ptr_last_variable
    dec nb_to_copy

passe_nom:
    getbyte_r(0)
    dec nb_to_copy
    bne passe_nom

    // puis passe valeur à supprimer

    getbyte_r(2)
    sta nb_to_copy

    inc nb_to_copy
    sec
    lda ptr_last_value
    sbc nb_to_copy
    sta ptr_last_value
    lda ptr_last_value+1
    sbc #0
    sta ptr_last_value+1
    dec nb_to_copy

passe_valeur:
    getbyte_r(2)
    dec nb_to_copy
    bne passe_valeur
    jmp suite_copie

    // ok = on recopie le nom, et la valeur
copies_ok:
    // stocke dest valeur r3 pour renseigner le nom ensuite dans r4
    str_r(4, 3)

    getbyte_r(2)
    sta nb_to_copy
    setbyte_r(3)
copie_valeur:
    getbyte_r(2)
    setbyte_r(3)
    dec nb_to_copy
    bne copie_valeur

    // copie le nom
    getbyte_r(0)
    cmp #0
    beq fin_copies
    sta nb_to_copy
    setbyte_r(1)
copie_nom:
    getbyte_r(0)
    setbyte_r(1)
    dec nb_to_copy
    bne copie_nom

    // et renseigne la destination de la valeur
    lda zr0+4*2
    setbyte_r(1)
    lda zr0+1+4*2
    setbyte_r(1)
    // et passes l'ancienne destination de valeur dans le nom
    getbyte_r(0)
    getbyte_r(0)

suite_copie:
    inx
    jmp copies

    // fin des copies : 1 variable de moins et update marquer dernier nom
fin_copies:
    lda nb_variables
    beq deja_zero
    dec nb_variables

deja_zero:
    lda #0
    setbyte_r(1)
    clc
    rts

to_supp:
    .byte 0
nb_to_copy:
    .byte 0
}

.print "do_rmvar=$"+toHexString(do_rmvar)

//---------------------------------------------------------------
// lookup_var : teste si une variable existe,
// r0 : nom variable
// C=1 et A = num var si existe et R1 = ptr data
// C=0 sinon
//
// appel complémentaire pour les commandes internes : 
// lookup_cmd
//---------------------------------------------------------------

lookup_cmd:
{
    stw_r(1, internal_commands)
    lda nb_cmd
    sta nb_var_work
    jmp lookup_gen
}

lookup_var:
{
    stw_r(1, var_names)
    lda nb_variables
    sta nb_var_work
}

lookup_gen:
{
    // si nb_variables = 0 => nouvelle variable
    lda nb_var_work
    beq nouvelle_variable

    // cherche dans la liste des noms à partir de R1
    //stw_r(1, var_names)
    lda #0
    sta num_var

    //-- même longueur, compare
check_name:
    ldy #0
    lda (zr1),y
    sta lgr_varname

    jsr compare_str
    bcs var_existe

    clc
    lda lgr_varname
    adc #3
    add_r(1)
    inc num_var
    lda num_var
    cmp nb_var_work

    beq nouvelle_variable
    bne check_name

var_existe:
    //-- la variable existe
    clc
    lda lgr_varname
    adc #1
    add_r(1)
    ldself_r(1)

    lda num_var
    sec
    rts

nouvelle_variable:
    lda #$ff
    clc
    rts

lgr_varname:
    .byte 0 
num_var:
    .byte 0
}
nb_var_work:
    .byte 0

//---------------------------------------------------------------
// compare_str : compare 2 pstrings, r0 vs r1, C=1 si OK
//---------------------------------------------------------------

compare_str:
{
    // si pas même longueur = KO
    ldy #0
    lda (zr0),y
    cmp (zr1),y
    bne comp_ko
    tay
do_comp:
    lda (zr0),y
    cmp (zr1),y
    bne comp_ko
    dey
    bne do_comp
    sec
    rts
comp_ko:
    clc
    rts
}

//---------------------------------------------------------------
// copy_str : copie pstring en r0 vers destination en r1
// en sortie A = longueur + 1 = longueur copiée
//---------------------------------------------------------------

do_copy_str:
{
    ldy #0
    lda (zr0),y
    pha
    tay
copie:
    lda (zr0),y
    sta (zr1),y
    dey
    bpl copie
    pla
    clc
    adc #1
    rts
}

//---------------------------------------------------------------
// print_path : affiche les éléments d'un objet ppath, pour
// debug
// r0 = objet ppath
// rappel ppath : type, device, partition, path, nom
//---------------------------------------------------------------

do_print_path:
{
    push_r(0)
    // type et dev
    getbyte_r(0)
    sta zr4h
    getbyte_r(0)
    sta zr4l
    // ignore partition
    getbyte_r(0)
    // path
    str_r(5, 0)
    getbyte_r(0)
    add_r(0)
    // name
    str_r(6, 0)
    call_bios(bios.pprintnl, msg_path)
    pop_r(0)
    rts
msg_path:
    pstring("TYPE/DEVICE (%R4) PATH (%P5) NAME (%P6)")
}

//---------------------------------------------------------------
// prep_path2 : prépare un objet path
// entrée : r0 = chaine à traiter, r1 = destination ppath
// c=0 mode normal, c=1 force path seulement (pour CD)
// format en entrée :
//
// [device:][partition][/path/][file]
//---------------------------------------------------------------

do_prep_path2:
{
    lda #0
    rol
    sta mode_path

    push_r(0)
    ldy #4
    lda #0
raz_path:
    sta (zr1),y
    dey
    bpl raz_path
    tay
    getbyte_r(0)
    sta lgr_entree
    bne process_entree
fin_prep_path:
    pop_r(0)
    clc
    rts

process_entree:
    getbyte_r(0)
    dec lgr_entree
    jsr is_digit
    bcc pas_device_partition
    jsr extract_device_partition
    bcs syntax_error
    dec_r(0)
    jsr convert_device_partition
pas_device_partition:
    push_r(1)
    jsr extract_path_name
    pop_r(1)
    jsr update_path_type
    jmp fin_prep_path

syntax_error:
    lda #2
    sta $d021
    sec
    rts

    // extraction device/partition, forme
    // [device:][partition]
    // max 2 digits et 3 digits

extract_device_partition:
    sty str_device
    sty str_partition
    iny
extr_device:
    ldy str_device
    cpy #2
    beq syntax_error
    iny
    sta str_device,y
    inc str_device
    ldy #0
    getbyte_r(0)
    dec lgr_entree
    cmp #':'
    beq fin_device
    cmp #'/'
    beq fin_device_partition_only
    bne extr_device

fin_device:
    getbyte_r(0)
    dec lgr_entree
    jsr is_digit
    bcc fin_device_only
extr_partition:
    ldy str_partition
    cpy #3
    beq syntax_error
    iny
    sta str_partition,y
    inc str_partition
    ldy #0
    getbyte_r(0)
    dec lgr_entree
    jsr is_digit
    bcs extr_partition
    rts
fin_device_only:
    rts
fin_device_partition_only:
    rts

str_device:
    pstring("00")
str_partition:
    pstring("000")

.print "str_device=$"+toHexString(str_device)
.print "str_partition=$"+toHexString(str_partition)

    // convert_device_partition : conversion en int
    // et stockage dans le PPATH, mise à jour TYPE

convert_device_partition:
    push_r(0)
    str_r(2, 1)
    stw_r(0, str_device)
    jsr bios.do_str2int
    pha
    stw_r(0, str_partition)
    jsr bios.do_str2int
    pha
    str_r(1, 2)
    ldy #2
    pla
    sta (zr1),y
    beq pas_int_partition
    ldy #0
    lda (zr1),y
    ora #PPATH.WITH_PARTITION
    sta (zr1),y
pas_int_partition:
    ldy #1
    pla
    sta (zr1),y
    beq pas_int_device
    dey
    lda (zr1),y
    ora #PPATH.WITH_DEVICE
    sta (zr1),y
pas_int_device:
    ldy #0
    pop_r(0)
    clc
    rts

    // extract_path_name : extraction path et nom
    // de fichier : [/PATH/][FICHIER]
    // en fonction du mode_path :
    // si mode_path = on prend toute la chaine restante
    // si pas mode_path = si la fin est / = idem
    // si la fin n'est pas / : fichier seul si pas de /,
    // sinon path[dernier/]fichier

extract_path_name:
    cmp #':'
    bne pas_sep_device
    getbyte_r(0)
    dec lgr_entree
pas_sep_device:
    sta lu
    ldy mode_path
    beq pas_do_mode_path
    jmp do_mode_path
pas_do_mode_path:
    // dernier caractère = / => comme mode_path
    push_r(0)
    lda lgr_entree
    add_r(0)
    getbyte_r(0)
    cmp #'/'
    bne pas_path_only
    jmp path_only
pas_path_only:
    pop_r(0)

    // sinon parcours et découpe sur dernier / ou si :, 
    // sauf // au début ? -> pas testé
    // recherche en partant de la fin

    ldy lgr_entree
cherche_nom:
    lda (zr0),y
    cmp #':'
    beq nom_trouve
    cmp #'/'
    beq nom_trouve
    dey
    bne cherche_nom

nom_pas_trouve:
    // pas de séparateur = nom seul
    push_r(0)
    jmp name_only

    // ici r0 = début du path, r1 = destination
    // Y = nb de caractères - 1 de la partie path
    // lgr_entrée = lgr chaine restante path + nom - 1

nom_trouve:
    // copie la partie path, vers R1+4
    // conserve longueur nom = lgr entrée - y
    iny
    tya
    tax
    sta lgr_path
    sec
    lda lgr_entree
    sbc lgr_path
    sta lgr_nom
    //inx
    // stocke la longueur
    ldy #0
    // et copie le path
    lda #3
    add_r(1)
    lda lgr_path
    setbyte_r(1)
copie_partie_path:
    getbyte_r(0)
    setbyte_r(1)
    dex
    bne copie_partie_path

    // ici R1 = position écriture filename
    // r0 = prochaine lecture = 1er caractère nom
    
    // écriture longueur nom
    lda lgr_nom
    tax
    inx
    txa
    setbyte_r(1)
copie_partie_nom:
    getbyte_r(0)
    setbyte_r(1)
    dex
    bne copie_partie_nom

    clc
    rts

name_only:
    lda #PPATH.WITH_NAME
    sta update_path_name
    // mode path, toute la chaine en entrée = path
path_only:
    pop_r(0)

do_mode_path:
    // mode path : on recopie tout dans le path
    // cible = r1 + 4
    push_r(1)
    ldy #0
    lda #3
    add_r(1)
    push_r(1)
    inc_r(1)
    tya
    sty lgr_path
    lda lu
copie_path:
    getbyte_r(0)
    setbyte_r(1)
    inc lgr_path
    dec lgr_entree
    bpl copie_path
    pop_r(1)
    // écriture longueur + longueur 0 pour nom
    // de fichier (non présent)
    lda lgr_path
    ldy #0
    setbyte_r(1)
    add_r(1)
    inc_r(1)
    tya
    setbyte_r(1)

    // update type |= WITH_PATH sauf si lgr path = 0
    pop_r(1)
    ldy #3
    lda (zr1),y
    beq path_vide
    ldy #0
    lda (zr1),y
    ora update_path_name:#PPATH.WITH_PATH
    sta (zr1),y
    lda PPATH.WITH_PATH
    sta update_path_name
path_vide:
    ldy #0
    clc
    rts

    // mise à jour type path avec présence path / filename

update_path_type:
    ldy #0
    lda (zr1),y
    and #PPATH.WITH_NAME
    bne pas_update
    lda (zr1),y
    sta lu
    ldy #3
    lda (zr1),y
    clc
    adc #4
    tay
    lda (zr1),y
    beq update_path_seul
    lda lu
    ora #PPATH.WITH_NAME
    sta lu
update_path_seul:
    lda lu
    ora #PPATH.WITH_PATH
    ldy #0
    sta (zr1),y
pas_update:
    rts

.print "lgr_entree=$"+toHexString(lgr_entree)

lu:
    .byte 0
lgr_nom:
    .byte 0
lgr_path:
    .byte 0
lgr_entree:
    .byte 0
mode_path:
    .byte 0
}

//---------------------------------------------------------------
// is_digit : C=1 si A est un digi, C=0 sinon
//---------------------------------------------------------------

is_digit:
{
    cmp #'0'
    bmi not_digit
    cmp #$3a
    bpl not_digit
    sec
    rts
not_digit:
    clc
    rts
}

//---------------------------------------------------------------
// prep_path : prépare un objet path
// 
// entrée : r0 = pstring path, r1 = destination stockage path
// sortie : objet path à jour
//
// objet path:
// - byte = device ou 0
// - byte = partition ou 0 (non géré pour l'instant)
// - pstring reste du path
// - pstring nom de fichier
// 
// format du path :
// [<device>:][[<partition>][/ ou //<path>/]][:<filename>]
// partition = 0 si pas de partition = partition courante
// device = 0 si pas de device indiqué = device courant
// work_path = partie chemin + nom de fichier
//---------------------------------------------------------------

do_prep_path:
{
    // cas : 
    // - chaine vide
    // - extraction device
    // - extraction partition
    // - extraction path
    // - extraction filename

    // raz destination
    ldy #0
    sty type_path
    tya
    tax

raz_path:
    sta (zr1),y
    iny
    cpy #5
    bne raz_path

    // lecture longueur chaine, sortie si vide
    ldy #0
    lda (zr0),y
    beq erreur_chaine_vide
    sta lgr_max
    iny

    // recherche device
    jsr get_path_device
    bcs pas_numero_device
    
    tya
    pha
    lda #1
    sta type_path
    push_r(0)
    push_r(1)
    stw_r(0, buffer_numero)
    jsr bios.do_str2int
    tax
    pop_r(1)
    pop_r(0)
    ldy #1
    txa
    sta (zr1),y
    pla
    tay

    // si fini, wrap up

    dey
    cpy lgr_max
    beq fin_ok_prep_path
    iny

pas_numero_device:

    // recherche path ou nom de fichier
    jsr get_path_filename
    bcc pas_separation_path_filename

    // séparation 

    lda type_path
    ora #8+4
    sta type_path
    jmp fin_ok_prep_path

    // fin KO
erreur_chaine_vide:
    sec
    rts


    // pas de séparation, copie juste filename
pas_separation_path_filename:
    
    sta lgr_max

    clc
    tya
    sta ztmp
    add_r(0)

    // ajuste la destination, utilise r2 pour
    // la copie et conserver r1

    str_r(2,1)
    clc
    lda #3
    add_r(2)
    inc_r(2)
    ldx #0
    ldy #0
copie_nom:
    getbyte_r(0)
    setbyte_r(2)
    inx
    dec lgr_max
    bpl copie_nom

    // écriture lgr copiée dans r1+3
    dex
    txa
    ldy #3
    sta (zr1),y

    // update type path = nom seul
    // et enregistre dans le path
    lda type_path
    ora #4
    sta type_path

fin_ok_prep_path:
    ldy #0
    lda type_path
    sta (zr1),y
    clc
    rts


    //------------------------------------------------------
    // get_path_filename : recherche path / nom de fichier
    // parcours la chaine jusqu'à la fin, si présence
    // caractère : = il y a un path et le nom de fichier
    // se trouve après :, sinon on a juste un nom de fichier
    // retour : C = 0 si pas de path, X = 0
    // C = 1 si path, X = début nom de fichier
    // en retour A = nb de caractères total à copier
    //------------------------------------------------------

get_path_filename:
    tya
    pha
    ldx #0
    stx nb_a_copier
    inc lgr_max

boucle_path_filename:
    lda (zr0),y
    inc nb_a_copier
    cmp #':'
    bne pas_fichier
    tya
    tax
    inx

boucle_fin_chaine:
    cpy lgr_max
    beq fin_chaine
    inc nb_a_copier
    iny
    bne boucle_fin_chaine

fin_chaine:
    pla
    tay
    dec lgr_max
    sec
    rts

pas_fichier:
    iny
    cpy lgr_max
    bne boucle_path_filename
    pla
    tay
    lda nb_a_copier
    dec lgr_max
    clc
    rts

nb_a_copier:
    .byte 0

    //------------------------------------------------------
    // get_path_device : récupère un numéro si existant
    // format numéro <99>: -> 2 digits max, fin par :
    // retour numéro dans buffer_numero, C=0, 
    // Y = caractère suivant
    // si pas numero, C = 1, Y = position de départ
    //------------------------------------------------------

get_path_device:
    tya
    pha
    ldx #0
    stx buffer_numero
boucle_path_device:
    lda (zr0),y
    cmp #':'
    beq fin_path_device
    cmp #'/'
    beq erreur_path_device
    cmp #'0'
    bcc erreur_path_device
    cmp #$3a
    bpl erreur_path_device
    // digit ok
    sta buffer_numero+1,x
    iny
    cpy lgr_max
    beq fin_path_device_lgr
    inx
    cpx #3
    bne boucle_path_device
erreur_path_device:
    pla
    tay
    sec
    rts
fin_path_device_lgr:
    inx
fin_path_device:
    iny
    pla
    //tay //tmp
    stx buffer_numero
    clc
    rts

type_path:
    .byte 0
lgr_max:
    .byte 0
pos_fin_num:
    .byte 0
buffer_numero:
    .byte 0, 0, 0
.print "buffer_numero=$"+toHexString(buffer_numero)
.print "***lgr_max=$"+toHexString(lgr_max)
}

//---------------------------------------------------------------
// lsblk : scan des disques, retour dans bios.devices et 
// nb_devices.
// en entrée si C=1 mode silencieux
// retour A = nb devices, X = 1er device trouvé
//---------------------------------------------------------------
// 00 - No serial device available
// 01 - foreign drive (MSD, Excelerator, Lt.Kernal, etc.)
// 41 - 1541 drive
// 71 - 1571 drive
// 81 - 1581 drive
// e0 - FD drive
// c0 - HD drive
// f0 - RD drive
// 80 - RAMLink
// si %11xxxxxx : capacités CMD
//---------------------------------------------------------------

do_lsblk:
{
    lda #0
    rol
    sta affichage_lecteurs

    //-- raz liste et nb de devices
    ldy #31
    lda #0
    sta first_device
    sta nb_devices
raz_devices:
    sta devices,y
    dey
    bpl raz_devices


    lda #8
    sta cur_device
test_listen:
    lda cur_device
    ldy #0
    sty STATUS
    jsr LISTEN
    lda #$ff
    jsr SECOND
    lda STATUS
    bpl dev_present
    jsr UNLSTN

next_device:
    inc cur_device
    lda cur_device
    cmp #31
    beq fin_test_listen
    bne test_listen

dev_present:
    lda first_device
    bne premier_deja_trouve
    lda cur_device
    sta first_device
premier_deja_trouve:
    ldy cur_device
    tya
    sta devices,y
    inc nb_devices
    bne next_device

fin_test_listen:

    //-- après test listen, recherche type drive
    ldy #8
    lda devices,y
    bne test_type_drive
    jmp boucle_drive

test_type_drive:

    sta cur_device
    jsr open_cmd
    ldx #<cmdinfo // test CMD drive
    ldy #>cmdinfo
    jsr send_cmd

    // retour commande, est-ce FD ?
    jsr CHRIN
    cmp #'F'
    bne pas_fd
    jsr CHRIN
    cmp #'D'
    bne test_cbm15xx

    lda #$e0
    jmp next_drive

pas_fd:
    // est-ce HD ?
    cmp #'H'
    bne pas_hd
    jsr CHRIN
    cmp #'D'
    bne test_cbm15xx

    lda #$c0
    jmp next_drive

pas_hd:
    // est-ce RL / RD ?
    cmp #'R'
    bne test_cbm15xx
    jsr CHRIN
    cmp #'D'
    bne pas_rd

    lda #$f0
    jmp next_drive

pas_rd:
    cmp #'L'
    bne test_cbm15xx

    lda #$80
    jmp next_drive


    //-- test 1541/1571
test_cbm15xx:
    jsr close_cmd
    jsr open_cmd
    ldx #<cbminfo
    ldy #>cbminfo
    jsr send_cmd

    jsr CHRIN
    cmp #'5'
    bne test_cbm1581
    jsr CHRIN
    cmp #'4'
    bne pas_1541

    lda #41
    jmp next_drive

pas_1541:
    cmp #'7'
    bne test_cbm1581

    lda #71
    jmp next_drive

test_cbm1581:
    jsr close_cmd
    jsr open_cmd
    ldx #<info1581
    ldy #>info1581
    jsr send_cmd

    jsr CHRIN
    cmp #'5'
    bne pas_cbm1581
    jsr CHRIN
    cmp #'8'
    bne pas_cbm1581

    lda #81
    jmp next_drive

    // other, valeur $01
pas_cbm1581:
    lda #1

next_drive:
    ldy cur_device
    sta devices,y
    jsr close_cmd

boucle_drive:
    inc cur_device
    lda cur_device
    cmp #31
    beq fin_lsblk
    ldy cur_device
    lda devices,y
    beq boucle_drive

    jmp test_type_drive

    // fin des tests, affiche la liste si pas en
    // mode silencieux
fin_lsblk:
    lda affichage_lecteurs
    bne pas_affichage
    jsr affiche_lecteurs
pas_affichage:
    lda nb_devices
    ldx first_device
    clc
    rts

affiche_lecteurs:
    lda #0
    sta cur_device

aff_suivant:
    ldy cur_device
    lda devices,y
    beq pas_present

    tya
    jsr aff_numero_drive
    lda #':'
    jsr CHROUT

    //-- type lecteur
    ldy cur_device
    lda devices,y
    jsr affiche_type

pas_present:
    inc cur_device
    lda cur_device
    cmp #31
    bne aff_suivant

fin_aff_total:
    lda #13
    jsr CHROUT
    rts

affiche_type:
    cmp #1
    bne aff_pas_autre
    lda #'O'
    jsr CHROUT
    lda #'T'
    jsr CHROUT
    lda #'H'
    jsr CHROUT
    lda #'R'
    jsr CHROUT
    jmp fin_aff_type

aff_pas_autre:
    cmp #$80
    bne aff_pas_ram

    lda #'R'
    jsr CHROUT
    lda #'A'
    jsr CHROUT
    lda #'M'
    jsr CHROUT
    lda #'L'
    jsr CHROUT
    jmp fin_aff_type

aff_pas_ram:
    cmp #$c0
    bne aff_15xx
    cmp #$e0
    bne aff_15xx
    cmp #$f0
    bne aff_15xx
    tax
    lda #32
    jsr CHROUT
    txa
    cmp #$e0
    bne aff_pas_e
    lda #'F'
    jsr CHROUT
    jmp aff_fin_hd
aff_pas_e:
    cmp #$c0
    bne aff_pas_c
    lda #'H'
    jsr CHROUT
    jmp aff_fin_hd
aff_pas_c:
    lda #'R'
    jsr CHROUT
aff_fin_hd:
    lda #'D'
    jsr CHROUT
    lda #32
    jsr CHROUT
    jmp fin_aff_type

aff_15xx:
    tax
    lda #'1'
    jsr CHROUT
    lda #'5'
    jsr CHROUT
    txa
    cmp #41
    bne aff_pas41
    lda #'4'
    jmp fin_aff_15xx
aff_pas41:
    cmp #71
    bne aff_pas71
    lda #'7'
    jmp fin_aff_15xx
aff_pas71:
    lda #'8'
fin_aff_15xx:
    jsr CHROUT
    lda #'1'
    jsr CHROUT

fin_aff_type:
    lda #32
    jsr CHROUT
    rts

    //-- ouverture pour envoi commande
open_cmd:
    lda #$0f // 15,dev,15
    tay
    ldx cur_device
    jsr SETLFS
    lda #7 // longueur commande m-r
    rts

    //-- envoi commande
send_cmd:
    jsr SETNAM
    jsr OPEN
    ldx #$0f  // 15
    jsr CHKIN // redirect input
    rts

    //-- fermeture cmd
close_cmd:
    ldx #15
    jmp bios.do_file_close

.print "devices=$"+toHexString(devices)

aff_numero_drive:
    sta zr0l
    lda #0
    sta zr0h
    lda #%00000011
    jmp do_print_int

first_device:
    .byte 0
cur_device:
    .byte 0
affichage_lecteurs:
    .byte 0

cmdinfo: // CMD info at $fea4 in drive ROM
    .text "M-R"
    .byte $a4,$fe,$02,$0d
cbminfo: // 1541, 1571, info at $e5c5
    .text "M-R"
    .byte $c5,$e5,$02,$0d
info1581: // 1581, info at $a6e8
    .text "M-R"
    .byte $e8,$a6,$02,$0d
}

//----------------------------------------------------
// file_close : fermeture fichier
// entrée : X = canal
//----------------------------------------------------

do_file_close:
{
    txa
    jsr CLOSE
    jsr CLRCHN
    clc
    rts
}

//----------------------------------------------------
// file_readline : lecture d'une ligne dans un fichier
// sortie : work_buffer, A = longueur
// c=0 : ok, c=1 : fin de fichier
// lecture de 255 octets max
//----------------------------------------------------

do_file_readline:
{
    ldy #0
    sty work_buffer

boucle_lecture:
    jsr READST
    bne fin_lecture
    jsr CHRIN
    cmp #13
    beq fin_ligne
    cmp #10
    beq fin_ligne
    sta work_buffer+1,y
    iny
    bne boucle_lecture
    
    // todo ici  : erreur dépassement buffer
erreur:
    inc $d020
    jmp erreur

fin_ligne:
    sty work_buffer
    clc
    rts

fin_lecture:
    sty work_buffer
    sec
    rts
}

//----------------------------------------------------
// str_empty : teste si la chaine en r0 est vide
// retour C=0 si vide, C=1 si non vide
//----------------------------------------------------

do_str_empty:
{
    ldy #0
    lda (zr0),y
    sta lgr_chaine
    beq est_vide
test_vide:
    getbyte_r(0)
    cmp #32
    beq suite_test_vide
    cmp #9
    beq suite_test_vide
    bne non_vide

suite_test_vide:
    dec lgr_chaine
    bne test_vide

est_vide:
    clc
    rts
non_vide:
    sec
    rts
lgr_chaine:
    .byte 0
}

//----------------------------------------------------
// set_device_from_path : r0 = ppath
//----------------------------------------------------

do_set_device_from_path:
{
    ldx bios.device
    ldy #0
    lda (zr0),y
    and #PPATH.WITH_DEVICE
    beq pas_device_1
    iny
    lda (zr0),y
    dey
    tax
    jmp do_set_device_from_int
pas_device_1:
    ldx bios.save_device
    jmp do_set_device_from_int
}

//----------------------------------------------------
// write_buffer : ecriture bufferisée
// entrée : R0 = buffer d'écriture, pstring
// X = id fichier
//----------------------------------------------------

do_write_buffer:
{
    jsr CHKOUT
    ldy #1
    sty pos_lecture
    dey
    lda (zr0),y
    sta nb_lu
ecriture:
    ldy pos_lecture
    lda (zr0),y
    jsr CHROUT
    inc pos_lecture
    dec nb_lu
    bne ecriture
    jsr CLRCHN
    clc
    rts

nb_lu:
    .byte 0
pos_lecture:
    .byte 0
}

//----------------------------------------------------
// read_buffer : lecture bufferisée
// entrée : R0 = buffer de lecture (pstring)
// X = id fichier
// sortie : buffer à jour
// C=0 si pas fini, C=1 si EOF
//----------------------------------------------------

do_read_buffer:
{
    jsr CHKIN

    lda #0
    sta nb_lu

lecture:
    jsr READST
    bne fin_lecture
    inc nb_lu
    jsr CHRIN
    ldy nb_lu
    sta (zr0),y
    cpy #255
    beq fin_buffer
    bne lecture
fin_buffer:
    lda nb_lu
    ldy #0
    sta (zr0),y
    jsr CLRCHN
    lda #'.'
    jsr CHROUT
    clc
    rts

fin_lecture:
    and #$40
    beq pas_erreur
    // erreur lecture à gérer
pas_erreur:
    lda nb_lu
    ldy #0
    sta (zr0),y
    jsr CLRCHN
    lda #13
    jsr CHROUT
    sec
    rts

nb_lu:
    .byte 0
}

//----------------------------------------------------
// file_open : ouverture fichier en lecture
// r0 : pstring nom, X = canal
// C=0 : lecture, C=1 : écriture
// retour C=0 OK, C=1 KO
// le fichier est ouvert en X,<device>,X
//----------------------------------------------------

msg_nom:
    pstring("NOM=[%P5]")
do_file_open:
{
    lda #0
    rol
    sta read_write
    stx canal
    push_r(0)
    str_r(5, 0)
    call_bios(bios.pprintnl, msg_nom)
    // ensure current device
    jsr bios.do_set_device
    pop_r(0)

    // set name
    ldy #0
    getbyte_r(0)
    ldx zr0l
    ldy zr0h
    jsr SETNAM

    ldy #0
    getbyte_r(0)
    ldy canal
    cmp #'$'
    bne not_directory
    ldy #0
not_directory:
    // open X,dev,X (ou 0 si directory)
    // canal secondaire = identique à primaire, attention
    // si 0 ou 1 ça force read / write sur du PRG
    lda canal
    ldx bios.device

    jsr SETLFS

    jsr OPEN    
    bcs error

    //sec // tmp
    bios(get_device_status)
    bcs error

    // si read = CHKIN, sinon CHKOUT
    lda read_write
    bne write
    //ldx canal
    //jsr CHKIN
    clc
    rts
write:
    //ldx canal
    //jsr CHKOUT
    clc
    rts

error:
    ldx bios.device
    jsr do_file_close
    sec
    rts

read_write:
    .byte 0
canal:
    .byte 0
}

//----------------------------------------------------
// build_path : construction path cible
// entrée : r0 = adresse pstring résultat
// r1 = ppath source
// sortie = r0 à jour
//----------------------------------------------------

do_build_path:
{
    ldy #0
    tya
    sta (zr0),y
    lda (zr1),y
    and #PPATH.WITH_PATH
    beq pas_path
    push_r(1)
    lda #3
    add_r(1)
    bios(bios.add_str)
    pop_r(1)
pas_path:
    ldy #0
    lda (zr1),y
    and #PPATH.WITH_NAME
    beq pas_name

    lda #3
    add_r(1)
    ldy #0
    lda (zr1),y
    add_r(1)
    bios(bios.add_str)
pas_name:
    clc
    rts
}

//----------------------------------------------------
// get_device_status : current device status
// si C=1 en entrée, affiche, sinon mode silencieux
// renvoie le code status sur 2 positions en R0,
// C=0 si code 00 = OK, C=1 dans les autres cas
//----------------------------------------------------

do_get_device_status:
{
    lda #0
    sta STATUS
    rol
    sta silencieux

    jsr bios.do_set_device
    
    jsr LISTEN     // call LISTEN
    lda #$6F       // secondary address 15 (command channel)
    jsr SECOND     // call SECLSN (SECOND)
    jsr UNLSTN     // call UNLSTN
    lda STATUS
    bne devnp       // device not present

    lda bios.device
    jsr $FFB4     // call TALK
    lda #$6F      // secondary address 15 (error channel)
    jsr $FF96     // call SECTLK (TKSA)

    jsr IECIN     // call IECIN (get byte from IEC bus)
    sta code_status+1
    jsr aff_si_ok
    jsr IECIN
    sta code_status+2
    jsr aff_si_ok

lecture_reste:
    jsr IECIN
    jsr aff_si_ok
    cmp #13
    bne lecture_reste

    jsr UNTLK

    stw_r(0, code_status)
    jsr bios.do_str2int
    beq code_ok
    sec
    rts

code_ok:
    clc
    rts

aff_si_ok:
    ldy silencieux
    beq pas_aff
    jmp CHROUT
pas_aff:
    rts

code_status:
    pstring("00")
devnp:
    call_bios(bios.error, msg_error.device_not_present)
    rts

silencieux:
    .byte 0
.print "code_status=$"+toHexString(code_status)
}

//---------------------------------------------------------------
// print_int : affichage entier
// entier dans r0
// A = format, %PL123456
// bit 7 = padding avec espace (avec 0 sinon)
// bit 6 = suppression espaces en tête
//---------------------------------------------------------------

do_print_int:
{
    sta format
    and #%10000000
    sta padding_space
    lda format
    and #%01000000
    sta write_space
    lda #%00100000
    sta test_format
    lda #1
    sta do_padding
    txa
    pha
    stw_r(1, int_conv)
    jsr bios.do_int2str

    ldx #0
suite_affiche:
    lda format
    and test_format
    beq pas_affiche
    lda int_conv+1,x
    cmp #$30
    bne pas_test_padding

    lda padding_space
    bmi test_padding
    lda int_conv+1,x
    bne affiche

test_padding:
    lda do_padding
    beq padding_fini

    lda write_space
    beq pas_affiche

    lda #32
    bne affiche
padding_fini:
    lda #$30
affiche:
    jsr CHROUT
pas_affiche:
    clc
    lsr test_format
    inx
    cpx #6
    bne suite_affiche
    pla
    tax
    rts
pas_test_padding:
    jsr CHROUT
    lda #0
    sta do_padding
    jmp pas_affiche

format:
    .byte 0
test_format:
    .byte 0
padding_space:
    .byte 0
write_space:
    .byte 0
do_padding:
    .byte 0
}

//===============================================================
// DATAS BIOS namespace
//===============================================================

nb_variables:       // nb de variables définies       
    .byte 0             
nb_cmd:             // nb de commandes internes
    .byte 0
ptr_last_variable:  // position libre var
    .word variables_end 
ptr_last_value:     // position libre valeurs
    .word values_end
device:             // current device
    .byte 0
save_device:
    .byte 0
devices:            // devices présents avec leur type
    .fill 32,0
nb_devices:         // nb de devices présents
    .byte 0

    // color scheme
color_scheme:
screen_fg:
    .byte 0
screen_bg:
    .byte 0
color_text:
    .byte 5
color_error:
    .byte 2

} // namespace bios

//===============================================================
// call_bios : call bios function with word parameter in r0
//===============================================================

.macro call_bios(bios_func, word_param)
{
    stw_r(0, word_param)
    lda #bios_func
    jsr bios.bios_exec
}

//===============================================================
// bios : call bios function without parameters
//===============================================================

.macro bios(bios_func)
{
    lda #bios_func
    jsr bios.bios_exec
}