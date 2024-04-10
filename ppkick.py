# ppkick : kickassembler pre-processor

import sys



def get_size(value):
    """
    get_size : get size of operand, 8 or 16 bits
    """

    size = 16
    if value[0] == '$':
        if len(value) <= 3:
            size = 8
    elif value.isdigit() and int(value) < 256:
            size = 8
    return size

def param_type(param):
    """
    param_type : get parameter type

    r = register
    w = word / address
    a = accumulator
    i = immediate value
    s = sub / indirect value
    """

    ptype = 'w'
    pval = param

    # immediate if starting with '#'
    if param[0] == '#':
        ptype = 'i'
        pval = param[1:]

    # accumulator if 'A'
    elif param.lower() == 'a':
        ptype = 'a'
        pval = ''

    # register if r<num> or rdest / rsrc
    elif param[0].lower()=='r' and (param[1:].isnumeric() or param.lower() in ['rdest', 'rsrc']):
        ptype = 'r'
        if param.lower() == 'rdest':
            pval = 'reg_zdest'
        elif param.lower() == 'rsrc':
            pval = 'reg_zsrc'
        else:
            pval = param[1:].lower()

    # sub / indirect if parenthesis
    elif param[0] == '(':
            ptype = 's'
            pval = param[2:-1].lower()
            if pval[-2:] == '++':
                ptype += 'i'
                pval = pval[:-2]
            if pval == 'rdest':
                pval = 'reg_zdest'
            if pval == 'rsrc':
                pval = 'reg_zsrc'

    return ptype, pval


if len(sys.argv) != 3:
    print('PPKICK v0.1\nBabygang extended 6510 instruction set pre-processor for kickass sources\n')
    print('ppkick <filein> <fileout>')
    quit()

filein = sys.argv[1]
fileout = sys.argv[2]

print('ppkick %s to %s' % (filein, fileout))

hin = open(filein, 'r')
hout = open(fileout, 'w')

for line in hin:
    wline = line.replace(',', ' , ')
    wline = wline.replace('  ', ' ')
    elems = wline.lstrip().rstrip().split(' ')
    if len(elems) > 0:
        instruction = elems[0].lower()
    else:
        instruction = ''

    #----------------------------------------------------------------------------
    # MOV instructions
    #
    # 
    #----------------------------------------------------------------------------

    if instruction == 'mov':
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])
        if ptype0 != 'a' and ptype1 != 'a':
            newline = 'st' + ptype1 + '_' + ptype0 + '(' + pval0 + ', ' + pval1 + ')'
        elif ptype0 == 'a' and ptype1 in ['s', 'si']:
            # mov a,(r0) / mov a,(r0++)
            newline = 'getbyte'
            if ptype1 == 'si':
                newline += '_r'
            newline += '(' + pval1 + ')'
        elif ptype1 == 'a' and ptype0 in ['s', 'si']:
            # mov (r0),a / mov (r0++),a
            newline = 'setbyte'
            if ptype0 == 'si':
                newline += '_r'
            newline += '(' + pval0 + ')'
        elif ptype1 == 'a' and ptype0 == 'r':
            # mov r0, a
            newline = 'sta_r(' + pval0 + ')'
        else:
            # mov r<num>, a -> 
            newline = 'st_' + ptype0 + ptype1 + '(' + pval0 + ', ' + pval1 + ')'
        #print('new [%s]' % newline)
        hout.write(newline + '\n')

    # MOVI
        
    elif instruction == 'movi':
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])

        if ptype0 == 's' and ptype1 == 'r':
            newline = 'stir_s(' + pval0 + ',' + pval1 + ')'
        else:
            input('movi error')
        hout.write(newline + '\n')

    # PUSH, POP, INC, DEC, INCW, DECW

    elif instruction in ['push', 'pop', 'inc', 'dec']:
        ptype0, pval0 = param_type(elems[1])
        if ptype0 == 'r':
            newline = instruction + '_r(' + pval0 + ')'
        else:
            newline = line
        hout.write(newline + '\n')
    elif instruction in ['incw', 'decw']:
        ptype0, pval0 = param_type(elems[1])
        if ptype0 == 'w':
            newline = instruction[0:3] + '_w(' + pval0 + ')'
        else:
            newline = line
        hout.write(newline + '\n')
    
    # SWN

    elif instruction == 'swn':
        hout.write('swn()\n')

    # ADD

    elif instruction == 'add':
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])
        if ptype0 == 'r' and ptype1 == 'a':
            newline = 'add_r(' + pval0 + ')'
            hout.write(newline + '\n')
        elif ptype0 == 'r' and ptype1=='i':
            lgr_value = get_size(pval1)
            if get_size(pval1) == 8:
                newline = 'addi_r(' + pval0 +', ' + pval1 + ')'
            else:
                newline = 'addw_r(' + pval0 +', ' + pval1 + ')'
            hout.write(newline + '\n')
        elif ptype0 == 'w' and ptype1 == 'a':
            newline = 'add8(' + pval0 + ')'
            hout.write(newline + '\n')
        elif ptype0 == 'w' and ptype1 == 'i':
            if get_size(pval1) == 8:            
                newline = 'addi_w(' + pval0 +', ' + pval1 + ')'
            else:
                newline = 'addw_w(' + pval0 +', ' + pval1 + ')'
            hout.write(newline + '\n')
        elif ptype0 == 'w' and ptype1 == 'w':
            newline = 'adda_w(' + pval0 +', ' + pval1 + ')'
            hout.write(newline + '\n')
        else:
            print(ptype0, pval0)
            print(ptype1, pval1)
            print('error', line)
            input('wait')

    # SWAP 

    elif instruction == 'swap':
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])
        if ptype0 == 'r' and ptype1 == 'r':
            newline = 'swapr_r(' + pval0 + ',' + pval1 + ')'
            hout.write(newline + '\n')
        else:
            print(ptype0, pval0)
            print(ptype1, pval1)
            print('error', line)
            input('wait')

    # LDC / STC / JNE / JEQ / JCC / JCS

    elif instruction in ['stc', 'ldc', 'jne', 'jeq', 'jcc', 'jcs']:
        newline = instruction + '(' + elems[1] + ')'
        hout.write(newline + '\n')

    # SWI
    
    elif instruction == 'swi':
        ptype0, pval0 = param_type(elems[1])
        if len(elems) == 2:
            newline = 'bios(bios.' + pval0 + ')'
        elif len(elems) == 4:
            ptype1, pval1 = param_type(elems[3])
            newline = 'call_bios(bios.' + pval0 + ', ' + pval1 + ')'
        elif len(elems) == 6:
            pval1 = elems[3]
            pval2 = elems[5]
            newline = 'call_bios2(bios.' + pval0 + ', ' + pval1 + ', '
            newline += pval2 + ')'
        else:
                print('error', line)
                input('wait')
        hout.write(newline + '\n')
    else:
        hout.write(line)

hout.close()
hin.close()
