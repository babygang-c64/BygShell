
//===============================================================
// BYG SHELL : Command line Shell
//
// 2024 Babygang
//===============================================================

#import "macros.asm"
#import "kernal.asm"

//===============================================================
// Shell and BIOS workspace data
//===============================================================

* = $7000 "Workspace data"

//---------------------------------------------------------------
// workspace for scripts
//---------------------------------------------------------------

.label script_data = *

    .fill $200,0

script_labels:
    pstring("START")
    .word script_data
next_labels:

//---------------------------------------------------------------
// workspace with names and values for internal variables
//---------------------------------------------------------------

    .align $100

var_names:
    pstring("PROMPT")
    .word prompt_value
    pstring("PATH")
    .word path_value
    pstring("DEVICE")
    .word device_value
    pstring("CONFIG")
    .word config_value
    pstring("VERSION")
    .word version_value

variables_end:
    .byte 0

    .align $100
* = * "variables values space"
var_values:
prompt_value:
    pstring("%VDEVICE%>")
path_value:
    pstring("//PATH/")
device_value:
    pstring("10")
config_value:
    pstring("9://CONFIG/")
version_value:
    pstring("0.2")

values_end:

//---------------------------------------------------------------
// input and work buffers
//
// input_buffer is the user input buffer space
// work_buffer and work_buffer2 are general purpose buffers
// work_io is for file I/O
// work_entries, work_path, work_path2, work_filename and
// work_filename2 are for directory, path and filename work
//---------------------------------------------------------------

    .align $100
* = * "input buffer"
input_buffer:
    .fill $100,0
* = * "work buffer"
work_buffer:
    .fill $100,0
work_buffer2:
    .fill $100,0
work_io:
    .fill $100,0
work_entries:
    .fill $100,0
work_path:
    ppath(128)
work_path2:
    ppath(128)
work_filename:
    .fill $80,0
work_filename2:
    .fill $80,0

work_name:
    .fill $40,0
work_pprint:
    .fill $80,0

.print "work_buffer=$"+toHexString(work_buffer)
.print "work_path=$"+toHexString(work_path)
.print "work_path.path=$"+toHexString(work_path.path)
.print "work_path.filename=$"+toHexString(work_path.filename)
.print "work_path2=$"+toHexString(work_path2)
.print "work_name=$"+toHexString(work_name)
.print "work_pprint=$"+toHexString(work_pprint)

* = * "end of workspaces"

//====================================================
// SHELL
// start address moved into $8000 cartridge space so
// the shell can be restarted with a reset.
// Still, source code is not ROM compatible due to
// some remaining self-modifying bits
//====================================================

* = $8000 "shell start"

.namespace shell 
{
//----------------------------------------------------
// C64 Cartridge header
//----------------------------------------------------

    .word coldstart
    .word warmstart
    .byte $C3,$C2,$CD,$38,$30

coldstart:
{
    sei
    stx $d016
    jsr $fda3   // prepare IRQ
    jsr $fd15   // init IO
    jsr $ff5b   // init video
    cli
    jmp bios.do_reset
}

warmstart:
{
    jmp bios.do_reset
}

//----------------------------------------------------
// insert BIOS entries starting $8100 (fixed address)
//----------------------------------------------------

* = $8100

#import "bios_pp.asm"

//----------------------------------------------------
// remaining shell code
//----------------------------------------------------

* = * "shell code"

//----------------------------------------------------
// extract_cmd : split command and parameters
//
// A = separator, R0 = input
// output : R0 command, R1 paramters
// C=1 if parameters are present
//----------------------------------------------------

extract_cmd:
{
    sta separateur
    push r0
    ldy #0
    sty guillemets
    mov r1, r0
    
    getbyte_r(0)    
    sta lgr_entree
    sta lgr_parcours
    cmp #0
    beq fin_extract

next_byte:
    getbyte_r(0)
    cmp separateur
    beq sep_trouve
    dec lgr_parcours
    bne next_byte
    beq fin_extract

    // separator found : cut the string, adjust the length ajuste
    // for r0, replaces separator byte by remaining length
    //
    // lgr commande = lgr_entree - lgr_parcours
    // lgr param = lgr_parcours - 1 

sep_trouve:

    pop r0
    sec
    lda lgr_entree
    sbc lgr_parcours
    ldy #0
    sta (zr0),y
    tay
    iny
    sec
    lda lgr_parcours
    sbc #1
    sta (zr0),y
    tya
    add r1, a
    sec
    rts

fin_extract:
    pop r0
    clc
    rts

separateur:
    .byte 0
guillemets:
    .byte 0
lgr_parcours:
    .byte 0
lgr_entree:
    .byte 0
}

//----------------------------------------------------
// cmd_echo : prints expansed parameters
//----------------------------------------------------

cmd_echo:
{
    ldx parameters.list
    dex
    beq sans_param

    stx nb_parameters
    lda #1
    sta pos_param

boucle_echo:
    ldx pos_param
    swi list_get, parameters.list
    swi pprint
    inc pos_param
    dec nb_parameters
    beq sans_param
    lda #32
    jsr CHROUT
    jmp boucle_echo

sans_param:
    lda #13
    jsr CHROUT
    clc
    rts
}

nb_parameters:
    .byte 0
pos_param:
    .byte 0

//----------------------------------------------------
// cmd_lsblk : tries to detect disks and disks types,
// output A = nb of disks found
//----------------------------------------------------

cmd_lsblk:
    clc
    swi lsblk
    rts

//----------------------------------------------------
// cmd_dump : prints all environment variables
// (name and value) paginates if option present
//----------------------------------------------------

cmd_dump:
{
    sec
    jsr option_pagine

    lda type_dump
    beq dump_env

    swi var_count, internal_commands
    sta parcours_variables
    cmp #0
    jeq fin_dump
    mov r0, #internal_commands
    jmp boucle_dump

dump_env:
    swi var_count, var_names
    sta parcours_variables
    cmp #0
    beq fin_dump

    mov r0, #var_names

boucle_dump:

    // r2 = partie nom
    mov r2, r0
    
    // r0 += longueur + 1 = adresse valeur
    ldy #0
    mov a, (r0)
    clc
    adc #1
    add r0, a

    // lecture adresse valeur -> dans r1
    // devrait être un mov r1, (r0)
    lda (zr0),y
    sta zr1l
    iny
    lda (zr0),y
    sta zr1h

    // et ajout 2 pour positionner r0 sur le suivant
    add r0, #2

    push r0

    // si type de dump pas environnement, n'affiche pas
    // les valeurs des variables
    lda type_dump
    beq type_env
    mov r0, #txt_autre
    jmp suite_env

type_env:
    mov r0, #txt_env

suite_env:
    mov r3, r1
    swi pprintnl
    clc
    jsr option_pagine

    pop r0
    jsr STOP
    beq fin_dump

    dec parcours_variables
    bne boucle_dump

    // fin, remet le type de dump à 0 = env
fin_dump:
    lda #0
    sta type_dump
    clc
    rts

type_dump:
    .byte 0
parcours_variables:
    .byte 0

txt_env:
    pstring(" %P2=%P3")
txt_autre:
    pstring(" %P2")
}

//----------------------------------------------------
// cmd_set : sets an environment variable value
//----------------------------------------------------

cmd_set:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    lda #'='
    jsr extract_cmd
    swi var_set
    clc
    rts
}

//----------------------------------------------------
// cmd_status : current disk status
//----------------------------------------------------

cmd_status:
{
    sec
    swi get_device_status
    rts
}

//----------------------------------------------------
// cmd_device : change device
//----------------------------------------------------

cmd_device:
{
    needs_parameters(1)

    ldx #1
    swi list_get, parameters.list

change:
    mov r1, r0
    lda bios.device
    sta prev_device

    swi var_set, device_var
    swi set_device
    bcs pb_device
    clc
    rts

    // si pb device, remet l'ancien
pb_device:
    lda prev_device
    jsr bios.do_set_device_from_int
    sec
    rts

prev_device:
    .byte 0
device_var:
    pstring("DEVICE")
}

//----------------------------------------------------
// cmd_cmd : sets command to current device
//
// r1 : command to send
//----------------------------------------------------

cmd_cmd:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    jmp do_cmd_send
}

do_cmd_send:
{
    ldx #15
    sec
    swi file_open
    bcs error

close_file:
    ldx #15
    swi file_close
    clc
    rts

error:
    sec
    swi get_device_status
    jsr close_file
    sec
    rts
}

//----------------------------------------------------
// cmd_cp : file copy
//
// objectives :
// 1 to 1 file copy
// n-1 fichiers to n/ if n is a path
//
// options :
//  M = move
//  C = compatible (force compatible file copy, not
// using disk copy command)
// (F = Force)
//----------------------------------------------------

cmd_mv:
{
    mov r1, #cmd_cp.options_cp
    jsr check_options
    ora #cmd_cp.OPT_M
    jmp cmd_cp.options_ok
}

cmd_cp:
{
    needs_parameters(2)
    lda bios.device
    sta bios.save_device
    mov r1, #options_cp
    jsr check_options
options_ok:
    sta options

    // destination = dernier paramètre
    swi list_size, parameters.list
    tax
    dex
    swi list_get, parameters.list
    mov r1, #work_path2
    swi prep_path
    dec parameters.list
    swi parameters_loop, do_cp, parameters.list
    clc
    rts

.label OPT_M=1
.label OPT_C=2
options:
    .byte 0
options_cp:
    pstring("MC")
write_str:
    pstring(",P,W")
}

do_cp:
{
    lda bios.device
    sta bios.save_device

    // préparation path source, nom en entrée dans R0
    mov r1, #work_path
    swi prep_path

    // path source sans séparateur path<:>nom
    sec
    mov r1, #work_path
    swi build_path, work_filename
    stx bios.device_source
    jsr bios.do_set_device_from_int

    // même disque = tests pour utilisation commandes CBM DOS
    // sauf si option C

    lda cmd_cp.options
    and #cmd_cp.OPT_C
    bne process_cp

    // tests device + partition
    lda work_path+1
    cmp work_path2+1
    bne process_cp
    lda work_path+2
    cmp work_path2+2
    bne process_cp
    // si pas de path
    lda work_path
    and #PPATH.WITH_PATH
    bne process_cp
    lda work_path2
    and #PPATH.WITH_PATH
    bne process_cp

    // ici : même device / partition / pas de path
    lda cmd_cp.options
    and #cmd_cp.OPT_M
    beq pas_move

    jmp move_direct

pas_move:
    jmp copy_direct

process_cp:
    // open fichier en entrée #4
    clc
    ldx #4
    swi file_open, work_filename
    jcs erreur_open_1

    // path destination sans séparateur path<:>nom
    sec
    mov r1, #work_path2
    swi build_path, work_buffer2
    stx bios.device_dest
    lda work_path2
    and #PPATH.WITH_NAME
    bne avec_nom
    // ajoute le nom si pas présent en destination
    swi path_get_name, work_path
    mov r0,#work_buffer2
    swi str_cat

avec_nom:
    // avec suffixe pour écriture
    mov r0, #work_buffer2
    mov r1, #cmd_cp.write_str
    swi str_cat

dest_ok:
    // open fichier en sortie #5
    
    ldx bios.device_dest
    jsr bios.do_set_device_from_int

    sec
    ldx #5
    swi file_open, work_buffer2
    bcs erreur_open_2

copie_fichier:
    lda #'R'
    jsr CHROUT
    ldx #4
    lda #255
    sta work_io
    swi buffer_read, work_io
    stc lecture_finie
    jsr CLRCHN
    lda #20
    jsr CHROUT
    lda #'W'
    jsr CHROUT
    ldx #5
    swi buffer_write, work_io
    jsr CLRCHN
    lda #20
    jsr CHROUT
    lda lecture_finie
    bne fin_copie
    jmp copie_fichier

fin_copie:
    // option M = MV ?
    lda cmd_cp.options
    and #cmd_cp.OPT_M
    beq pas_opt_m
    jsr delete_source

pas_opt_m:
    jsr close_files
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    clc
    rts

erreur_open_2:
    ldx #5
    swi file_close
    swi error, msg_error.write_error
    jmp close1

erreur_open_1:
    swi error, msg_error.read_error

close1:
    ldx #4
    swi file_close
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    sec
    rts

delete_source:
    ldx bios.device_source
    jsr bios.do_set_device_from_int
    ldx #1
    swi str_ins, work_filename, cmd_delete
    mov r1, r0
    jmp do_cmd_send

move_direct:
    swi str_cpy, cmd_rename, work_buffer
move_direct_names:
    swi path_get_name, work_path2
    swi str_cat, work_buffer
    swi str_cat, work_buffer, cmd_egal
    swi path_get_name, work_path
    swi str_cat, work_buffer
    mov r1, r0
    jmp do_cmd_send

copy_direct:
    swi str_cpy, cmd_copy, work_buffer
    jmp move_direct_names

cmd_delete:
    pstring("S:")
cmd_rename:
    pstring("R:")
cmd_copy:
    pstring("C:")
cmd_egal:
    pstring("=")

lecture_finie:
    .byte 0

close_files:
    ldx #4
    swi file_close
    ldx #5
    swi file_close
    rts

}

//----------------------------------------------------
// needs_parameter : if no parameters (C=0),
// prints error and pulls return address from stack in
// order to avoid executing command
//----------------------------------------------------

.macro needs_parameters(nb_params)
{
    lda #nb_params
    jsr do_needs_parameters
}

do_needs_parameters:
{
    cmp parameters.list
    bpl ko
    rts
ko:
    swi error, msg_error.needs_parameters
    pla
    pla
    rts
}

//----------------------------------------------------
// check_options : check the options given in the
// parameters
// input = reads parameters, r1 = valid options string
// output : c=0 OK, c=1 and A=0 no options
// c=1 and A=1 : invalid option was given
//----------------------------------------------------

check_options:
{
    lda parameters.options
    beq pas_options
    mov r0, #parameters.options
    jsr do_get_options
    bcc options_ok
    cmp #0
    beq pas_options

    swi error, msg_error.invalid_option
    pla
    pla
    rts
pas_options:
    lda #0
options_ok:
    clc
    rts  
}

//----------------------------------------------------
// option_pagine : pagination option processing for
// printing in CAT / LS commands
// input : if C=1 performs intialisation of number of
// lines already printed. subsequent calls C=0
//----------------------------------------------------

option_pagine:
{
    bcc do_pagination
    lda #0
    sta cpt_ligne
    clc
    rts

do_pagination:
    inc cpt_ligne
    lda cpt_ligne
    cmp #13
    bne pas_opt_p

    lda #0
    sta cpt_ligne
    swi pprint, msg_suite
    swi key_wait
    ldy #6
    lda #20
efface_msg:
    jsr CHROUT
    dey
    bne efface_msg
    // ici il faudrait vider le buffer clavier
pas_opt_p:
    rts

cpt_ligne:
    .byte 0
msg_suite:
    pstring("%CF<MORE>%C5")
}

//----------------------------------------------------
// cmd_input : user input, storage into the environment
// variable indicated as parameter
// if [invite] is given : prints invite first
//
// input [invite] <variable>
//
// options :
//  K = single key press
//  P = print hex code of key pressed
//----------------------------------------------------

cmd_input:
{
    .label OPT_K=1
    .label OPT_P=2

    mov r1, #options_input
    jsr check_options
    sta options
    lda options
    and #OPT_K
    bne wait_key

    needs_parameters(1)

    lda parameters.list
    cmp #3
    bne pas_texte_invite

    jsr invite

    ldx #2
    swi list_get, parameters.list
    mov r1, r0
    
input_var:
    swi input
    swap r0, r1
    swi var_set
    clc
    rts

pas_texte_invite:
    ldx #1
    swi list_get, parameters.list
    mov r1, r0
    jmp input_var

wait_key:
    lda parameters.list
    cmp #2
    bne do_wait
    jsr invite

do_wait:
    jsr GETIN
    beq do_wait
    tax
    lda options
    and #OPT_P
    beq pas_opt_p
    stx zr0l
    swi pprinthex8

pas_opt_p:
    lda #13
    jsr CHROUT
    clc
    rts

invite:
    ldx #1
    swi list_get, parameters.list
    mov r1, r0
    swi pprint
    rts

options_input:
    pstring("KP")
options:
    .byte 0
}

//----------------------------------------------------
// cmd_wait : wait vblanks
//----------------------------------------------------

cmd_wait:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    swi wait
    clc
    rts
}

//----------------------------------------------------
// cmd_filter : test for filter, not a real command,
// has to go
//----------------------------------------------------

cmd_filter:
{
    swi var_get, var_test
    mov r2, r1
    swi var_get,var_pattern
    mov r0, r2
    swi str_pat
    bcc no_match
    swi pprintnl, msg_match
no_match:
    clc
    rts

var_test:
    pstring("TEST")
var_pattern:
    pstring("PATTERN")
msg_match:
    pstring("MATCHING")
}

//----------------------------------------------------
// cmd_cat : print file(s)
//
// options : 
// N = numbers all lines
// E = prints a $ sign at the end of line
// B = numbers non empty lines
// P = paginates output
// H = hexdump
// A = reads start address in file for hexdump
//----------------------------------------------------

cmd_more:
{
    lda #do_cat.OPT_P
    jmp cmd_cat.options_ok
}

cmd_cat:
{
    needs_parameters(1)
    mov r1, #options_cat
    jsr check_options

options_ok:
    sta options

    // sauve device courant pour référence aux
    // paths sans device d'indiqué
    lda bios.device
    sta bios.save_device
    swi parameters_loop, do_cat, parameters.list
    clc
    rts

options:
    .byte 0
options_cat:
    pstring("BENPHA")
}

// do_cat : effectue la commande CAT unitaire, nom en R0

do_cat:
{
    .label OPT_B=1
    .label OPT_E=2
    .label OPT_N=4
    .label OPT_P=8
    .label OPT_H=16
    .label OPT_A=32

    // initialisation
    ldy #0
    sty num_lignes
    sty num_lignes+1

    // passe le nom en r0 par un objet ppath
    // mise à jour device + nom construit dans r0

    mov r1, #work_path
    swi prep_path
    mov r1, #work_path
    swi set_device_from_path, work_path
    mov r1, #work_path
    clc
    swi build_path, work_buffer
    mov r0, #work_buffer

    sec
    jsr option_pagine

    // ouverture en lecture, nom dans r0
    ldx #4
    clc
    swi file_open
    jcs error

    // passe le canal en lecture si pas hexdump

    lda cmd_cat.options
    and #OPT_H
    bne open_hex
    ldx #4
    jsr CHKIN
open_hex:

    // test pour file not found
    //jsr READST
    //bne end

    jsr option_start_address

boucle_cat:
    lda cmd_cat.options
    and #OPT_H
    beq pas_hexdump

    ldx #4
    lda #8
    sta buffer_hexdump
    clc
    swi buffer_read, buffer_hexdump
    bcs derniere_ligne_hex
    jsr option_pagination
    jsr print_hex_buffer
    jmp suite_cat
    
pas_hexdump:

    swi file_readline, work_buffer
    bcs derniere_ligne
    jsr affiche_ligne

suite_cat:
    jsr STOP
    beq end
    bne boucle_cat

affiche_ligne:
    jsr option_pagination
    jsr option_numero
    swi pprint, work_buffer

    // option E = affiche $ en fin de ligne
    lda cmd_cat.options
    and #OPT_E
    beq pas_option_e
    lda #'$'
    jsr CHROUT

pas_option_e:
    lda #13
    jmp CHROUT

derniere_ligne_hex:
    jsr print_hex_buffer
    jmp fin_cat

derniere_ligne:
    jsr affiche_ligne

fin_cat:
    lda #0
end:
    and #2
    bne error

    ldx #4
    swi file_close
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    clc
    rts

    // erreur : file not found

error:
    ldx #4
    swi file_close
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    swi error, msg_error.file_not_found
    rts

    // option pagination : affichage sur 13 lignes max

option_pagination:
    lda cmd_cat.options
    and #OPT_P
    jne option_pagine
    rts

option_numero:
    lda cmd_cat.options
    and #OPT_B
    beq pas_opt_b
    lda work_buffer
    bne opt_b_numero_ok

pas_opt_b:
    lda cmd_cat.options
    and #OPT_N
    beq pas_numero

opt_b_numero_ok:
    incw num_lignes
    ldx #%10011111
    mov r0, num_lignes
    swi pprint_int
    lda #32
    jsr CHROUT

pas_numero:
    rts

option_start_address:
    mov r1, #0
    lda cmd_cat.options
    and #OPT_A
    beq pas_opt_A
    ldx #4
    jsr CHKIN
    jsr CHRIN
    sta zr1l
    jsr CHRIN
    sta zr1h

pas_opt_A:
    rts

num_lignes:
    .word 0
buffer_hexdump:
    pstring("01234567")
}

//----------------------------------------------------
// file_load
//----------------------------------------------------

cmd_file_load:
{

    // passe le nom en r0 par un objet ppath
    // mise à jour device + nom construit dans r0

    mov r1, #work_path
    swi prep_path
    mov r1, #work_path
    swi set_device_from_path, work_path
    mov r1, #work_path
    clc
    swi build_path, work_buffer
    mov r0, #work_buffer

    // ouverture en lecture, nom dans r0
    ldx #2
    clc
    swi file_open
    jcs error

    // passe le canal en lecture
    //ldx #2
    //jsr CHKIN

    // test pour file not found
    jsr READST
    bne fin_load

    mov r2, #$4000
    ldy #0
    jsr CHRIN
    jsr CHRIN

boucle_load:
    jsr CHRIN
    mov (r2++), a
    jsr READST
    bne fin_load
    jmp boucle_load

fin_load:
    and #2
    bne error
    ldx #2
    swi file_close
    clc
    rts

    // erreur : file not found

error:
    ldx #2
    swi file_close
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    swi error, msg_error.file_not_found
    rts
}

//----------------------------------------------------
// cmd_do_cmd : sends command to current device
// r1 : prefix of command to send
// r0 : path to use
//----------------------------------------------------

cmd_do_cmd:
{
    stc avec_sep

    // analyse du path en R0, retour = work_path
    push r1
    mov r1, #work_path
    swi prep_path

    lda work_path
    and #PPATH.WITH_DEVICE
    beq pas_de_device

    // change de device si device dans le path
    // et contrôle existence device
    ldx work_path+1
    lda bios.devices,x
    bne pas_erreur_device

    swi error, msg_error.device_not_present
    pop r1
    sec
    rts

pas_erreur_device:
    txa
    jsr bios.do_set_device_from_int

pas_de_device:
    // construction du path cible dans work_buffer
    mov r1, #work_path
    lda avec_sep
    ror
    swi build_path, work_buffer

    // commande à envoyer = r5 + work_buffer

    ldy #0
    sty work_buffer2

    mov r0, #work_buffer2
    pop r1
    swi str_cat

    mov r1, #work_buffer
    swi str_cat

    lda work_buffer2
    ldx #<work_buffer2+1
    ldy #>work_buffer2+1
    jsr SETNAM

    lda #15
    ldx bios.device
    tay
    jsr SETLFS

    jsr OPEN
    bcs error

    // erreur à gérer pour affichage
    sec
    swi get_device_status

    ldx #15
    swi file_close
    clc
    rts

error:
    swi pprintnl, erreur
    sec
    rts
erreur:
    pstring("ERREUR")
avec_sep:
    .byte 0
}

//---------------------------------------------------------------
// get_options : reads options presents in r0 if r0
// contains options (options should start with "-"),
//
// input : r0 = parameters string,
// r1 = list of options available for command
//
// output : if ok C=0, A = options bitmap, else C=1 and A = 0
//---------------------------------------------------------------

do_get_options:
{
    // utilise r2 au lieu de r0 pour conserver r0
    mov r2, r0
    ldy #0
    sty options

    mov a, (r2++)
    beq pas_options

    // si options présentes = il y en a lgr - 1
    tay
    dey
    sty nb_options

    // vérifie la syntaxe
    ldy #0
    mov a, (r2++)
    cmp #'-'
    bne pas_options

    // parcours de r0, recherche si option dans r1
    // si pas dans r1 = erreur, si dans r1 ajoute option

    // nb_options_total = nb d'options dans la liste des options
    // zr1 pointe sur le débute de la liste des options
    
    mov a, (r1++)
    sta nb_options_total
    
    // teste chaque option de zr2 : si trouvé ajoute aux
    // options, si non trouvé = erreur d'option
next_option:
    ldy #0
    mov a, (r2++)

    ldy #0
test_tout:
    cmp (zr1),y
    beq trouve
    iny
    cpy nb_options_total
    beq pas_trouve
    jmp test_tout

trouve:
    // trouve : enregistre et passe à la suivante
    lda options
    jsr bios.set_bit
    sta options

    // boucle si il reste des options en entrée à tester
    dec nb_options
    bne next_option

    // sinon on est OK, retour A = options et C=0
    lda options
    clc
    rts

pas_trouve:
    lda #1
    sec
    rts

pas_options:
    sec
    lda #0
    rts

options:
    .byte 0
nb_options:
    .byte 0
nb_options_total:
    .byte 0

.print "nb_options=$"+toHexString(nb_options)
.print "nb_options_total=$"+toHexString(nb_options_total)
.print "options=$"+toHexString(options)
}

//----------------------------------------------------
// cmd_mkdir : create directory
//----------------------------------------------------

cmd_mkdir:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    mov r1, #commande
    clc
    jmp cmd_do_cmd

commande:
    pstring("MD")
}

//----------------------------------------------------
// cmd_rmdir : remove directory
//----------------------------------------------------

cmd_rmdir:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    mov r1, #commande
    clc
    jmp cmd_do_cmd

commande:
    pstring("RD")
}

//----------------------------------------------------
// cmd_rm : remove file(s)
//----------------------------------------------------

cmd_rm:
{
    needs_parameters(1)
    swi parameters_loop, do_rm, parameters.list
    clc
    rts

do_rm:
    mov r1, #commande
    clc
    jmp cmd_do_cmd

commande:
    pstring("S")
}

//----------------------------------------------------
// cmd_cd : directory change
//----------------------------------------------------

cmd_cd:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    mov r1, #parent
    swi str_cmp
    bcc not_parent
    mov r0, #oparent
not_parent:
    mov r1, #commande
    clc
    jmp cmd_do_cmd

commande:
    pstring("CD")
parent:
    pstring("..")
oparent:
    .byte 1
    .byte 95
}

//----------------------------------------------------
// cmd_clear : clear the screen
//----------------------------------------------------

cmd_clear:
{
    lda #147
    jsr CHROUT
    clc
    rts
}

//----------------------------------------------------
// cmd_ls : print directory
// A : format : 
//  0 -> disk name
//  1 -> blocks free
//  2 -> size
// if C=1, check parameters in r1
// 
// options :
//
// L = long format
// D = only directories
// P = paginates output
//----------------------------------------------------

cmd_ll:
{
    mov r1, #cmd_ls.options_ls
    jsr check_options
    ora #cmd_ls.OPT_LONG
    jmp cmd_ls.options_ok
}

cmd_ls:
{
    .label FT_DISKNAME=1
    .label FT_FREE=2
    .label FT_SIZE=4

    .label OPT_LONG=1
    .label OPT_DIR=2
    .label OPT_PAGE=4
    
    mov r1, #options_ls
    jsr check_options
    
options_ok:
    sta options
    sec
    jsr option_pagine

pas_options:
    lda #0
    sta format
    lda options
    and #OPT_LONG
    beq pas_option_L

    lda #FT_DISKNAME+FT_FREE+FT_SIZE
    sta format

pas_option_L:
    lda #0
    sta colonnes
    sta tosize40

    // ouverture répertoire
    swi directory_open
    bcc open_ok
    sec
    rts

open_ok:
    lda parameters.list
    cmp #2
    bne do_dir

    // si filtre en paramètre, copie le 
    ldx #1
    swi list_get, parameters.list
    ldx #255
    swi directory_set_filter

    // lecture nom du disque / répertoire
do_dir:
    lda options
    and #OPT_DIR
    beq pas_opt_dir

    lda #bios.directory.TYPE_DIR
    sta bios.directory.filter_types
    
pas_opt_dir:
    swi directory_get_entry
    jcs exit

    lda format
    and #FT_DISKNAME
    beq not_ft_diskname
    swi pprint, bios.directory.entry.filename
    lda #32
    jsr CHROUT
    swi pprintnl, bios.directory.entry.type

not_ft_diskname:
next:
    lda options
    and #OPT_PAGE
    beq pas_opt_page
    clc
    jsr option_pagine

pas_opt_page:
    swi directory_get_entry
    bmi pas_opt_page
    jcs exit
    bne pas_blocs

    // affichage blocks free
blocs:
    lda format
    and #FT_FREE
    beq pas_aff_blocs_free

    ldx #%11111111
    mov r0, bios.directory.entry.size
    swi pprint_int
    swi pprintnl, blocksfree

pas_aff_blocs_free:
    jmp exit

    // affichage nom fichier
pas_blocs:
    lda format
    and #FT_SIZE
    beq pas_ft_size

    jsr set_dir_color

pas_filtre_dir:
    swi pprint, bios.directory.entry.type
    ldx #%11111111
    mov r0, bios.directory.entry.size
    swi pprint_int
    lda #32
    jsr CHROUT

pas_ft_size:
    lda format
    and #FT_SIZE
    beq pas_ft_size_name

    swi pprintnl, bios.directory.entry.filename
    lda #5
    sta 646
    jmp do_next

pas_ft_size_name:
    jmp print_name_no_size

size40:
    lda tosize40
    cmp #20
    beq do_next
    inc tosize40
    lda #32
    jsr CHROUT
    jmp size40

do_next:
    jsr STOP
    beq error      // no RUN/STOP -> continue
    jmp next

error:
    // A contains error code
    // most likely error:
    // A = $05 (DEVICE NOT PRESENT)
exit:
    lda colonnes
    bne pas_impair
    lda #13
    jsr CHROUT

pas_impair:
    swi directory_close
    rts

    // print_name_no_size : affichage nom sans taille
print_name_no_size:
    lda bios.directory.entry.filename
    sta tosize40

    jsr set_dir_color
    swi pprint, bios.directory.entry.filename
    lda #5
    sta 646
    lda colonnes
    beq size40

    lda #1
    sta colonnes
    lda #$0d
    jmp CHROUT

set_dir_color:
    // type fichier
    lda bios.directory.entry.type+1
    cmp #'D'
    bne pas_dir
    lda #13
    sta 646
pas_dir:
    cmp #'*'
    bne pas_ouvert
    lda #2
    sta 646
pas_ouvert:
    rts

blocksfree:
    pstring(" BLOCKS FREE")
format:
    .byte 0
colonnes:
    .byte 0
tosize40:
    .byte 0
options:
    .byte 0

options_ls:
    pstring("LDP")
}

//----------------------------------------------------
// toplevel : toplevel loop
//----------------------------------------------------

* = * "toplevel"

.print "history_list=$"+toHexString(history_list)

//------------------------------------------------------------
// check_history : if max is reached then removes 1 record
//------------------------------------------------------------

check_history:
{
    swi str_len, history_list
    cmp max_history
    beq pas_max
    bmi pas_max

    dec nb_history
    ldx #0
    swi list_del, history_list

pas_max:
    rts
}

//------------------------------------------------------------
// add_history :
// add command to history, if command is not "history"
// and command is not empty
//------------------------------------------------------------

add_history:
{
    swi str_len
    beq pas_copie_history

    mov r1, #history_kw
    swi str_cmp
    bcs pas_copie_history

    mov r1, r0
    swi list_add, history_list
    inc nb_history

pas_copie_history:
    rts
}

toplevel:

    // affiche le prompt
    swi var_get, varprompt
    mov r0, r1
    swi pprint

    // si on dépasse le max historique : supprime 1 enreg
    jsr check_history

    // lecture de la commande, retour en r0 = input_buffer
    //sec
    //ldx #10
    clc
    swi input
    
    // ajout à l'historique
    jsr add_history

    // execute la commande
    jsr command_process
    jmp toplevel

command_process:
{
    // découpage des paramètres    
    mov r0, #input_buffer
    jsr do_get_params
    //swi list_print, parameters.list

    // pas de commande = boucle
    lda parameters.list
    bne non_vide
    rts

non_vide:
    ldx #0
    swi list_get, parameters.list
    jsr bios.lookup_cmd
    bcc non_trouve

    // exécute la commande si commande interne
    jmp command_execute

    // commande non trouvée en interne, essaye en externe, d'abord sur
    // le répertoire en cours
non_trouve:

    ldx #'.'
    swi str_chr
    bcc is_binary

    iny
    lda (zr0),y
    cmp #'S'
    bne pas_script
    iny
    lda (zr0),y
    cmp #'H'
    bne pas_script

    jmp script_execute

pas_script:
    swi error, msg_error.command_not_found
    rts

is_binary:
    clc
    jmp bios.do_file_load
}

command_execute:
{
    mov jmp_cmd, r1
    jmp jmp_cmd:$fce2
}

script_execute:
{
    push r0
    swi parameters_export, parameters.list
    pop r0
    swi script_read
    clc
    rts

    // open file for reading, name in r0
    ldx #8
    clc
    swi file_open
    bcs error

next_line:
    ldx #8
    sec
    lda #255
    sta input_buffer
    swi buffer_read, input_buffer
    bcs fini

    // si ligne vide, empty ou commence par # = ignore
    swi str_empty
    bcc next_line
    ldy #1
    lda (zr0),y
    cmp #'#'
    beq next_line

    lda #'>'
    jsr CHROUT
    swi pprintnl

    // sinon traite la ligne
    mov r0, #input_buffer
    jsr command_process
    jmp next_line

fini:
    ldx #8
    swi file_close
    clc
    rts

error:
    jsr fini
    swi error, msg_error.command_not_found
    rts
}

nb_history:
    .byte 0
max_history:
    .byte 10

history_list:
    plist(history_data)
history_data:
    .fill 512,0

// parameters : stockage options et paramètres pour get_params
parameters:
{
options:
    pstring("-00000000")
list:
    plist(data)
data:
    .fill 256,0
}

//---------------------------------------------------------------
// get_params : split command /  parameters / options
// input R0 = parameters list
// output in parameters : options and list of command / params
//---------------------------------------------------------------

do_get_params:
{
    // travaille avec r4 pour la lecture
    mov r4, r0
    // raz options (positions 2 à 9, conserve lgr et -)
    mov r1, #parameters.options
    
    ldy #2
    lda #$30
raz_options:
    sta (zr1),y
    iny
    cpy #10
    bne raz_options
    lda #0
    sta parameters.options

    // raz liste des paramètres
    
    mov r1, #parameters.data
    swi list_reset, parameters.list

    // raz présence options
    ldy #0
    sty presence_options

    // parcours de la chaine en entrée (r4),
    // lecture longueur et si 0 -> out
    
    getbyte_r(4)
    sta lgr_entree
    cmp #0
    bne lecture_chaine
    jmp fini

    // boucle lecture chaine
lecture_chaine:
    ldy #0
    sty no_eval
    getbyte_r(4)
    dec lgr_entree

    cmp #'-'
    bne pas_options

    //--------------------------------------------------------
    //-- OPTIONS ----
    // if options, reads options, 
    // KO if multiple, else copy to parameters.options
    //--------------------------------------------------------

    mov r1, #parameters.options
    jsr process_traite_options

    //-- test de la suite de la chaine, si non vide,
    //-- si vide : fin
teste_suite_chaine:
    lda lgr_entree
    bne lecture_chaine
    jmp fini

    //--------------------------------------------------------
    //-- QUOTES ----
    // process string quotes separator
    //--------------------------------------------------------

pas_options:
    cmp #34
    beq guillemets34
    cmp #39
    beq guillemets39
    bne pas_guillemets

guillemets39:
    lda #1
    sta no_eval
    lda #39
    bne suite_3439
guillemets34:
    lda #34
suite_3439:
    sta separateur_test
    jsr process_guillemets
    jmp teste_suite_chaine

    //--------------------------------------------------------
    //-- SPACE ----
    // space separator
    // = same as quotes with space for ending
    //--------------------------------------------------------

pas_guillemets:
    cmp #32
    bne pas_espace

    sta separateur_test
    jsr process_guillemets
    jmp teste_suite_chaine

    //--------------------------------------------------------
    //-- OTHER ----
    // not space : that's a string, reads and store 
    //--------------------------------------------------------

pas_espace:

    lda #32
    sta separateur_test
    inc lgr_entree
    dec r4
    jsr process_guillemets
    jmp teste_suite_chaine

    //-------------------------------------------------------------
    // process_guillemets : quotes processing
    //-------------------------------------------------------------

process_guillemets:
    
    // on va recopier le paramètre dans work_buffer
    mov r5, #work_buffer

    // raz lgr début de la chaine à copier = 0 et longueur copiée
    ldy #0
    tya
    sty lgr_copie
    setbyte_r(5)

    // avance tant que pas fin ou nouveaux guillemets
copie_guillemets:
    dec lgr_entree
    ldy #0
    getbyte_r(4)
    cmp separateur_test:#34
    beq fin_de_parametre
    setbyte_r(5)
    inc lgr_copie
    lda lgr_entree
    bne copie_guillemets
    
     //.print "lgr_entree=$"+toHexString(lgr_entree)
     .print "parameters.list=$"+toHexString(parameters.list)

    // fin de parametre, mise à jour longueur et ajout
    // dans la liste
fin_de_parametre:
    lda lgr_copie
    sta work_buffer

    // expanse si pas no_eval et ajoute à la liste
    // des paramètres
    mov r1, #work_buffer2
    lda no_eval
    beq do_eval
    mov r1, #work_buffer
    jmp add_to_list
do_eval:
    swi str_expand, work_buffer
add_to_list:
    swi list_add, parameters.list
    rts

    //-------------------------------------------------------------
    // options issue : error
    //-------------------------------------------------------------

pb_options:
    swi error, msg_error.invalid_parameters
    rts

    //-------------------------------------------------------------
    // process_traite_options : reads and copy options
    //-------------------------------------------------------------

process_traite_options:
    lda lgr_entree
    inc presence_options
    lda presence_options
    cmp #1
    bne pb_options

    // reutilisation pour parcours 2 à 9 de la liste
    // des options (lecture_options = presence_options)
    inc pos_lecture_options

    // recopie des options, HS si plus de 8 options
    // (si pos_lecture_options = 10)
recopie_options:
    ldy #0
    getbyte_r(4)
    // si séparateur = fin des options
    cmp #32
    bne pas_fin_options

    dec lgr_entree // change

    jmp options_ok

pas_fin_options:
    ldy pos_lecture_options
    cpy #10
    bpl pb_options

    sta (zr1),y
    inc pos_lecture_options

    // si plus de données = fini
    dec lgr_entree
    beq options_ok

    jmp recopie_options

    // options OK : mise à jour longueur options et retour
options_ok:
    ldy pos_lecture_options
    dey
    tya
    ldy #0
    sta (zr1),y
    
fini:
    lda lgr_entree
    clc
    rts

no_eval:
    .byte 0
lgr_entree:
    .byte 0
presence_options:
pos_lecture_options:
    .byte 0
lgr_copie:
    .byte 0

.print "parameters=$"+toHexString(parameters)
.print "parameters.options=$"+toHexString(parameters.options)

}

//---------------------------------------------------------------
// cmd_koala : reads and show a koala file picture
//---------------------------------------------------------------

cmd_koala:
{
    needs_parameters(1)
    mov r1, #options_koala
    jsr check_options
    sta options
    swi parameters_loop, do_koala, parameters.list
    clc
    ldx #0
    swi picture_show
    clc
    jmp cmd_clear

options:
    .byte 0
options_koala:
    pstring("KW")
}

do_koala:
{
    mov r1, #$4000
    sec
    swi file_load
    clc
    lda cmd_koala.options
    and #OPT_K
    bne pas_K
    sec
pas_K:
    ldx #1
    swi picture_show
    lda cmd_koala.options
    and #OPT_W
    bne pas_W
    mov r0, #$0050
    swi wait
pas_W:
    clc
    rts

.label OPT_K=1
.label OPT_W=1
}

//---------------------------------------------------------------
// cmd_history : prints command history
//---------------------------------------------------------------

cmd_history:
{
    swi list_print, history_list
    clc
    rts
}

//---------------------------------------------------------------
// cmd_save_env : exports environment variables
//
// Not working yet
//
// parameter : path/name for writing
//---------------------------------------------------------------

cmd_save_env:
{
    needs_parameters(1)
    ldx #1
    swi list_get, parameters.list
    mov r1, #work_path
    swi prep_path
    sec
    mov r1, #work_path
    swi build_path, work_buffer
    mov r0, #work_buffer
    mov r1, #cmd_cp.write_str
    swi str_cat

    sec
    ldx #3
    swi file_open, work_buffer
    bcc ok_open
    jmp erreur_open

ok_open:
    swi var_count, var_names
    sta parcours_variables
    cmp #0
    bne ok_dump
    jmp fin_dump

ok_dump:
    mov r0, #var_names
    ldx #3
    jsr CHKOUT

boucle_dump:

    // r2 = partie nom
    mov r2, r0
    
    // r0 += longueur + 1 = adresse valeur
    swi str_len
    add r0, #1

    // lecture adresse valeur -> dans r1
    mov r1, (r0)

    // et ajout 2 pour positionner r0 sur le suivant
    add r0, #2

    push r0

    // ici : écriture

    lda #'S'
    jsr CHROUT
    lda #'E'
    jsr CHROUT
    lda #'T'
    jsr CHROUT
    lda #32
    jsr CHROUT

    getbyte_r(2)
    tax
write_name:
    getbyte_r(2)
    jsr CHROUT
    dex
    bne write_name

    lda #'='
    jsr CHROUT

    getbyte_r(1)
    tax
write_val:
    getbyte_r(1)
    jsr CHROUT
    dex
    bne write_val

    lda #13
    jsr CHROUT
    jsr CLRCHN

    pop r0

    dec parcours_variables
    beq fin_dump 
    jmp boucle_dump
fin_dump:
    ldx #3
    swi file_close

    clc
    rts

parcours_variables:
    .byte 0

erreur_open:
    ldx #3
    swi file_close
    swi error, msg_error.write_error
    sec
    rts
}

//---------------------------------------------------------------
// cmd_help : lists internal commands, if used with parameter
// then parameter is command name to fetch help for
// if <command>.hlp file exists in config path then prints it
//---------------------------------------------------------------

cmd_help:
{
    lda parameters.list
    cmp #1
    beq no_params
    ldx #1
    swi list_get, parameters.list
    mov r5, r0
    mov r1, #work_buffer
    swi str_expand, help_location
    mov r0, r1
    
    lda bios.device
    sta bios.save_device
    lda #do_cat.OPT_P
    sta cmd_cat.options
    jsr do_cat
    ldx bios.save_device
    jsr bios.do_set_device_from_int

    clc
    rts

no_params:
    swi pprintnl, help_message
    lda #1
    sta cmd_dump.type_dump
    jmp cmd_dump

help_location:
    pstring("%VCONFIG%%P5.HLP")
help_message:
    pstring(" LIST OF COMMANDS TRY HELP <COMMAND>m OR HELP MEm")
}

//---------------------------------------------------------------
// cmd_quit : exits the shell prompt
//---------------------------------------------------------------

cmd_quit:
    ldx #$ff
    sei
    txs
    cld
    jmp $fcef

presence_separateur:
    .byte 0
varprompt:
    pstring("PROMPT")
txt_bye:
    pstring("%C1BYEm")

//----------------------------------------------------
// cmd_load : loads file in memory to given address
//----------------------------------------------------

cmd_load:
{
    needs_parameters(2)
    ldx #2
    swi list_get, parameters.list
    swi hex2int
    mov r1, r0
    dex
    swi list_get, parameters.list
    sec
    swi file_load
    rts
}

//----------------------------------------------------
// cmd_mem : memory dump
// parameters : 1st = start address (hex)
// 2nd if present = end address, else prints 8 bytes 
// of memory max
//----------------------------------------------------

cmd_mem:
{
    needs_parameters(1)
    lda parameters.list
    cmp #3
    bne juste_8

    ldx #2
    swi list_get, parameters.list
    swi hex2int
    mov stop_address, r0
    ldx #1
    swi list_get, parameters.list
    swi hex2int
    jmp boucle_hex

juste_8:
    ldx #1
    swi list_get, parameters.list
    swi hex2int
    push r0
    add r0, #8
    mov stop_address, r0
    pop r0

boucle_hex:
    mov r1, r0
    ldx #0

prep_buffer:
    mov a, (r0++)
    sta bytes+1,x
    inx
    cpx #8
    bne prep_buffer
    push r0
    mov r0, #bytes
    jsr print_hex_buffer
    pop r0

    // check run/stop
    jsr STOP
    beq fin_hex

    // il en reste ?
    lda zr0h
    cmp stop_address+1
    bcc boucle_hex
    lda zr0l
    cmp stop_address
    bcc boucle_hex

fin_hex:
    clc
    rts

stop_address:
    .word 0
nb_bytes:
    .byte 0
bytes:
    .byte 8
    .fill 8,0
}

//---------------------------------------------------------------
// print_hex_buffer : hexdump buffer in r0, address r1
//---------------------------------------------------------------

print_hex_buffer:
{
    swi str_len 
    sta nb_total
    inc r0

aff_line:
    push r0
    mov r0, r1
    sec
    swi pprinthex
    pop r0
    lda #32
    jsr CHROUT

    push r0
    ldx #8
aff_bytes:
    lda nb_total
    bne pas_fini_hex

    lda #'.'
    jsr CHROUT
    jsr CHROUT
    jmp suite_hex

pas_fini_hex:
    dec nb_total
    mov a, (r0++)
    jsr bios.do_pprinthex8a

suite_hex:
    lda #32
    jsr CHROUT
    dex
    bne aff_bytes

    pop r0
    dec r0
    ldx #8
    jsr print_hex_text

    lda #13
    jsr CHROUT
    add r1, #8
    clc
    rts

print_hex_text:
    swi str_len
    sta nb_total
    inc r0
    
    ldx #8
aff_txt:
    lda nb_total
    beq aff_txt_fini
    mov a, (r0++)
    dec nb_total

aff_txt_fini:
    cmp #$20
    bpl pas_moins
    lda #'.'
pas_moins:
    cmp #$80
    bcc pas_plus
    cmp #$a0
    bpl pas_plus
    lda #'.'
pas_plus:
    jsr CHROUT
    dex
    bne aff_txt
    rts

nb_total:
    .byte 0
}


} // namespace shell

//---------------------------------------------------------------
// internal shell commands list
// aliases can be made by adding entries with the same execution
// address
//---------------------------------------------------------------

    .align $100
* = * "internal commands list"
internal_commands:
    pstring("QUIT")
    .word shell.cmd_quit
    pstring("SET")
    .word shell.cmd_set
    pstring("ECHO")
    .word shell.cmd_echo
    pstring("ENV")
    .word shell.cmd_dump
    pstring("LS")
    .word shell.cmd_ls
    pstring("ST")
    .word shell.cmd_status
    pstring("SD")
    .word shell.cmd_device
    pstring("HELP")
    .word shell.cmd_help
    pstring("LSD")
    .word shell.cmd_lsblk
    pstring("CD")
    .word shell.cmd_cd
    pstring("CMD")
    .word shell.cmd_cmd
    pstring("CAT")
    .word shell.cmd_cat
    pstring("MKDIR")
    .word shell.cmd_mkdir
    pstring("RMDIR")
    .word shell.cmd_rmdir
    pstring("RM")
    .word shell.cmd_rm
    pstring("MEM")
    .word shell.cmd_mem
    pstring("CP")
    .word shell.cmd_cp
    pstring("CLEAR")
    .word shell.cmd_clear
    pstring("MORE")
    .word shell.cmd_more
    pstring("SAVEENV")
    .word shell.cmd_save_env
    pstring("INPUT")
    .word shell.cmd_input
    pstring("FILTER")
    .word shell.cmd_filter
    pstring("KOALA")
    .word shell.cmd_koala
    pstring("LOAD")
    .word shell.cmd_load
    pstring("WAIT")
    .word shell.cmd_wait

    //-- aliases
    pstring("LL")
    .word shell.cmd_ll
    pstring("MV")
    .word shell.cmd_mv
    pstring("$")
    .word shell.cmd_ls
    .byte 1, 64 // @
    .word shell.cmd_status

history_kw:
    pstring("HISTORY")
    .word shell.cmd_history
    .byte 0

//---------------------------------------------------------------
// error messages
//---------------------------------------------------------------

msg_error:
{
    pstring("ERROR:")
read_error:
    pstring("READ")
write_error:
    pstring("WRITE")
file_not_found:
    pstring("FILE NOT FOUND")
command_not_found:
    pstring("COMMAND NOT FOUND")
device_not_present:
    pstring("DEVICE NOT PRESENT")
needs_parameters:
    pstring("NEEDS PARAMETERS")
buffer_overflow:
    pstring("OVERFLOW")
invalid_option:
invalid_parameters:
    pstring("INVALID PARAMETERS")
}
