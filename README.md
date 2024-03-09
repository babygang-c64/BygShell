# BygShell
Shell like commands for the C64

## Shell commands

### Script and external commands execution

When a command is not found in the internal commands list then a lookup is done on disk in the current directory.
If the command name is a script name (ends with .sh) then all commands from the script are read and executed.
If the command name is a binary then it is launched (for now starting at $080d) Must have a basic header with a SYS.

### Internal commands

## Data structures

### 16 bit registers

8 x 16bit registers (R0 to R7) are stored on ZP starting at address $39
They are referenced with the following pre-defined labels :
zr0 to zr1 : base address of registers
zr0l to zr1l : lower bytes of registers
zr0h to zr1h : higher bytes of registers

### macro instructions with pre-processor for 16 bit registers

**MOV**
```
mov r<n>, r<m>      : register n = register m
mov r<n>, #<addr>   : register n = address
mov r<n>, <addr>    : register n = content at address
mov a, (r<n>)       : a = byte at register n address
mov a, (r<n>++)     : a = byte at register n address, increment register
mov (r<n>), a       : store a at register n address
mov (r<n>++),a      : store a at register n address, increment register
mov (r<n>), r<m>    : store register m at address in register n
mov r<n>, (r<m>)    : store value at address in register m
mov <addr>, <addr2> : copy word at addr2 to addr
mov <addr>, #<val>  : copy value to addr
```

Warning : indirect MOV operations rely on Y beeing set to 0, if not then Y will be added to address

**ADD**
```
add r<n>, #<imm>    : add 8bit or 16bit immediate value to register n
add r<n>, a         : add a to register n
add <addr>, a       : add a to value at address <addr>
todo : add <addr>, #<imm> and add <addr>, <addr2>
```
**INC, DEC**
```
inc r<n> : increment register
dec r<n> : decrement register
```
**SWAP**
```
swap r<n>, r<m> : swap registers
```
**STC / LDC**
```
stc <address> : store carry as 1 or 0 to address
ldc <address> : get carry from 1 or 0 at address
```
**JNE / JEQ / JCC / JCS**
long branches
**SWI**
```
swi <bios_function>                    : calls bios function
swi <bios_function>, <addr> [,<addr2>] : calls bios function with r0 = addr, r1 = addr2
```
### pStrings

Pstrings are Pascal like strings consisting of a length byte followed by max 255 characters

related macro :

**pstring("STRING VALUE")**

Initializes a pstring value with length preset according to the "STRING VALUE" length
    
### Lists

A list data structure contains multiple pStrings

### system variables

A pool of <name> / <pstring value> variables is maintained.
Some variables are pre-allocated

**var_set** : 
    Variable with name in R0 = pstring R1

**var_get** : 
    R1 = value of variable with name in R0 
    On exit : C=1 variable found, C=0 variable not found

**var_del** : 
    Delete variable #A

### Directory routines

### Helper BIOS functions

**is_digit**

C=1 if A is a digit

**set_bit**

Y = bit to set in A

### List of BIOS entry points

## System

**reset**
    Restart the shell, cold start

**file_load**
    Load a binary file for running, checks the presence of a BASIC stubs with a SYS instruction and starts code at $080D (2061)

**error**
    Print the error message in R0

## Screen & Keyboard I/O

**pprint**
    Print a pString, after expansion of contents

**pprintnl**
    Same as pprint, with a new line added

(**print_int** to add to BIOS)

**input**

**pprinthex**

**pprinthex8**

**print_path**

## Conversions

**hex2int**

(**int2str** to add to BIOS)

(**str2int** to add to BIOS)

## Variables

**var_set** : 
    Variable with name in R0 = pstring R1

**var_get** : 
    R1 = value of variable with name in R0 
    On exit : C=1 variable found, C=0 variable not found

**var_del** : 
    Delete variable #A

**var_count**
    Count number of available variables or internal commands.
    R0 = source variables space
    On exit : A = number of variables

    shell.var_names = variables space
    shell.internal_commands = internal commands space

## Lists

**list_add**

**list_get**

**list_del**

**list_print**

**list_size**

**list_reset**

## Disk I/O

**set_device**

**prep_path**

**build_path**
    Build a path pString from a ppath
    R1 = ppath source
    R0 = address of target pString
    C=0 adds : to filename, C=1 : no separator added
    On exit: r0 contains path:name

**lsblk**

**get_device_status**
    Get current device status
    C=1 prints result on screen, C=0 silent mode
    On exit : status code into R0, 2 positions
    C=0 if code 00, C=1 otherwise

**set_device_from_path**

## pStrings

**str_cat**
```
    pstring(r0) += pstring(r1)
```
**str_cpy**
```
    pstring(r1) = pstring(r0)
    return A = total copied bytes (R0 pstring length + 1)
```
**str_empty**
```
    Input R0 = pstring
    C(arry)=0 if string is empty (zero length or spaces)
    C=1 if string is not empty
```
**str_expand**
```
    pstring(r1) = expansed pstring(r0)
    expanses pstring(r0) according to the following modifiers :

        %% = %
        %R<n> = hex value of register R<n>
        %P<n> = pstring value at address of register R<n>
        %V<variable>% = pstring value stored for system variable with name <variable>
        %C<hexcolor> = insert character to change color to <hexcolor> (hex nibble)
                       R = reverse, N = normal, H = clear screen / home
        %H<hex> = insert character <hex>

    On exit : C=1 if error, C=0 if OK
```
**str_pat**
```
    Pattern filter apply r1 on r0
    Patterns can be ? or *
    On exit : C = 1 if filter matches
```
**str_cmp**
```
    Compare pstring(r0) and pstring(r1)
    On exit : C=1 if equals, C=0 otherwise
```
**str_chr**
```
    Find position of character X in pstring(r0)
    On exit : C=1 if found, Y = position
```
**str_rchr**
```
    Backwards str_chr
    On exit : C=1 if found, Y = position
```
**str_lstrip**
```
    Suppress spaces on left side of pstring(r0)
```
**str_len**
```
    Return length of pstring(r0) into A
    On exit : A = pstring length
```
**str_del**
```
    Remove Y characters of pstring r0, starting at X
```
**str_ins**
```
    Insert pstring(r1) at position X of pstring(r0)
    pstring(r0) string size should be big enough
```
**str_ncpy**
```
    pstring(r1) = left(pstring(r0), X)
```
**str_split**
```
    Split pstring(r0) with separator X
    On exit : C = 1 if split occurs, 
              A = number of items after split
```

## File

**file_open**
```
    R0 = filename to open, X = channel to use.
    C=0 open for reading, C=1 open for writing (applies a CHKIN / CHKOUT to channel)
    On exit : C=1 if open failed

    Open disk file for reading / writing.
    Secondary address will be X too, except for directory where it's forced to 0.
    For writing the filename should contain the file type and write indicator.
```
**file_close**
```
    X = channel to close
```
**file_readline**
```
```
**buffer_read**
```
    X = channel to read from, R0 = pString buffer, C=0 for normal reading or C=1 for line reading.
    The pString buffer should be allocated, the function will read at most the length indicated in the pString.
    Line reading stops when a $0A or $0D character is found.
    On exit C=1 if end of file or error

        ldx #2
        lda #8
        sta buffer_hexdump
        clc
        swi buffer_read, buffer_hexdump
```
**buffer_write**
```
```

## Directory

**directory_open**
```
    Open the directory

    Works on current device, resets the directory filters
    On exit : C=1 if error
```
**directory_set_filter**
```
    Filters directory entries

    R0 = pstring of filename filter
    X = bitmap of filetypes filter

    File types are in bios.directory namespace :

    bios.directory.TYPE_PRG     PRG program files
    bios.directory.TYPE_SEQ     SEQ files
    bios.directory.TYPE_USR     USR files
    bios.directory.TYPE_REL     REL files
    bios.directory.TYPE_DIR     DIR directory
    bios.directory.TYPE_ERR     ERR file in error status
    bios.directory.TYPE_FILES   PRG / USR / SEQ files

    Example :

        swi directory_open
        ldx #bios.directory.TYPE_PRG
        swi directory_set_filter, filtre_dir
        ...
    filtre_dir:
        pstring("*.TXT")
```
**directory_get_entry**
```
    Retrieves next directory entry

    Populates the bios.directory.entry data structure

    On exit :
        A   : entry type
            $00 = disk name
            $80 = filtered entry

        C=1 : end of directory

    Example :

        dir_next:
            swi directory_get_entry
            bcs dir_end
            beq dir_end
            bmi dir_next

            swi pprintnl, bios.directory.entry.filename
            jmp dir_next

        dir_end:
            swi directory_close
```
**directory_close**
```
    Close the directory
```
**directory.entry data structure**
```
    Available at bios.directory.entry

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
```
**is_filter**
```
    Check if pString in R0 contains wildcards (* and ?)
    C=1 if wildcards were found
```

# Internal commands

**QUIT**
```
Warm reset to BASIC startup.
Restart shell with reset, sys 64738 or run / stop + restore
```
**SET**

**ECHO**

**ENV**

**LS**

**ST**
```
Print status of current disk device
```
**SD**
```
SD <device>
Change current disk device (if device is available in scanned devices)
To rescan devices use LSBLK
"DEVICE" variable is set to current device
```
**HELP**

**LSD**

**KEYTEST**

**CD**

**CMD**

**CAT**
```
cat <file> [<file> ...]

print file(s) contents to screen
    options : 
    N = numbers all lines
    E = print $ at EOL
    B = numbers all non empty lines
    P = paginates output
    H = hexdump
    A = read C64 binary start address for hexdump
```
**MKDIR**
```
mkdir <directory>
create subdirectory
```
**RMDIR**
```
rmdir <directory>
remove subdirectory
```
**RM**
```
rm <file>
erase file
```
**MEM**
```
mem <start-address> [<end-address>]
Dump memory to screen
```
**CP**

**CLEAR**
```
Clear screen
```
**SAVEENV**

**INPUT**

**FILTER**

**HISTORY**

# Internal commands aliases

**$**
```
    Alias for LS
```
**@**
```
    Alias for ST
```
**LL**
```
    Alias for LS -L
```
**MORE**
```
    Alias for CAT -P
```
