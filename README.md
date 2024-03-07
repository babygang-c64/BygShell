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

related BIOS operations : 

**str_empty** : input R0 = pstring
    C(arry)=0 if string is empty (zero length or spaces)
    C=1 if string is not empty

**str_cat** : pstring(r0) += pstring(r1)

**str_cpy** : pstring(r1) = pstring(r0)
    return A = total copied bytes (R0 pstring length + 1)

**str_ncpy** : pstring(r1) = left(pstring(r0), X)

**str_expand** : pstring(r1) = expansed pstring(r0)
    expanses pstring(r0) according to the following modifiers :
```
        %% = %
        %R<n> = hex value of register R<n>
        %P<n> = pstring value at address of register R<n>
        %V<variable>% = pstring value stored for system variable with name <variable>
        %C<hexcolor> = insert character to change color to <hexcolor> (hex nibble)
```    
    On exit : C=1 if error, C=0 if OK

**str_cmp** : compare pstring(r0) and pstring(r1)

    On exit : C=1 if equals, C=0 otherwise

**str_del** : remove Y characters of pstring r0, starting at X

**str_ins** : insert pstring(r1) at position X of pstring(r0)

    pstring(r0) string size should be big enough

**str_chr** : find position of character X in pstring(r0)

    On exit : C=1 if found, Y = position

**str_rchr** : backwards str_chr

    On exit : C=1 if found, Y = position

**str_lstrip** : suppress spaces on left side of pstring(r0)

**str_len** : return length of pstring(r0) into A

    On exit : A = pstring length

**str_split** : split pstring(r0) with separator X

    On exit : C = 1 if split occurs, 
              A = number of items after split

**str_pat** : pattern filter apply r1 on r0

    On exit : C = 1 if filter matches

### system variables

A pool of <name> / <pstring value> variables is maintained.

related BIOS operations :

**var_set** : variable with name in R0 = pstring R1

**var_get** : R1 = value of variable with name in R0 

    On exit : C=1 variable found, C=0 variable not found

**var_del** : deletes variable #A

### Directory routines

**directory_open** : Open the directory

Works on current device, resets the directory filters
On exit : C=1 if error

**directory_set_filter** : Filters directory entries

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
```
    swi directory_open
    ldx #bios.directory.TYPE_PRG
    swi directory_set_filter, filtre_dir
    ...
filtre_dir:
    pstring("*.TXT")
```

**directory_get_entry** : Retrieves next directory entry

Populates the bios.directory.entry data structure

On exit :
    A   : entry type
        $00 = disk name
        $80 = filtered entry

    C=1 : end of directory

Example :

```
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
**directory_close** : Close the directory

**directory.entry data structure**

Available at bios.directory.entry
```
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
### Helper BIOS functions

**is_digit**

C=1 if A is a digit

**set_bit**

Y = bit to set in A
