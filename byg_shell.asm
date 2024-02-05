
//===============================================================
// BYG SHELL : Command line Shell
//
// 2024 Babygang
//===============================================================

#import "macros.asm"
#import "kernal.asm"

//====================================================
// SHELL
// start address moved into $8000 cartridge space
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
    //jsr $fd50   // init memory
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
// insère le BIOS à partir de $8100 (fixe)
//----------------------------------------------------

* = $8100

#import "bios.asm"

//----------------------------------------------------
// suite code shell
//----------------------------------------------------

* = * "shell code"

//----------------------------------------------------
// extract_cmd : découpe commande / paramètres
//
// A = séparateur, R0 = entrée
// en sortie : R0 commande et R1 paramètre
// C=1 si paramètres trouvés
//----------------------------------------------------

extract_cmd:
{
    sta separateur
    push_r(0)
    ldy #0
    sty guillemets
    str_r(1, 0)
    
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

    // separateur trouvé : découpe la chaine : ajuste
    // la longueur pour r0, remplace le séparateur par la longueur
    // restant
    // lgr commande = lgr_entree - lgr_parcours
    // lgr param = lgr_parcours - 1 

sep_trouve:

    pop_r(0)
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
    add_r(1)
    sec
    rts

fin_extract:
    pop_r(0)
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
// cmd_echo : affiche le paramètre expansé
//----------------------------------------------------

cmd_echo:
{
    ldx parameters.list
    dex
    beq sans_param

    stx nb_parameters
    lda #1
    sta pos_param
boucle_params:
    ldx pos_param
    call_bios(bios.list_get, parameters.list)
    
    jsr bios.do_pprint
    inc pos_param
    dec nb_parameters
    beq sans_param
    lda #32
    jsr CHROUT
    jmp boucle_params

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
// cmd_keytest : test clavier
//----------------------------------------------------

cmd_keytest:
{
    jsr GETIN
    beq cmd_keytest
    jsr bios.do_pprinthex8a
    lda #13
    jsr CHROUT
    clc
    rts
}

//----------------------------------------------------
// cmd_lsblk : détecte les disques, retour A = nb disques
//----------------------------------------------------

cmd_lsblk:
    clc
    jmp bios.do_lsblk

//----------------------------------------------------
// cmd_dump : affiche les variables
//----------------------------------------------------

cmd_dump:
{
    lda type_dump
    beq dump_env

    call_bios(bios.count_vars, internal_commands)
    sta parcours_variables
    cmp #0
    bne dump_cmd
    jmp fin_dump

dump_cmd:
    stw_r(0, internal_commands)
    jmp boucle_dump

dump_env:
    call_bios(bios.count_vars, var_names)
    sta parcours_variables
    cmp #0
    beq fin_dump

    stw_r(0, var_names)

boucle_dump:

    // r2 = partie nom
    str_r(2, 0)
    
    // r0 += longueur + 1 = adresse valeur
    ldy #0
    clc
    lda (zr0),y
    clc
    adc #1
    add_r(0)

    // lecture adresse valeur -> dans r1
    lda (zr0),y
    sta zr1l
    iny
    lda (zr0),y
    sta zr1h

    // et ajout 2 pour positionner r0 sur le suivant
    clc
    lda #2
    add_r(0)

    push_r(0)

    // si type de dump pas environnement, n'affiche pas
    // les valeurs des variables
    lda type_dump
    beq type_env
    stw_r(0, txt_autre)
    jmp suite_env

type_env:
    stw_r(0, txt_env)

suite_env:
    str_r(3, 1)
    jsr bios.do_pprintnl

    pop_r(0)

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
// cmd_set : affecte une valeur à une variable
//----------------------------------------------------

cmd_set:
{
    needs_parameters(1)
    ldx #1
    call_bios(bios.list_get, parameters.list)
    lda #'='
    jsr extract_cmd
    jsr bios.do_setvar
    clc
    rts
}

//----------------------------------------------------
// cmd_status : current disk status
//----------------------------------------------------

cmd_status:
{
    sec
    bios(bios.get_device_status)
    rts
}

//----------------------------------------------------
// cmd_device : change device
//----------------------------------------------------

cmd_device:
{
    needs_parameters(1)

    ldx #1
    call_bios(bios.list_get, parameters.list)

change:
    str_r(1, 0)
    lda bios.device
    sta prev_device

    stw_r(0, device_var)
    jsr bios.do_setvar
    jsr bios.do_set_device
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
// cmd_cmd : envoie une commande
// r1 : paramètre
//----------------------------------------------------

cmd_cmd:
{
    needs_parameters(1)
    ldx #1
    call_bios(bios.list_get, parameters.list)
    ldx #15
    sec
    bios(bios.file_open)
    bcs error
close_file:
    ldx #15
    bios(bios.file_close)
    clc
    rts
error:
    jsr close_file
    sec
    rts
}

//----------------------------------------------------
// cmd_cp : copie
//----------------------------------------------------

cmd_cp:
{
    needs_parameters(2)
    lda bios.device
    sta bios.save_device

    ldx #1
    call_bios(bios.list_get, parameters.list)
    stw_r(1, work_path)
    bios(bios.prep_path)
    ldx #2
    call_bios(bios.list_get, parameters.list)
    stw_r(1, work_path2)
    bios(bios.prep_path)

    stw_r(1, work_path)
    call_bios(bios.build_path, work_buffer)

    stw_r(1, work_path2)
    call_bios(bios.build_path, work_buffer2)
    stw_r(0, work_buffer2)
    stw_r(1, write_str)
    bios(bios.add_str)

    // open fichier en sortie
    
    call_bios(bios.set_device_from_path, work_path2)
    sec
    ldx #3
    call_bios(bios.file_open, work_buffer2)
    bcs erreur_open_2

    // open fichier en entrée

    call_bios(bios.set_device_from_path, work_path)
    clc
    ldx #2
    call_bios(bios.file_open, work_buffer)
    bcs erreur_open_1

    // copie fichier 1 vers 2

copie_fichier:
    ldx #2
    call_bios(bios.read_buffer, work_buffer)
    lda #0
    rol
    sta copie_finie
    ldx #3
    call_bios(bios.write_buffer, work_buffer)
    lda copie_finie
    beq copie_fichier

    jsr close_files

    ldx bios.save_device
    jsr bios.do_set_device_from_int
    
    clc
    rts

copie_finie:
    .byte 0

close_files:
    ldx #3
    bios(bios.file_close)
    ldx #2
    bios(bios.file_close)
    rts

erreur_open_2:
    ldx #3
    bios(bios.file_close)
    call_bios(bios.error, msg_error.write_error)
    jmp close1
erreur_open_1:
    call_bios(bios.error, msg_error.read_error)
close1:
    ldx #2
    bios(bios.file_close)
    sec
    rts

write_str:
    pstring(",P,W")
}

//----------------------------------------------------
// needs_parameter : si pas de paramètres (C=0),
// affiche erreur et dépile le retour pour ne pas
// executer la commande
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
    call_bios(bios.error, msg_error.needs_parameters)
    pla
    pla
    rts
}

//----------------------------------------------------
// check_options : vérifie les options données dans
// les paramètres
// entrée = lecture parameters, r1 = valid options
// sortie : c=0 OK, c=1 et A=0 pas d'options
// c=1 et A=1 : option invalide
//----------------------------------------------------

check_options:
{
    lda parameters.options
    beq pas_options
    stw_r(0, parameters.options)
    jsr do_get_options
    bcc options_ok
    cmp #0
    beq pas_options

    call_bios(bios.error, msg_error.invalid_option)
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
// boucle_params : execute tant qu'il y a des 
// paramètres dans la liste
// entrée r0 adresse sous-routine
// dans la boucle r0 = paramètre transmis
//----------------------------------------------------

boucle_params:
{
    lda zr0l
    sta jump
    lda zr0h
    sta jump+1
    // boucle si il y a plusieurs noms de fichiers
    ldx #1
    stx pos_cat
encore_cat:
    call_bios(bios.list_get, parameters.list)
    jsr jump:$fce2
    bcs fin_cat

    inc pos_cat
    ldx pos_cat
    cpx parameters.list
    bne encore_cat
    clc

    // fin avec erreur
fin_cat:
    rts

pos_cat:
    .byte 0
}

//----------------------------------------------------
// cmd_cat : affichage fichier
//----------------------------------------------------

cmd_cat:
{
    needs_parameters(1)
    stw_r(1, options_cat)
    jsr check_options
    sta options

    // sauve device courant pour référence aux
    // paths sans device d'indiqué
    lda bios.device
    sta bios.save_device

    stw_r(0, do_cat)
    jmp boucle_params

options:
    .byte 0
options_cat:
    pstring("BEN")
}

// do_cat : effectue la commande CAT unitaire, nom en R0

do_cat:
{
    .label OPT_B=1
    .label OPT_E=2
    .label OPT_N=4

    // initialisation
    ldy #0
    sty num_lignes
    sty num_lignes+1

    // passe le nom en r0 par un objet ppath
    // mise à jour device + nom construit dans r0
    stw_r(1, work_path)
    bios(bios.prep_path)
    call_bios(bios.set_device_from_path, work_path)
    stw_r(1, work_path)
    call_bios(bios.build_path, work_buffer)

    call_bios(bios.print_path, work_path)

    // ouverture en lecture, nom dans r0
    ldx #2
    clc
    jsr bios.do_file_open
    bcs error

    // passe le canal en lecture
    ldx #2
    jsr CHKIN

    // test pour file not found
    jsr READST
    bne end

boucle_cat:
    jsr $FFE1      // RUN/STOP pressed?
    beq end

    jsr bios.do_file_readline
    bcs derniere_ligne
    jsr affiche_ligne
    jmp boucle_cat

affiche_ligne:
    jsr option_numero
    call_bios(bios.pprint, work_buffer)

    // option E = affiche $ en fin de ligne
    lda cmd_cat.options
    and #OPT_E
    beq pas_option_e
    lda #'$'
    jsr CHROUT

pas_option_e:
    lda #13
    jmp CHROUT

derniere_ligne:
    jsr affiche_ligne    
    lda #0
end:
    and #2
    bne error
    ldx #2
    jsr bios.do_file_close
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    clc
    rts

error:
    ldx #2
    jsr bios.do_file_close
    ldx bios.save_device
    jsr bios.do_set_device_from_int
    call_bios(bios.error, msg_error.file_not_found)
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
    inc num_lignes
    bne pas_inc
    inc num_lignes+1
pas_inc:
    lda num_lignes
    sta zr0l
    lda num_lignes+1
    sta zr0h
    lda #%10011111
    jsr bios.do_print_int
    lda #32
    jsr CHROUT
pas_numero:
    rts


num_lignes:
    .word 0
}

//----------------------------------------------------
// cmd_do_cmd : envoi de commande quelconque
// r1 : préfixe commande à envoyer
// r0 : path à utiliser
//----------------------------------------------------

cmd_do_cmd:
{
    // analyse du path en R0, retour = work_path
    str_r(5, 1)
    stw_r(1, work_path)
    bios(bios.prep_path)
    //jsr bios.do_pprinthex8a
    lda work_path
    and #PPATH.WITH_DEVICE
    beq pas_de_device

    // change de device si device dans le path
    // et contrôle existence device
    ldx work_path+1
    lda bios.devices,x
    bne pas_erreur_device
    call_bios(bios.error, msg_error.device_not_present)
    sec
    rts

pas_erreur_device:
    txa
    jsr bios.do_set_device_from_int

pas_de_device:
    // construction du path cible dans work_buffer

    call_bios(bios.build_path, work_buffer)

    // commande à envoyer = r5 + work_buffer

    ldy #0
    sty work_buffer2
    push_r(0)
    stw_r(0, work_buffer2)
    str_r(1, 5)
    bios(bios.add_str)
    pop_r(1)
    stw_r(0, work_buffer2)
    bios(bios.add_str)

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
    bios(bios.get_device_status)

    ldx #15
    jsr bios.do_file_close
    clc
    rts

error:
    call_bios(bios.pprintnl, erreur)
    sec
    rts
erreur:
    pstring("ERREUR")

}

//---------------------------------------------------------------
// get_options : lecture des options présentes en r0 si r0
// contient des options (commence par "-"), 
// r1 = liste des options
// retour : si ok C=0, A = options, sinon C=1 et A = 0
//---------------------------------------------------------------

do_get_options:
{
    // utilise r2 au lieu de r0 pour conserver r0
    str_r(2, 0)
    ldy #0
    getbyte_r(2)
    beq pas_options

    // si options présentes = il y en a lgr - 1
    tay
    dey
    sty nb_options

    // vérifie la syntaxe
    ldy #0
    getbyte_r(2)
    cmp #'-'
    bne pas_options

    lda #0
    sta options
    // parcours de r0, recherche si option dans r1
    // si pas dans r1 = erreur, si dans r1 ajoute option

    // nb_options_total = nb d'options dans la liste des options
    // zr1 pointe sur le débute de la liste des options
    ldy #0
    getbyte_r(1)
    sta nb_options_total
    
.print "nb_options=$"+toHexString(nb_options)
.print "nb_options_total=$"+toHexString(nb_options_total)
.print "options=$"+toHexString(options)
    // teste chaque option de zr2 : si trouvé ajoute aux
    // options, si non trouvé = erreur d'option
next_option:
    ldy #0
    getbyte_r(2)

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
    jsr set_bit
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
}

// positionne le bit Y à 1 dans A
set_bit:
{
    ora bit_list,y
    rts
bit_list:
    .byte 1,2,4,8,16,32,64,128
}


//----------------------------------------------------
// cmd_mkdir : crée un répertoire
//----------------------------------------------------

cmd_mkdir:
{
    needs_parameters(1)
    ldx #1
    call_bios(bios.list_get, parameters.list)
    stw_r(1, commande)
    jmp cmd_do_cmd

commande:
    pstring("MD:")
}

//----------------------------------------------------
// cmd_rmdir : supprime un répertoire
//----------------------------------------------------

cmd_rmdir:
{
    needs_parameters(1)
    ldx #1
    call_bios(bios.list_get, parameters.list)
    stw_r(1, commande)
    jmp cmd_do_cmd

commande:
    pstring("RD:")
}

//----------------------------------------------------
// cmd_rm : supprime un ou plusieurs fichier
//----------------------------------------------------

cmd_rm:
{
    needs_parameters(1)
    stw_r(0, do_rm)
    jmp boucle_params

do_rm:
    stw_r(1, commande)
    jmp cmd_do_cmd

commande:
    pstring("S:")
}

//----------------------------------------------------
// cmd_cd : change de répertoire
//----------------------------------------------------

cmd_cd:
{
    needs_parameters(1)
    ldx #1
    call_bios(bios.list_get, parameters.list)
    stw_r(1, commande)
    jmp cmd_do_cmd

commande:
    pstring("CD")
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
// si C=1 en entrée, vérifie paramètres en r1
// 
// options :
//
// 0 : L = liste en format long
//----------------------------------------------------

cmd_ll:
{
    lda #1
    jmp cmd_ls.options_ok
}

cmd_ls:
{
    .label FT_DISKNAME=1
    .label FT_FREE=2
    .label FT_SIZE=4
    
    // vérifie la présence d'options ou non

    ldy #0
    sty options
    lda parameters.options
    beq pas_de_parametres

    stw_r(0, parameters.options)
    stw_r(1, options_ls)
    
    jsr do_get_options
    bcc options_ok
    sec
    rts
filtre:
    pstring("0123456789ABCDEF")
.print "filtre=$"+toHexString(filtre)
options_ok:
    sta options

pas_de_parametres:

    lda #0
    sta filtre
    lda parameters.list
    cmp #2
    bne pas_filtre

    // si filtre en paramètre, copie le 
    ldx #1
    call_bios(bios.list_get, parameters.list)
    stw_r(1, filtre)
    bios(bios.copy_str)

pas_filtre:
    lda #0
    sta format
    lda options
    cmp #1
    bne pas_option_L

    lda #FT_DISKNAME+FT_FREE+FT_SIZE
    sta format
pas_option_L:
    lda #0
    sta colonnes
    sta tosize40

    // ouverture $
    ldx #2
    clc
    call_bios(bios.file_open, dirname)
    ldx #2
    jsr CHKIN

    // lecture nom du disque / répertoire
do_dir:
    jsr do_read_dir_entry

    lda format
    and #FT_DISKNAME
    beq not_ft_diskname
    call_bios(bios.pprint, dir_entry.filename)
    lda #32
    jsr CHROUT
    call_bios(bios.pprintnl, dir_entry.type)

not_ft_diskname:
next:

    jsr do_read_dir_entry
    bcc no_exit
    jmp exit

no_exit:
    bne pas_blocs

    // affichage blocks free
blocs:
    lda format
    and #FT_FREE
    beq pas_aff_blocs_free

    lda dir_entry.size
    sta zr0l
    lda dir_entry.size+1
    sta zr0h
    lda #%11111111
    jsr bios.do_print_int
    call_bios(bios.pprintnl, blocksfree)

pas_aff_blocs_free:
    jmp next

    // affichage nom fichier
pas_blocs:

    lda format
    and #FT_SIZE
    beq pas_ft_size

    // type fichier
    lda (dir_entry.type)+1
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

    //BRK//*
    stw_r(1, dir_entry.filename)
    call_bios(bios.filter, filtre)
    bcs filtre_ko

    call_bios(bios.pprint, dir_entry.type)

    // taille fichier
    lda dir_entry.size
    sta zr0l
    lda dir_entry.size+1
    sta zr0h
    lda #%11111111
    jsr bios.do_print_int
    lda #32
    jsr CHROUT
pas_ft_size:

    lda format
    and #FT_SIZE
    beq pas_ft_size_name

    call_bios(bios.pprintnl, dir_entry.filename)
    lda #5
    sta 646
filtre_ko:
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
    jsr $FFE1      // RUN/STOP pressed?
    beq error      // no RUN/STOP -> continue
    jmp next
error:
    // A contains BASIC error code

    // most likely error:
    // A = $05 (DEVICE NOT PRESENT)
exit:
    lda colonnes
    bne pas_impair
    lda #13
    jsr CHROUT
pas_impair:
    lda #$02      // filenumber 2
    jsr $FFC3     // call CLOSE

    jsr $FFCC     // call CLRCHN
    rts

    // print_name_no_size : affichage nom sans taille
print_name_no_size:
    lda dir_entry.filename
    sta tosize40

    //stw_r(1, dir_entry.filename)
    //call_bios(bios.filter, filtre)
    //bcs no_print2
    call_bios(bios.pprint, dir_entry.filename)
//no_print2:

    lda colonnes
    beq size40

    lda #1
    sta colonnes
    lda #$0d
    jmp CHROUT

dirname:
    pstring("$")     // filename used to access directory
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
    pstring("L")
}

//----------------------------------------------------
// dir_entry : stockage d'une entrée de répertoire
//----------------------------------------------------

dir_entry:
{
size:
    .word 0
filename:
    pstring("0123456789ABCDEF")
type:
    pstring("*DIR<")
}

//----------------------------------------------------
// read_dir_entry : lecture entrée répertoire
//----------------------------------------------------

do_read_dir_entry:
{
    jsr READST
    beq lecture_ok
    sec
    rts
lecture_ok:
    // lecture 32 octets = 1 entrée de répertoire
    ldy #0
lecture_buffer:
    jsr CHRIN
    sta buffer_entry,y
    iny
    cpy #32
    bne lecture_buffer

    // update size
    lda buffer_entry+2
    sta dir_entry.size
    lda buffer_entry+3
    sta dir_entry.size+1

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
    sta dir_entry.filename+1,x
    inx
    bne suite_update

    // si guill = 2 : copie dans type
    // sauf si espace ou 0
apres_nom:
    lda buffer_entry,y
    beq suite_update
    cmp #32
    beq suite_update
    sta dir_entry.type+1,x
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
    stx dir_entry.filename
    ldx #0

    // suite update_nom
suite_update:
    iny
    cpy #32
    bne update_nom
    stx dir_entry.type

    lda status_guillemets
    clc
    rts

status_guillemets:
    .byte 0
buffer_entry:
    .fill 32,0
msg_taille:
    pstring("%R1 ")
}

.print "buffer_entry=$"+toHexString(do_read_dir_entry.buffer_entry)
.print "dir_entry=$"+toHexString(dir_entry)

//----------------------------------------------------
// toplevel test
//----------------------------------------------------

* = * "toplevel"

.print "history_list=$"+toHexString(history_list)

//------------------------------------------------------------
// check_history : si on dépasse le max historique 
// on supprime 1 enreg
//------------------------------------------------------------

check_history:
{
    stw_r(0, history_list)
    ldy #0
    lda (zr0),y
    cmp max_history
    beq pas_max
    bmi pas_max

    dec nb_history
    ldx #0
    call_bios(bios.list_rm, history_list)

pas_max:
    rts
}

//------------------------------------------------------------
// add_history :
// ajoute une copie à l'historique, sauf si c'est history 
// ou si la commande est vide
//------------------------------------------------------------

add_history:
{
    ldy #0
    lda (zr0),y
    beq pas_copie_history
    stw_r(1, history_kw)
    jsr bios.compare_str
    bcs pas_copie_history

    str_r(1, 0)
    call_bios(bios.list_add, history_list)
    inc nb_history

pas_copie_history:
    rts
}

toplevel:

    stw_r(0, test1)
    stw_r(1, work_path)
    clc
    jsr bios.do_prep_path2
    call_bios(bios.print_path, work_path)
loop:
    inc $d020
    jmp loop

test1:
    //pstring("8:/PATH")
    //pstring("FICHIER.PRG")
    //pstring("10:/CHEMIN/FICHIER.PRG")
    pstring("9:17/PATH/PATH2/FILE")
    //pstring("/PATH")
    //pstring("/")
    jmp toplevel2

toplevel2:
    // affiche le prompt
    stw_r(0, varprompt)
    jsr bios.do_getvar
    str_r(0, 1)
    jsr bios.do_pprint

    // si on dépasse le max historique : supprime 1 enreg
    jsr check_history

    // lecture de la commande, retour en r0 = input_buffer
    jsr bios.do_input
    
    // ajout à l'historique
    jsr add_history

    // découpage des paramètres
    
    stw_r(0, input_buffer)
    jsr do_get_params
    //call_bios(bios.list_print, parameters.list)

    // pas de commande = boucle
    lda parameters.list
    beq toplevel2

    ldx #0
    call_bios(bios.list_get, parameters.list)
    jsr bios.lookup_cmd
    bcc non_trouve
    // exécute la commande
    jsr command_execute
    jmp toplevel2

    // commande non trouvée en interne, essaye en externe
non_trouve:
    jsr bios.do_file_load

    //call_bios(bios.pprintnl, msg_non_trouve)

    // et boucle sur le toplevel
    jmp toplevel2

command_execute:
{
    lda zr1l
    sta jmp_cmd
    lda zr1h
    sta jmp_cmd+1
    jmp jmp_cmd:$fce2
}

msg_non_trouve:
    pstring("COMMANDE NON TROUVEE")
msg_trouve:
    pstring("COMMANDE OK")

nb_history:
    .byte 0
max_history:
    .byte 5

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
// get_params : découpage commande /  paramètres / options
// entrée en R0 = liste des paramètres
// sortie dans parameters : options et liste commande / params
//---------------------------------------------------------------

do_get_params:
{
    // travaille avec r4 pour la lecture
    str_r(4, 0)
    // raz options (positions 2 à 9, conserve lgr et -)
    stw_r(1, parameters.options)
    
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
    
    stw_r(1, parameters.data)
    call_bios(bios.list_reset, parameters.list)

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
    // si options, lecture des options, 
    // si plusieurs fois présent
    // alors HS, sinon recopie dans parameters.options
    //--------------------------------------------------------

    stw_r(1, parameters.options)
    jsr process_traite_options

    //-- test de la suite de la chaine, si non vide,
    //-- si vide : fin
teste_suite_chaine:
    lda lgr_entree
    bne lecture_chaine
    jmp fini

    //--------------------------------------------------------
    //-- GUILLEMETS ----
    // process chaine separateur guillemets
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
    //-- ESPACE ----
    // séparateur espace
    // = idem guillemets mais séparateur espace pour fin
    //--------------------------------------------------------

pas_guillemets:
    cmp #32
    bne pas_espace

    sta separateur_test
    jsr process_guillemets
    jmp teste_suite_chaine

    //--------------------------------------------------------
    //-- AUTRES ----
    // pas espace : on est directement sur une chaine, lis 
    // et stocke la suite
    //--------------------------------------------------------

pas_espace:

    lda #32
    sta separateur_test
    inc lgr_entree
    dec_r(4)
    jsr process_guillemets
    jmp teste_suite_chaine

    //-------------------------------------------------------------
    // process_guillemets
    //-------------------------------------------------------------

process_guillemets:
    
    // on va recopier le paramètre dans work_buffer
    stw_r(5, work_buffer)

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
    stw_r(1, work_buffer2)
    lda no_eval
    beq do_eval
    stw_r(1, work_buffer)
    jmp add_to_list
do_eval:
    call_bios(bios.eval_str, work_buffer)
add_to_list:
    call_bios(bios.list_add, parameters.list)
    rts

    //-------------------------------------------------------------
    // pb options : erreur
    //-------------------------------------------------------------

pb_options:
    call_bios(bios.error, msg_error.invalid_parameters)
    rts

    //-------------------------------------------------------------
    // process_traite_options : lecture et copie des options
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
// cmd_history : affiche l'historique des commandes
//---------------------------------------------------------------

cmd_history:
{
    call_bios(bios.list_print, history_list)
    clc
    rts
}

//---------------------------------------------------------------
// cmd_help : affiche la liste des commandes internes
//---------------------------------------------------------------

cmd_help:
{
    lda parameters.list
    cmp #1
    beq no_params
    ldx #1
    call_bios(bios.list_get, parameters.list)
    str_r(5, 0)
    stw_r(1, work_buffer)
    call_bios(bios.eval_str, help_location)
    str_r(0, 1)
    lda bios.device
    sta bios.save_device
    lda #0
    sta cmd_cat.options
    jsr do_cat
    ldx bios.save_device
    jsr bios.do_set_device_from_int

    clc
    rts

no_params:
    lda #1
    sta cmd_dump.type_dump
    jmp cmd_dump

help_location:
    pstring("%VCONFIG%%P5.HLP")
}

//---------------------------------------------------------------
// cmd_quit : commande quit, quitte le shell
//---------------------------------------------------------------

cmd_quit:
    pla
    pla
    lda #MEMSTD
    sta $01
    rts

presence_separateur:
    .byte 0
varprompt:
    pstring("PROMPT")

//----------------------------------------------------
// cmd_mem : affiche un contenu mémoire
// paramètres utilisés : 1er = adresse début (hex)
// 2ème si présent = adresse fin, sinon affiche 8
// octets max
//----------------------------------------------------

cmd_mem:
{
    needs_parameters(1)
    lda parameters.list
    cmp #3
    bne juste_8

    ldx #2
    call_bios(bios.list_get, parameters.list)
    bios(bios.hex2int)
    lda zr0l
    sta stop_address
    lda zr0h
    sta stop_address+1
    ldx #1
    call_bios(bios.list_get, parameters.list)
    bios(bios.hex2int)
    lda stop_address
    jmp boucle_hex

juste_8:
    ldx #1
    call_bios(bios.list_get, parameters.list)
    bios(bios.hex2int)
    push_r(0)
    add_r(8)
    lda zr0l
    sta stop_address
    lda zr0h
    sta stop_address+1
    pop_r(0)

boucle_hex:

    lda zr0h
    jsr bios.do_pprinthex8a
    lda zr0l
    jsr bios.do_pprinthex8a

    lda #0
    sta nb_bytes
aff_mem:
    lda #32
    jsr CHROUT
    ldy #0
    getbyte_r(0)
    ldx nb_bytes
    sta bytes,x

    jsr bios.do_pprinthex8a
    inc nb_bytes
    lda nb_bytes
    cmp #8
    bne aff_mem
    lda #32
    jsr CHROUT
    ldx #0
aff_txt:
    lda bytes,x
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
    inx
    cpx #8
    bne aff_txt

    lda #13
    jsr CHROUT
    jsr $FFE1      // RUN/STOP pressed?
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
    .fill 8,0
adr_hex:
    pstring(":%R1")
}




} // namespace shell

//---------------------------------------------------------------
// liste des commandes internes du shell
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
    pstring("KEYTEST")
    .word shell.cmd_keytest
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
    pstring("LL")
    .word shell.cmd_ll
    pstring("CLEAR")
    .word shell.cmd_clear

    //-- aliases
    pstring("$")
    .word shell.cmd_ls
    .byte 1, 64 // @
    .word shell.cmd_status

history_kw:
    pstring("HISTORY")
    .word shell.cmd_history
    .byte 0

//===============================================================
// BIOS workspace data
//===============================================================

//---------------------------------------------------------------
// espace de nom et valeurs pour les variables
//---------------------------------------------------------------

    .align $100
* = * "variable names space"
var_names:
    pstring("PROMPT")
    .word prompt_value
    pstring("PATH")
    .word path_value
    pstring("DEVICE")
    .word device_value
    pstring("CONFIG")
    .word config_value

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
    pstring("10:CONFIG/")

values_end:

//---------------------------------------------------------------
// buffers de saisie et de travail
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

work_path:
    ppath(128)
work_path2:
    ppath(128)

work_name:
    .fill $40,0
work_pprint:
    .fill $80,0

.print "work_path=$"+toHexString(work_path)
.print "work_path.path=$"+toHexString(work_path.path)
.print "work_path.filename=$"+toHexString(work_path.filename)
.print "work_path2=$"+toHexString(work_path2)
.print "work_name=$"+toHexString(work_name)

//---------------------------------------------------------------
// messages d'erreur
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
invalid_option:
invalid_parameters:
    pstring("INVALID PARAMETERS")
}