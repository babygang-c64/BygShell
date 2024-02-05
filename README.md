# BygShell
Shell like commands for the C64

## Data structures

### 16 bit registrers

8 x 16bit registers (R0 to R7) are reserved on ZP starting at address $39
They are referenced with the following pre-defined labels :
zr0 to zr1 : base address of registers
zr0l to zr1l : lower bytes of registers
zr0h to zr1h : higher bytes of registers

### pStrings

Pstrings are Pascal like strings consisting of a length byte followed by max
254 characters

related macros :

**pstring("STRING VALUE")**

Initializes a pstring value with length preset according to the "STRING VALUE" length

related BIOS operations : 

**str_empty** : input R0 = pstring
    C(arry)=0 if string is empty (zero length or spaces)
    C=1 if string is not empty

**add_str** : pstring(r0) += pstring(r1)

**copy_str** : pstring(r1) = pstring(r0)
    return A = total copied bytes (R0 pstring length + 1)

**eval_str** : pstring(r1) = expansed pstring(r0)
    expanses pstring(r0) according to the following modifiers :

        %% = %
        %R<n> = hex value of register R<n>
        %P<n> = pstring value at address of register R<n>
        %V<variable>% = pstring value stored for system variable with name <variable>
    
    On exit : C=1 if error, C=0 if OK

**compare_str** : compare pstring(r0) and pstring(r1)

    On exit : C=1 if equals, C=0 otherwise

### system variables

A pool of <name> / <pstring value> variables is maintained.

related BIOS operations :

**setvar** : variable with name in R0 = pstring R1
**getvar** : R1 = value of variable with name in R0 

    On exit : C=1 variable found, C=0 variable not found

**lookup_var** : lookup variable #,

    On exit : A = variable #, C=1, R1=value if found, C=0 otherwise

**rmvar** : deletes variable #A

Helper BIOS functions :

**is_digit**

