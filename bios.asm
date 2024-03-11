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
.label var_set=3
.label var_get=4
.label var_del=5
.label input=6
.label var_count=7
.label list_add=8
.label list_get=9
.label file_load=10
.label set_device=11
.label str_cat=12
.label str_cpy=13
.label list_del=14
.label list_print=15
.label list_size=16
.label error=17
.label list_reset=18
.label str_empty=19
.label prep_path=20
.label lsblk=21
.label pprinthex=22
.label pprinthex8=23
.label hex2int=24
.label file_open=25
.label get_device_status=26
.label file_close=27
.label build_path=28
.label set_device_from_path=29
.label buffer_read=30
.label buffer_write=31
.label str_expand=32
.label str_pat=33
.label print_path=34
.label str_cmp=35
.label str_chr=36
.label str_lstrip=37
.label str_len=38
.label str_del=39
.label str_ins=40
.label str_rchr=41
.label str_ncpy=42
.label file_readline=43
.label str_split=44
.label directory_open=45
.label directory_set_filter=46
.label directory_get_entry=47
.label directory_close=48
.label is_filter=49
.label picture_show=50
.label key_wait=51
.label directory_get_entries=52
.label wait=53
.label pprint_int=54
.label parameters_loop=55
.label script_read=56

bios_jmp:
    .word do_reset
    .word do_pprint
    .word do_pprintnl
    .word do_var_set
    .word do_var_get
    .word do_var_del
    .word do_input
    .word do_var_count
    .word do_list_add
    .word do_list_get
    .word do_file_load
    .word do_set_device
    .word do_str_cat
    .word do_str_cpy
    .word do_list_del
    .word do_list_print
    .word do_list_size
    .word do_error
    .word do_list_reset
    .word do_str_empty
    .word do_prep_path
    .word do_lsblk
    .word do_pprinthex
    .word do_pprinthex8
    .word do_hex2int
    .word do_file_open
    .word do_get_device_status
    .word do_file_close
    .word do_build_path
    .word do_set_device_from_path
    .word do_buffer_read
    .word do_buffer_write
    .word do_str_expand
    .word do_str_pat
    .word do_print_path
    .word do_str_cmp
    .word do_str_chr
    .word do_str_lstrip
    .word do_str_len
    .word do_str_del
    .word do_str_ins
    .word do_str_rchr
    .word do_str_ncpy
    .word do_file_readline
    .word do_str_split
    .word do_directory_open
    .word do_directory_set_filter
    .word do_directory_get_entry
    .word do_directory_close
    .word do_is_filter
    .word do_picture_show
    .word do_key_wait
    .word do_directory_get_entries
    .word do_wait
    .word do_print_int
    .word do_parameters_loop
    .word do_script_read
    
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

    // lookup how many variables and commands are available at startup
    swi var_count, var_names
    sta nb_variables
    swi var_count, internal_commands
    sta nb_cmd

    // script reset
    lda #0
    sta script_data

    // print banner
    swi pprintnl, text_banner

    // check present devices
    sec
    swi lsblk
    stx bios.device
    // ici A = nb devices et X = 1er device

    // tente de sélectionner le device dans variable device
    swi set_device
    bcc device_ok

    // si KO essaye le 1er device trouvé
    ldx bios.device
    jsr bios.do_set_device_from_int

device_ok:
    // start shell
    clc
    jmp shell.toplevel

text_banner:
    pstring("%CR%HFA %HC2YG %HD3HELL V%VVERSION%                        %CN")
}

//---------------------------------------------------------------
// str_len : renvoie dans A la longueur de la pstring en R0
//---------------------------------------------------------------

do_str_len:
{
    ldy #0
    mov a, (r0)
    rts
}

//---------------------------------------------------------------
// str_lstrip : enleve les espaces en début de chaine
// entrée : R0, sortie : R0 modifié
//---------------------------------------------------------------

do_str_lstrip:
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
    add r0, a
fini:
    clc
    rts

longueur:
    .byte 0
}

//---------------------------------------------------------------
// is_filter : C=1 si filtre fichier dans R0 (? ou *)
//---------------------------------------------------------------

do_is_filter:
{
    swi str_len
    tay
test_str:
    lda (zr0),y
    cmp #'*'
    beq filtre_trouve    
    cmp #'?'
    beq filtre_trouve    
    dey
    bne test_str
    clc
    rts
filtre_trouve:
    sec
    rts
}

//---------------------------------------------------------------
// wait : attente r0 vblanks, entrée = r0 hexa
//---------------------------------------------------------------

do_wait:
{
    swi hex2int
boucle_w0:
    dec zr0l
    beq boucle_w1
    lda #$f0
wait_v:
    cmp $d012
    bne wait_v
wait_v2:
    cmp $d012
    beq wait_v2
    jmp boucle_w0
boucle_w1:
    lda zr0h
    beq fin_wait
    dec zr0h
    bne boucle_w0
fin_wait:
    clc
    rts
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
    push r0
    ldy #0
    sty zr1l
    sty zr1h
    mov a, (r0++)
    sta lgr_str
    cmp #0
    bne next_char
    pop r0
    tya
    clc
    rts
next_char:
    mov a, (r0++)
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
    pop r0
    lda zr1l
    clc
    rts
pas_int:
    pop r0
    sec
    rts
lgr_str:
    .byte 0    
}

//----------------------------------------------------
// do_var_count : compte le nombre de variables ou de
// commandes dispos, en entrée r0 = source
// en sortie : A = nb variables
//----------------------------------------------------

do_var_count:
{
    ldy #0
    sty nb_variables

boucle:
    getbyte_r(0)
    cmp #0
    beq fin

    add r0, a
    lda #2
    add r0, a
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
    push r0
    swi pprint, msg_error
    pop r0
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
// do_hex2int.conv_hex_byte
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

//----------------------------------------------------
// set_device_from_path : r0 = ppath
//----------------------------------------------------

do_set_device_from_path:
{
    // sauve le device courant
    ldx bios.device
    stx bios.save_device

    // lecture type ppath pour voir si device indiqué
    ldy #0
    lda (zr0),y
    and #PPATH.WITH_DEVICE
    beq pas_device_1

    // si indiqué, lecture int device et update
    iny
    lda (zr0),y
    dey
    tax

    // sinon récup device courant sauvegardé
pas_device_1:
    jmp do_set_device_from_int
}

//---------------------------------------------------------------
// set_device_from_int : sélectionne device avec la valeur
// en entrée device dans X
//---------------------------------------------------------------

do_set_device_from_int:
{
    push r0
    // conversion int en str
    stx zr0l
    stx device_tmp
    lda #0
    sta zr0h
    mov r1, #int_conv
    jsr do_int2str
    swi str_lstrip, int_conv

    // remplace la variable DEVICE
    mov r1, r0
    swi var_set, do_set_device.text_device
    pop r0
    lda device_tmp
    jmp do_set_device.set_device
device_tmp:
    .byte 0
    .print "int_conv=$"+toHexString(int_conv)
}

//---------------------------------------------------------------
// set_device : sélectionne device en fonction de la valeur dans
// la variable DEVICE
//---------------------------------------------------------------

do_set_device:
{
    // lecture variable device
    swi var_get, text_device
    mov r0, r1
    jsr do_str2int
    // si pas int, no device
    bcs no_device

set_device:
    tay
    lda devices,y
    // si pas dans la liste des devices OK = device not present
    beq no_device

    tya
    sta bios.device
    clc
    rts

no_device:
    swi error, msg_error.device_not_present
    sec
    rts

text_device:
    pstring("DEVICE")
}

//---------------------------------------------------------------
// str_cat : ajoute une chaine
// r0 = r0 + r1
// sortie Y = 0
//---------------------------------------------------------------

do_str_cat:
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
// r0 = nom fichier
// si c=1 utilise R1 comme adresse de chargement et ne tente pas
// de lancement, sinon utilise l'adresse présente dans le
// fichier, vérifie la présence d'un SYS et lance en $080D
// à revoir utilisation du path pour lancement commande
//---------------------------------------------------------------

do_file_load:
{
    stc avec_adresse_dest
    mov adresse_dest, r1
    jsr test_load
    bcc load_ok

erreur:
    swi error, msg_error.command_not_found
    rts

load_ok:
    lda avec_adresse_dest
    beq run_binary
    clc
    rts

run_binary:
    // vérifie présence SYS XXXX
    lda $0805
    cmp #$9e
    bne erreur
    lda $080a
    bne erreur

    // récupère les infos des paramètres avant le saut
    // A = présence paramètre si pas 0
    // paramètres en r0 = workbuffer + lgr commande

    // not a typo :)
    lda work_buffer
    sta zr0l
    lda #>work_buffer
    sta zr0h

    clc
    jmp $080d

test_load:
    ldy #0
    getbyte_r(0)
    ldx zr0l
    ldy zr0h
    jsr SETNAM

    jsr bios.do_set_device
    lda bios.device

    // 2,X,0
    lda #2
    ldx bios.device
    ldy #0  // 0 = fixed address, 1 = source address
    jsr SETLFS

    // load file to $0801 or adresse_dest

    ldx #1
    ldy #8
    lda avec_adresse_dest
    beq suite_load
    ldx adresse_dest
    ldy adresse_dest+1

suite_load:
    lda #0
    jmp LOAD

text_path:
    pstring("PATH")
avec_adresse_dest:
    .byte 0
adresse_dest:
    .word 0
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

    mov r0, r2
    jsr do_pprintnl

    lda lgr_elem
    add r2, a
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
// list_del : supprime une entrée dans une liste
// entrée : r0 = ptr objet liste, X = numéro entrée à supprimer
// retour : r0 = ptr objet liste à jour
//---------------------------------------------------------------

do_list_del:
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

    mov r5, r2
    mov r1, r2
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

    mov r0, r2
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
    mov r0, #do_var_get.msg_pas_var
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
    inc r0

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
    push r4 // sauvegarde r4

    jsr setup_list
    sta num_elem

    push r0

    // copie r0 vers r3 = ptr new
    // ptr last = r1
    mov r0, r1
    mov r1, r3
    mov r4, r1
    jsr do_str_cpy
    tay
    pop r0
    tya
    jsr addelem_list
    lda num_elem

    pop r4
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
    stx input_buffer

get_next:
    jsr GETIN
    beq get_next

    cmp #$0d
    jeq fin_input

    //-- INS -----
    cmp #INS
    bne pas_ins

    ldx write_x
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

    mov r0, #input_buffer
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
    swi list_get, shell.history_list
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
// str_expand : expanse une pstring
// entrée : R0, sortie : R1
//
// séquences expansées :
//
// %V<variable>% = valeur variable
// %P<reg> = pstring à l'adresse du registre <reg>
// %R<reg> = valeur hexa du registre <reg>
// %% = %
// %C<nibble> = couleur <nibble> ou caractère de contrôle :
//              R = reverse, N = normal
// %H<hex> = caractère code <hex>
//---------------------------------------------------------------

do_str_expand:
{
    ldy #0
    tya
    sta (zr1),y
    lda (zr0),y
    bne pas_vide
    clc
    rts

pas_vide:
    push r1
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
    pop r1
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
    jeq process_normal

    cmp #'R'
    bne pas_registre

    // registre : récupère la valeur d'un registre
    jsr consomme_car
    dec lgr_input
    getbyte_r(0)
    and #$0f
    asl
    tay

    push r0
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

    pop r0
    jmp process_suite

pas_registre:
    cmp #'V'
    jne pas_variable
    jsr consomme_car

    // V = variable : récupère la valeur d'une variable

    push r1
    mov r1, #work_name
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

    push r0
    swi var_get, work_name
    mov r2, r1
    pop r0
    pop r1

do_copy_var:
    ldy #0
    getbyte_r(2)
    sta lgr_copie
    cmp #0
    beq pas_copie_var
copie_var:
    getbyte_r(2)
    setbyte_r(1)
    inc lgr_output
    dec lgr_copie
    bne copie_var

pas_copie_var:
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

    // C = couleur, insère le caractère de changement de couleur
    // fonction du nibble hexa qui suit ou N / R

pas_pstring:
    cmp #'C'
    bne pas_couleur
    jsr consomme_car

    mov a, (r0++)
    sta ztmp

    ldy #0
    ldx #0
lookup_code:
    lda corresp_code, x
    beq code_hs
    cmp ztmp
    beq code_trouve
    inx
    bne lookup_code
code_hs:
    lda #'?'
    jmp process_normal
code_trouve:
    lda code_couleur,x
    jmp process_normal

    // H = caractère valeur <hex> qui suit (2 octets)
pas_couleur:
    cmp #'H'
    bne pas_hex

    jsr consomme_car
    jsr consomme_car
    jsr do_hex2int.conv_hex_byte
    ldy #0
    jmp process_normal

pas_hex:
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

corresp_code:
    .text "0123456789ABCDEFRNH"
    .byte 0
code_couleur:
    .byte 90,5,28,159,156,30,31,158
    .byte 150,149,129,151,152,153,154,155
    .byte 18,146,147

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
    push r1
    tya
    pha
    mov r1, #work_pprint
    jsr do_str_expand
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
    pop r1
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
// si C=1, n'affiche pas le préfixe
//---------------------------------------------------------------

do_pprinthex:
{
    stx ztmp
    bcs no_prefix
    lda #'$'
    jsr CHROUT
no_prefix:
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

//---------------------------------------------------------------
// var_get : lecture variable
// r0 : nom variable -> r1 : contenu et C = 1
// pas trouvé => C = 0 et contenu = NIL
//---------------------------------------------------------------

do_var_get:
{
    jsr lookup_var
    bcc pas_var
    clc
    rts

pas_var:
    mov r1, #msg_pas_var
    sec
    rts

msg_pas_var:
    pstring("NIL")
}

//---------------------------------------------------------------
// var_set : crée une variable, affecte une valeur
// r0 : nom variable, r1 : nouveau contenu
//---------------------------------------------------------------

do_var_set:
{
    // sauvegarde r0 nom dans rsrc et r1 valeur dans rdest
    mov rsrc, r0
    mov rdest, r1
    // var existe ?
    jsr lookup_var
    jcs pas_creation

    // création : 
    // copie nom variable
    mov r1, #ptr_last_variable
    mov r1, (r1)
    jsr do_str_cpy
    add ptr_last_variable, a
    mov r3, #ptr_last_variable

    // copie valeur variable
    mov r0, rdest
    //pop r1
    //mov r0, r1
    mov r1, #ptr_last_value
    mov r1, (r1)
    mov r4, r1
    jsr do_str_cpy
    add ptr_last_value, a

    // ecriture adresse valeur à la suite du nom
    mov (r3), r4

    // ajoute longueur adresse valeur à ptr_last_variable
    lda #2
    add ptr_last_variable, a

    // incrémente le nb de variables
    inc nb_variables
    clc
    rts

    // si update, supprime la variable et rappelle var_set
pas_creation:
    pha
    mov r1, #work_buffer
    mov r0, rdest
    swi str_cpy
    pla
    tax
    jsr do_var_del
    mov r0, rsrc
    mov r1, #work_buffer
    jmp do_var_set
}

.print "ptr_last_variable=$"+toHexString(ptr_last_variable)
.print "ptr_last_value=$"+toHexString(ptr_last_value)
.print "nb_variables=$"+toHexString(nb_variables)

.print "var_names=$"+toHexString(var_names)
.print "var_values=$"+toHexString(var_values)

//---------------------------------------------------------------
// do_var_del : supprime une variable
// X = numéro variable à supprimer
//---------------------------------------------------------------

do_var_del:
{
    stx to_supp

    // source
    mov r0, #var_names
    mov r2, #var_values
    // destination
    mov r1, #var_names
    mov r3, #var_values

    // recopie des noms, sauf si numéro à supprimer
    ldy #0
    ldx #0

copies:
    cpx to_supp
    bne copies_ok

    // à supprimer = passe nom et adresse valeur
    // si longueur = 0 = fin = non trouvé
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

    // 
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
    mov r4, r3

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
    mov r1, #internal_commands
    lda nb_cmd
    sta nb_var_work
    jmp lookup_gen
}

lookup_var:
{
    mov r1, #var_names
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

    jsr do_str_cmp
    bcs var_existe

    clc
    lda lgr_varname
    adc #3
    add r1, a
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
    add r1, a
    mov r1, (r1)

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
// str_cmp : compare 2 pstrings, r0 vs r1, C=1 si OK
//---------------------------------------------------------------

do_str_cmp:
{
    // si pas même longueur = KO
    swi str_len
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
// str_cpy : copie pstring en r0 vers destination en r1
// en sortie A = longueur + 1 = longueur copiée
//---------------------------------------------------------------

do_str_cpy:
{
    swi str_len
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
// str_ins : insère dans r0 la chaine r1 en position X
//---------------------------------------------------------------

do_str_ins:
{
    // 1. décale la fin de chaine pour faire de la place
    // 2. copie r1 en position X
    // 3. mise à jour lgr = +lgr r1

    stx pos_copie
    swi str_len
    sta pos_lecture
    push r0
    mov r0, r1
    swi str_len
    sta lgr_r1
    pop r0
    lda pos_lecture
    clc
    adc lgr_r1
    sta pos_ecriture
    lda pos_lecture
    sec
    sbc pos_copie
    tax
    lda #1
    sta pos_lecture_copie

decale:
    ldy pos_lecture
    mov a, (r0)
    ldy pos_ecriture
    mov (r0), a
    dec pos_lecture
    dec pos_ecriture
    dex
    bpl decale

    ldx lgr_r1
copie:
    ldy pos_lecture_copie
    mov a, (r1)
    ldy pos_copie
    mov (r0), a
    inc pos_lecture_copie
    inc pos_copie
    dex
    bne copie

    swi str_len
    clc
    adc lgr_r1
    mov (r0), a

    clc
    rts

pos_lecture:
    .byte 0
pos_ecriture:
    .byte 0
pos_copie:
    .byte 0
pos_lecture_copie:
    .byte 0
lgr_r1:
    .byte 0
}

//---------------------------------------------------------------
// str_del : supprime Y caractères à partir de la position X
// entrée : R0 = pstring
// todo : contrôle erreurs / dépassements
//---------------------------------------------------------------

do_str_del:
{
    // 0 123456789 : 3, 4 -> 0 123 4567 89 -> 0 12389
    // début Y+1
    sty nb_supp
    inx
    stx pos_ecriture
    txa
    clc
    adc nb_supp
    sta pos_lecture
    
    swi str_len
    sec
    sbc pos_ecriture
    sbc nb_supp
    tax

copie:
    ldy pos_lecture
    mov a, (r0)
    ldy pos_ecriture
    mov (r0), a
    inc pos_ecriture
    inc pos_lecture
    dex
    bpl copie

    // maj longueur
    ldy #0
    mov a, (r0)
    sec
    sbc nb_supp
    mov (r0), a    
    clc
    rts

nb_supp:
    .byte 0
pos_lecture:
    .byte 0
pos_ecriture:
    .byte 0
}

//---------------------------------------------------------------
// print_path : affiche les éléments d'un objet ppath, pour
// debug
// r0 = objet ppath
// rappel ppath : type, device, partition, path, nom
//---------------------------------------------------------------

do_print_path:
{
    push r0
    // type et dev
    getbyte_r(0)
    sta zr4h
    getbyte_r(0)
    sta zr4l
    // ignore partition
    getbyte_r(0)
    // path
    mov r5, r0
    getbyte_r(0)
    add r0, a
    // name
    mov r6, r0

    swi pprintnl, msg_path
    pop r0
    rts
msg_path:
    pstring("TYPE/DEVICE (%R4) PATH (%P5) NAME (%P6)")
}

//---------------------------------------------------------------
// str_chr : recherche X dans pstring R0, C=1 si trouvé et
// Y = position
//---------------------------------------------------------------

do_str_chr:
{
    stx ztmp
    ldy #0
    lda (zr0),y
    beq pas_trouve
    sta longueur
    iny
    lda ztmp
recherche:
    cmp (zr0),y
    beq trouve
    iny
    dec longueur
    bne recherche
pas_trouve:
    clc
    rts
trouve:
    sec
    rts
longueur:
    .byte 0
}

//---------------------------------------------------------------
// str_rchr : recherche A dans pstring R0, C=1 si trouvé et
// Y = position (recherche inverse)
//---------------------------------------------------------------

do_str_rchr:
{
    sta ztmp
    ldy #0
    lda (zr0),y
    beq pas_trouve
    tay
    lda ztmp
recherche:
    cmp (zr0),y
    beq trouve
    dey
    bne recherche
pas_trouve:
    clc
    rts
trouve:
    sec
    rts
}

//---------------------------------------------------------------
// str_alt_ncpy : alternative str_ncpy using zsrc / zdest
//---------------------------------------------------------------

do_str_alt_ncpy:
{
    ldy #0
    stx lgr_copie
    push rdest
    lda #0
    setbyte_r(reg_zdest)

copie_nom:
    getbyte_r(reg_zsrc)
    setbyte_r(reg_zdest)
    dex
    bne copie_nom

    pop rdest
    lda lgr_copie
    setbyte_r(reg_zdest)
    dec rdest
    clc
    rts

lgr_copie:
    .byte 0
}

//---------------------------------------------------------------
// str_ncpy : copie X caractères à partir de r0 vers une
// nouvelle chaine pstring en r1
//---------------------------------------------------------------

do_str_ncpy:
{
    ldy #0
    stx lgr_copie
    push r1
    lda #0
    setbyte_r(zr1)

copie_nom:
    getbyte_r(zr0)
    setbyte_r(zr1)
    dex
    bne copie_nom

    pop r1
    lda lgr_copie
    setbyte_r(zr1)
    dec r1
    clc
    rts

lgr_copie:
    .byte 0
}

//---------------------------------------------------------------
// prep_path : prépare un objet path
//
// entrée : r0 = chaine à traiter, r1 = destination ppath
//
// format en entrée :
// [device[,partition]]:][path/][file]
//---------------------------------------------------------------

do_prep_path:
{
    // sauvegarde r0, raz ppath
    push r0
    ldy #4
    lda #0
raz_path:
    sta (zr1),y
    dey
    bpl raz_path

    // lecture longueur en entrée, si 0 = exit
    tay
    lda (zr0),y
    sta lgr_entree
    bne process_entree

fin_prep_path:
    pop r0
    clc
    rts

    // traitement entrée, si 1er caractère est un digit
    // alors extract_device_partition

process_entree:
    jsr extract_device_partition
    bcs syntax_error
    sty suite_lecture
    jsr convert_device_partition
    jsr extract_path_name
    jsr update_path_type
    jmp fin_prep_path

suite_lecture:
    .byte 0

syntax_error:
    pop r0
    swi error, msg_error.invalid_parameters
    sec
    rts

    // extraction device/partition, forme
    // [device[,partition]]:]
    // max 2 digits et 3 digits
    // en sortie str_device / str_partition à jour
    // et Y=suite lecture
    // C=0 si OK, C=1 si erreur

extract_device_partition:
    // raz device et partition
    ldy #0
    sty str_device
    sty str_partition

    // recherche présence ":"
    ldx #':'
    jsr do_str_chr
    bcs presence_device_partition
    ldy #1
    clc
    rts

presence_device_partition:
    ldy #1
    ldx #1
copie_device:
    lda (zr0),y
    iny
    cmp #':'
    beq fin_device_partition
    cmp #','
    beq test_partition
    sta str_device,x
    inx
    inc str_device
    cpx #4
    bne copie_device
    beq fin_erreur_partition

test_partition:
    ldx #1
copie_partition:
    lda (zr0),y
    iny
    cmp #':'
    beq fin_device_partition
    sta str_partition,x
    inx
    inc str_partition
    cpx #5
    bne copie_partition

fin_erreur_partition:
    sec
    rts
    
fin_device_partition:
    clc
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
    push r0
    mov r2, r1
    mov r0, #str_device
    jsr bios.do_str2int
    pha
    mov r0, #str_partition
    jsr bios.do_str2int
    pha
    mov r1, r2
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
    pop r0
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

    lda #'/'
    jsr do_str_rchr
    bcs do_cut

    // pas de découpage, nom seul, recopie dans partie nom
    
    mov rsrc, r0
    lda suite_lecture
    add rsrc, a
    mov r5, r1
    lda #4
    add r5, a
    mov rdest, r5

    sec
    lda lgr_entree
    sbc suite_lecture
    tax
    inx
    jsr do_str_alt_ncpy
    jmp fin_extract_path_name

    // découpage path / nom, Y = position de départ
    // path = début suite_lecture, lgr = Y
do_cut:

    tya
    tax
    stx lgr_copie

    // copie partie path
    mov rsrc, r0
    lda suite_lecture
    add rsrc, a
    mov r5, r1
    lda #3
    add r5, a
    mov rdest, r5

    sec
    lda lgr_copie
    sbc suite_lecture
    tax
    inx
    jsr do_str_alt_ncpy

    // destination 
    ldy #0
    mov r5, r1
    lda #3
    add r5, a
    ldy #0
    lda (zr5),y
    add r5, a
    inc r5
    mov rdest, r5
    // source = OK
    // longueur = total - lgr_copie
    ldy #0
    lda (zr0),y
    sec
    sbc lgr_copie
    tax
    jsr do_str_alt_ncpy
    
fin_extract_path_name:
    clc
    rts

lgr_copie:
    .byte 0

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
// str_pat : pattern matching, C=1 si OK, C=0 sinon
// r0 : chaine à tester
// r1 : pattern
//---------------------------------------------------------------

do_str_pat:
{
    .label zstring = zr0
    .label zwild = zr1

    ldy #0
    lax (zstring),y
    inx
    stx lgr_string
    lax (zwild),y
    inx
    stx lgr_wild
    iny
    sty pos_wild
    sty pos_string
    sty pos_cp
    sty pos_mp

while1:
    lda pos_string
    cmp lgr_string
    beq end_while1

    ldy pos_wild
    lda (zwild),y
    cmp #'*'
    beq end_while1

    ldy pos_wild
    lda (zwild),y
    ldy pos_string
    cmp (zstring),y
    beq suite_while1
    cmp #'?'
    beq suite_while1
    clc
    rts

suite_while1:
    inc pos_wild
    inc pos_string
    jmp while1

end_while1:

while2:
    lda pos_string
    cmp lgr_string
    beq end_while2

    ldy pos_wild
    //cmp lgr_wild
    //beq pas_etoile
    lda (zwild),y
    cmp #'*'
    bne pas_etoile

    inc pos_wild
    lda pos_wild
    cmp lgr_wild
    bne suite
    sec
    rts
suite:
    lda pos_wild
    sta pos_mp
    ldy pos_string
    iny
    sty pos_cp
    jmp while2

pas_etoile:
    ldy pos_wild
    //cpy lgr_wild
    //beq end_while2

    lda (zwild),y
    cmp #'?'
    beq ok_comp
    ldy pos_string
    cpy lgr_string
    beq end_while2
    cmp (zstring),y
    beq ok_comp
    
not_ok_comp:
    lda pos_mp
    sta pos_wild
    inc pos_cp
    lda pos_cp
    sta pos_string
    jmp while2

ok_comp:
    inc pos_wild
    inc pos_string
    lda pos_wild
    cmp lgr_wild
    beq ok_wild
    bcs ko_inc
ok_wild:
    lda pos_string
    cmp lgr_string
    beq ok_string
    bcs ko_inc
ok_string:
    jmp while2
ko_inc:
    sec
    rts
end_while2:

while3:
    ldy pos_wild
    cpy lgr_wild
    beq fini_wild
    lda (zwild),y
    cmp #'*'
    bne end_while3
    inc pos_wild
    jmp while3

end_while3:
    lda pos_wild
    cmp lgr_wild
    beq fini_wild
    clc
    rts
fini_wild:
    sec
    rts

debug_values:
    lda #'S'
    jsr CHROUT
    lda pos_string
    ora #'0'
    jsr CHROUT
    lda #'W'
    jsr CHROUT
    lda pos_wild
    ora #'0'
    jsr CHROUT
    lda #'C'
    jsr CHROUT
    lda pos_cp
    ora #'0'
    jsr CHROUT
    lda #'M'
    jsr CHROUT
    lda pos_mp
    ora #'0'
    jsr CHROUT

    lda #13
    jmp CHROUT

lgr_string:
    .byte 0
lgr_wild:
    .byte 0
pos_wild:
    .byte 0
pos_string:
    .byte 0
pos_cp:
    .byte 0
pos_mp:
    .byte 0
}

//===============================================================
// Helper functions
//===============================================================

//---------------------------------------------------------------
// set_bit : positionne le bit Y à 1 dans A
//---------------------------------------------------------------

set_bit:
{
    ora bit_list,y
    rts
bit_list:
    .byte 1,2,4,8,16,32,64,128
}

//---------------------------------------------------------------
// is_digit : C=1 si A est un digit, C=0 sinon
//---------------------------------------------------------------

is_digit:
{
    pha
    clc
    adc #$ff-'9'
    adc #'9'-'0'+1
    pla
    rts
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
    stc affichage_lecteurs

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
    jeq boucle_drive

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
    ldx #%00000011
    swi pprint_int

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
// file_close : fermeture fichier et reset I/O
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
//
// r0 = buffer réception
// sortie : work_buffer, A = longueur
// c=0 : ok, c=1 : fin de fichier
// lecture de 255 octets max
//----------------------------------------------------

do_file_readline:
{
    ldy #0
    tya
    mov (r0), a
    iny

boucle_lecture:
    jsr READST
    bne fin_lecture
    jsr CHRIN
    cmp #13
    beq fin_ligne
    cmp #10
    beq fin_ligne
    sta (zr0),y
    iny
    bne boucle_lecture
    
    // todo ici  : erreur dépassement buffer
erreur:
    swi error, msg_error.buffer_overflow
    sec
    rts

fin_ligne:
    dey
    tya
    ldy #0
    sta (zr0),y
    clc
    rts

fin_lecture:
    dey
    tya
    ldy #0
    sta (zr0),y
    sec
    rts
}

//----------------------------------------------------
// str_split : découpe une pstring en fonction d'un
// séparateur
// entrée = r0 pstring, X = séparateur
// en sortie = r0 pstring découpée, A = nb d'éléments
// C=0 pas de découpe, C=1 découpe effectuée
//----------------------------------------------------

do_str_split:
{
    stx separateur
    swi str_len
    sta lgr_total
    sty decoupe
    sty nb_items
    iny
    sty lgr_en_cours
    dey
    mov r1, r0
    inc r0

parcours:
    lda lgr_total
    beq fini
    mov a, (r0++)
    cmp separateur
    bne pas_process_sep
    lda #1
    sta decoupe
    jsr process_sep

pas_process_sep:
    inc lgr_en_cours
    dec lgr_total
    bne parcours

    // traitement dernier
    jsr process_sep

fini:
    ldc decoupe
    lda nb_items
    rts

process_sep:
    ldx lgr_en_cours
    dex
    txa
    mov (r1), a
    mov r1, r0
    dec r1
    ldx #0
    stx lgr_en_cours
    inc nb_items
    rts

separateur:
    .byte 0
lgr_total:
    .byte 0
lgr_en_cours:
    .byte 0
decoupe:
    .byte 0
nb_items:
    .byte 0
}

//----------------------------------------------------
// str_empty : teste si la chaine en r0 est vide
// retour C=0 si vide, C=1 si non vide
// caractères "vides" = espace / tab / espace shifté
//----------------------------------------------------

do_str_empty:
{
    ldy #0
    mov a, (r0)
    sta lgr_chaine
    beq est_vide

test_vide:
    iny
    mov a, (r0)
    cmp #32
    beq suite_test_vide
    cmp #9
    beq suite_test_vide
    cmp #160
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
// buffer_write : ecriture bufferisée
// entrée : R0 = buffer d'écriture, pstring
// X = id fichier
//----------------------------------------------------

do_buffer_write:
{
    jsr CHKOUT
    swi str_len
    sta nb_lu
    iny
    sty pos_lecture
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
// buffer_read : lecture bufferisée
// entrée : R0 = buffer de lecture (pstring)
// longueur buffer = pstring, longueur = max buffer
// C=0 lecture normale, C=1 arrêt si 0d ou 0a (ligne)
// X = id fichier
// sortie : buffer à jour et longueur à jour
// C=0 si pas fini, C=1 si EOF
//----------------------------------------------------

do_buffer_read:
{
    stc lecture_ligne
    jsr CHKIN

    swi str_len
    sta lgr_max
    sty nb_lu
lecture:
    jsr READST
    bne fin_lecture
    jsr CHRIN
    ldy lecture_ligne
    beq pas_test
    cmp #13
    beq fin_buffer
    cmp #10
    beq fin_buffer
pas_test:
    ldy nb_lu
    iny
    sta (zr0),y
    inc nb_lu
    cpy lgr_max:#255
    beq fin_buffer
    bne lecture
fin_buffer:
    lda nb_lu
    ldy #0
    sta (zr0),y
    jsr READST
    bne fin_lecture
    jsr CLRCHN
    clc
    rts

fin_lecture:
    and #$40
    beq pas_erreur
    // erreur lecture à gérer
    //swi error, msg_error.read_error
    // fin de fichier
pas_erreur:
    lda nb_lu
    ldy #0
    sta (zr0),y
    jsr CLRCHN
    sec
    rts

lecture_ligne:
    .byte 0
nb_lu:
    .byte 0
}

//----------------------------------------------------
// file_open : ouverture fichier en lecture
// r0 : pstring nom, X = canal
// retour C=0 OK, C=1 KO
// le fichier est ouvert en X,<device>,X
//----------------------------------------------------

do_file_open:
{
    stx canal
    // jsr bios.do_set_device

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
    swi get_device_status
    bcs error
    clc
    rts

error:
    ldx bios.device
    jsr do_file_close
    sec
    rts

canal:
    .byte 0
}

//----------------------------------------------------
// build_path : construction path cible
// entrée : r0 = adresse pstring résultat
// r1 = ppath source
// si C=0 ajout :, si C=1 pas d'ajout séparateur ":"
// sortie = r0 à jour = path:nom
//----------------------------------------------------

do_build_path:
{
    stc pas_ajout

    mov rsrc, r1
    mov rdest, r0
    
    // raz dest
    ldy #0
    tya
    mov (r0), a

    mov a, (r1)
    sta options_path
    and #PPATH.WITH_PATH
    beq pas_path

    // ajout PATH
    add r1, #3
    swi str_cat

pas_path:
    lda options_path
    and #PPATH.WITH_NAME
    beq pas_name

    // ajout NAME, avec séparateur si demandé
    lda pas_ajout
    bne pas_ajout_sep

    mov r1, #msg_sep
    swi str_cat

pas_ajout_sep:
    mov r1, rsrc
    add r1, #3
    mov a, (r1)
    add r1, a
    inc r1
    swi str_cat

pas_name:
    clc
    rts

options_path:
    .byte 0
pas_ajout:
    .byte 0
msg_sep:
    pstring(":")
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
    jsr TALK
    lda #$6F      // secondary address 15 (error channel)
    jsr TKSA

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

    mov r0, #code_status
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
    swi error, msg_error.device_not_present
    rts

silencieux:
    .byte 0
.print "code_status=$"+toHexString(code_status)
}

//---------------------------------------------------------------
// print_int : affichage entier
// entier dans r0
// X = format, %PL123456
// bit 7 = padding avec espace (avec 0 sinon)
// bit 6 = suppression espaces en tête
//---------------------------------------------------------------

do_print_int:
{
    stx format
    txa
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
    mov r1, #int_conv
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

//---------------------------------------------------------------
// key_wait : wait for keypress
//---------------------------------------------------------------

do_key_wait:
{
wait_key:
    jsr SCNKEY
    jsr GETIN
    cmp #$20
    beq wait_key
    cmp #$03
    beq key_ok
    cmp #$51
    beq key_ok
    cmp #$0d
    beq key_ok
    cmp #$11
    beq key_ok
    bne wait_key
key_ok:
    clc
    rts
}

//----------------------------------------------------
// parameters_loop : execute tant qu'il y a des 
// paramètres dans la liste
//
// entrée r0 adresse sous-routine
// r1 = adresse plist des paramètres
// dans la boucle r0 = paramètre transmis
//----------------------------------------------------

do_parameters_loop:
{
    ldy #0
    mov a, (r1)
    sta nb_params
    mov adr_params, r1
    mov jump, r0
    ldx #1
    stx pos_param

do_params:
    mov r0, adr_params
    swi list_get
    swi is_filter
    bcc no_filter

    // si filtre : traite entrées de répertoire
    swi directory_open
    ldx #bios.directory.TYPE_FILES
    swi directory_set_filter
    
boucle_entries:
    swi directory_get_entry
    bcs fin_boucle_entries
    beq fin_boucle_entries
    bmi boucle_entries
    jsr CLRCHN
    mov r0, #bios.directory.entry.filename
    jsr do_jump
    jmp boucle_entries

no_filter:
    jsr do_jump
    bcs erreur_exec
    jmp next_param

fin_boucle_entries:
    swi directory_close
next_param:
    inc pos_param
    ldx pos_param
    cpx nb_params
    bne do_params
    clc
    rts

do_jump:
    jsr jump:$fce2
    bcs erreur_exec
    clc

erreur_exec:
    rts

adr_params:
    .word 0
nb_params:
    .byte 0
pos_param:
    .byte 0
}

//===============================================================
// picture routines :
//
// show  : show picture
//===============================================================

//---------------------------------------------------------------
// picture_show : show picture
//
// R0 = picture data address if needed
// C=1 : wait for keypress and returns to text mode
// X = picture type
//
//  $00 : return to text mode
//  $01 : Koala picture
//---------------------------------------------------------------

do_picture_show:
{
    stc has_keypress
    bne pas_txt
    jsr go_txt
    lda #0
    sta $d021
    jmp fin_show


pas_txt:
    cpx #1
    bne pas_koala

    // screen to 6800, color to d800
    // screen offset is 2800

    ldx #0
copy_color:
    lda $6328,x
    sta $d800,x
    lda $6428,x
    sta $d900,x
    lda $6528,x
    sta $da00,x
    lda $6628,x
    sta $db00,x
    lda $5f40,x
    sta $6800,x
    lda $6040,x
    sta $6900,x
    lda $6140,x
    sta $6a00,x
    lda $6240,x
    sta $6b00,x
    dex
    bne copy_color

    // background color

    lda $6710
    sta $d021

    jsr go_gfx
    jmp fin_show

pas_koala:

fin_show:
    lda has_keypress
    beq no_keypress
    swi key_wait
no_keypress:
    clc
    rts

go_gfx:
    lda #$38
    sta $d011
    lda #$18
    sta $d016
    lda #$02
    sta $dd00
    lda #$A0
    sta $d018
    rts

go_txt:
    lda #$9b
    sta $d011
    lda #$c8
    sta $d016
    lda #$03
    sta $dd00
    lda #$17
    sta $d018
    rts

has_keypress:
    .byte 0
}

//===============================================================
// scripts routines :
//
// read
// execute
//===============================================================

//---------------------------------------------------------------
// script_execute : execute script
//
// R0 = script start
//---------------------------------------------------------------

do_script_execute:
{
next_command:
    swi str_len
    beq end_execute
    sta lgr_commande
    mov r1, #input_buffer
    swi str_cpy
    push r0
    jsr shell.command_process
    pop r0
    lda lgr_commande
    add r0, a
    jmp next_command
end_execute:
    clc
    rts
lgr_commande:
    .byte 0
}

//---------------------------------------------------------------
// script_read : read script into memory
//
// R0 = script file name
// R1 = write destination (usually script_data)
//---------------------------------------------------------------

do_script_read:
{
    ldx #8
    clc
    swi file_open
    bcc script_found
    sec
    rts

script_found:
    ldx #8
    jsr CHKIN

next_line:
    swi file_readline, input_buffer
    bcs fini

    mov r0, #input_buffer

    // si ligne vide, empty ou commence par # = ignore
    swi str_empty
    bcc next_line
    ldy #1
    mov a, (r0)
    cmp #'#'
    beq next_line
    swi pprintnl, input_buffer

    jsr CLRCHN
    jsr shell.command_process
    ldx #8
    jsr CHKIN
    jmp next_line

fini:
    ldx #8
    swi file_close
    clc
    rts
}

//===============================================================
// directory routines :
//
// open
// set_filter
// get_entry
// get_entries
// close
// 
// Uses channel #7 : 7,<device>,0
//===============================================================

//---------------------------------------------------------------
// directory_open : lecture répertoire
//---------------------------------------------------------------

do_directory_open:
{
    push r0
    swi str_cpy, directory.default_filter, directory.filter
    ldx #7
    clc
    swi file_open, directory.dirname
    bcc open_ok
    swi file_close
    swi error, msg_error.read_error
    pop r0
    sec
    rts

open_ok:
    lda #2
    sta directory.diskname
    lda #255
    sta directory.filter_types
    pop r0
    clc
    rts
}

//---------------------------------------------------------------
// directory_set_filter : change le filtre
// en entrée r0 = nouveau filtre nom et X = filtre types
//---------------------------------------------------------------

do_directory_set_filter:
{
    stx directory.filter_types
    mov r1, #directory.filter
    swi str_cpy
    clc
    rts
}

//---------------------------------------------------------------
// directory_get_entry : lecture entrée répertoire, retour r0
//
// C=1 : fin
// A=0 : blocks free
//---------------------------------------------------------------

do_directory_get_entry:
{
    ldx #7
    jsr CHKIN

    jsr READST
    beq pas_EOF
    sec
    rts

pas_EOF:    
    // lecture 32 octets = 1 entrée de répertoire
    ldy #0
lecture_buffer:
    jsr CHRIN
    sta buffer_entry,y
    iny
    cpy #32
    bne lecture_buffer
    jsr CLRCHN
    // update size
    mov directory.entry.size, buffer_entry+2

    // update nom et type par automate sur status
    // des guillemets :
    // 0 = pas encore rencontré = rien
    // 1 = ouvert = copie nom
    // 2 = fermé = copie type

    ldx #0
    stx status_guillemets
    ldy #4

update_nom:
    lda buffer_entry,y
    cmp #34
    beq traite_guillemets

    // si guill = 0 : continue
    lda status_guillemets
    beq suite_update

    // si guill = 1 : copie dans nom
    cmp #1
    bne apres_nom
    lda buffer_entry,y
    sta directory.entry.filename+1,x
    inx
    bne suite_update

    // si guill = 2 : copie dans type
    // sauf si espace ou 0
apres_nom:
    lda buffer_entry,y
    beq suite_update
    cmp #32
    beq suite_update
    sta directory.entry.type+1,x
    inx
    bne suite_update

    // guillemets : incrémente
traite_guillemets:
    inc status_guillemets
    lda status_guillemets
    cmp #2
    bne suite_update

    // si 2 = fin nom, màj longueur
    // et redémarre à 0 pour type
    stx directory.entry.filename
    ldx #0

    // suite update_nom
suite_update:
    iny
    cpy #32
    bne update_nom
    stx directory.entry.type

    lda status_guillemets
    beq fin_entry

    // détermine le type d'entrée

    ldx #0
    stx directory.entry.filetype
det_type:
    lda directory.types,x
    beq fin_types
    cmp directory.entry.type+1
    beq type_trouve
    inx
    bne det_type
type_trouve:
    lda directory.types_code,x
    sta directory.entry.filetype
fin_types:

    // traite le cas du nom de disque
    lda directory.diskname
    beq diskname_passe
    dec directory.diskname

diskname_passe:
    // filtre types
    lda directory.entry.filetype
    and directory.filter_types
    beq filtre_ko

    // test filtre, retour $80 si KO
    swi str_pat, directory.entry.filename, directory.filter
    bcs fin_entry

filtre_ko:
    lda #$80
    clc
    rts

fin_entry:
    lda status_guillemets
    clc
    rts

status_guillemets:
    .byte 0
buffer_entry:
    .fill 32,0
}

//---------------------------------------------------------------
// directory_close : fermeture répertoire
//---------------------------------------------------------------

do_directory_close:
{
    ldx #7
    swi file_close
    clc
    rts
}

//---------------------------------------------------------------
// directory_get_entries : lecture entrées vers liste
// entrée X = filtre types, R0 = filtre nom
// A = nb d'entrées
//---------------------------------------------------------------

do_directory_get_entries:
{
    txa
    pha
    push r0
    swi directory_open
    pop r0
    pla
    tax

    swi directory_set_filter
    mov r1, #directory.entries
    // raz liste destination
    ldy #0
    sty nb_items
    tya
    mov (r1), a
    push r1

dir_suite:
    swi directory_get_entry
    bcs dir_fin
    beq dir_fin
    bmi dir_suite

entree_ok:
    // filtre OK, 
    //swi pprintnl, bios.directory.entry.filename
    mov r0, #bios.directory.entry.filename
    pop r1

    // ajoute chaine en r0, copie lgr+1
    swi str_len
    tax
    inx
ajoute_entree:
    mov a, (r0++)
    mov (r1++), a
    dex
    bne ajoute_entree
    push r1
    inc nb_items
    jmp dir_suite

dir_fin:
    pop r1
    lda #0
    mov (r1), a

    swi directory_close
    clc
    lda nb_items
    rts

nb_items:
    .byte 0
}

//===============================================================
// DATAS BIOS namespace
//===============================================================

// directory reading

directory:
{

dirname:
    pstring("$")

    // indicateur entrée = diskname
diskname:
    .byte 0

    // Types de fichier

    .label TYPE_PRG=1
    .label TYPE_SEQ=2
    .label TYPE_USR=4
    .label TYPE_REL=8
    .label TYPE_DIR=16
    .label TYPE_ERR=128
    .label TYPE_FILES=1+2+4

types:
    .text "PSURD*"
    .byte 0
types_code:
    .byte 1,2,4,8,16,128

    // Valeurs pour filtre

filter_types:
    .byte 255
filter:
    pstring("0123456789ABCDEF")
default_filter:
    pstring("*")

entry:
    {
    // Filesize in blocks
    size:
        .word 0
    
    // Filename
    filename:
        pstring("0123456789ABCDEF")
    
    // Filetype string
    type:
        pstring("*DIR<")
    
    // Filetype binary value
    filetype:
        .byte 0
    }
.label entries = work_entries;

}
.print "directory.entry=$"+toHexString(directory.entry)
.print "directory.entry.filetype=$"+toHexString(directory.entry.filetype)
.print "directory.entry.filename=$"+toHexString(directory.entry.filename)
.print "directory.filter=$"+toHexString(directory.filter)
.print "directory.filter_types=$"+toHexString(directory.filter_types)

// other

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
    mov r0, #word_param
    lda #bios_func
    jsr bios.bios_exec
}

//===============================================================
// call_bios2 : call bios function with parameters in r0, r1
//===============================================================

.macro call_bios2(bios_func, word_param, word_param2)
{
    mov r0, #word_param
    mov r1, #word_param2
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
