# BygShell
Shell like commands for the C64

## Data structures

### 16 bit registers

8 x 16bit registers (R0 to R7) are stored on ZP starting at address $39
They are referenced with the following pre-defined labels :
zr0 to zr1 : base address of registers
zr0l to zr1l : lower bytes of registers
zr0h to zr1h : higher bytes of registers

### macro instructions with pre-processor for 16 bit registers

**Mov**
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

**Add**
```
add r<n>, #<imm>    : add 8bit or 16bit immediate value to register n
add r<n>, a         : add a to register n
add <addr>, a       : add a to value at address <addr>
todo : add <addr>, #<imm> and add <addr>, <addr2>
```
**Inc, Dec**
```
inc r<n> : increment register
dec r<n> : decrement register
```
**Swap**
```
swap r<n>, r<m> : swap registers
```
**Stc**
```
stc <address> : store carry as 1 or 0 to address
```
**Swi**
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

### system variables

A pool of <name> / <pstring value> variables is maintained.

related BIOS operations :

**var_set** : variable with name in R0 = pstring R1

**var_get** : R1 = value of variable with name in R0 

    On exit : C=1 variable found, C=0 variable not found

**var_del** : deletes variable #A

Helper BIOS functions :

**is_digit**

