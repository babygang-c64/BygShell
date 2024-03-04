# ppkick : kickassembler pre-processor

import sys


def get_size(value):
    size = 16
    if value[0] == '$':
        if len(value) <= 3:
            size = 8
    elif value.isdigit() and int(value) < 256:
            size = 8
    return size


def param_type(param):
    # type param : r, w, a, i

    ptype = 'w'
    pval = param
    if param[0] == '#':
        ptype = 'i'
        pval = param[1:]
    elif param[0].lower() == 'a':
        ptype = 'a'
        pval = ''
    elif param[0].lower()=='r' and (param[1:].isnumeric() or param.lower() in ['rdest', 'rsrc']):
        ptype = 'r'
        if param.lower() == 'rdest':
            pval = 'reg_zdest'
        elif param.lower() == 'rsrc':
            pval = 'reg_zsrc'
        else:
            pval = param[1:].lower()
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

    # MOV

    if instruction == 'mov':
        #print(elems, len(elems))
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])
        #print("param 1 %s [%s]" % (ptype0, pval0))
        #print("param 2 %s [%s]" % (ptype1, pval1))
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
        else:
            # mov r<num>, a -> 
            newline = 'st_' + ptype0 + ptype1 + '(' + pval0 + ', ' + pval1 + ')'
        #print('new [%s]' % newline)
        hout.write(newline + '\n')

    # PUSH, POP, INC, DEC

    elif instruction in ['push', 'pop', 'inc', 'dec']:
        ptype0, pval0 = param_type(elems[1])
        if ptype0 == 'r':
            newline = instruction + '_r(' + pval0 + ')'
        else:
            newline = line
        hout.write(newline + '\n')

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
    elif instruction == 'stc':
        newline = 'stc(' + elems[1] + ')'
        hout.write(newline + '\n')
        print('stc = %s' % newline)
    else:
        hout.write(line)

hout.close()
hin.close()
