# ppkick : kickassembler pre-processor

import sys


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
            ptype= 's'
            if param.lower() == '(rdest)':
                pval = 'reg_zdest'
            elif param.lower() == '(rsrc)':
                pval = 'reg_zsrc'
            else:
                pval = param[2:-1]

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

    if instruction == 'mov':
        print(elems, len(elems))
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])
        print("param 1 %s [%s]" % (ptype0, pval0))
        print("param 2 %s [%s]" % (ptype1, pval1))
        if ptype0 != 'a' and ptype1 != 'a':
            newline = 'st' + ptype1 + '_' + ptype0 + '(' + pval0 + ', ' + pval1 + ')'
        elif ptype0 == 'a':
            newline = 'st_' + ptype0 + ptype1 + '(' + pval1 + ')'
        else:
            newline = 'st_' + ptype0 + ptype1 + '(' + pval1 + ')'
        print('new [%s]' % newline)
        hout.write(newline + '\n')
    elif instruction in ['push', 'pop', 'inc', 'dec']:
        ptype0, pval0 = param_type(elems[1])
        if ptype0 == 'r':
            newline = instruction + '_r(' + pval0 + ')'
        else:
            newline = line
        hout.write(newline + '\n')
    elif instruction == 'add':
        ptype0, pval0 = param_type(elems[1])
        ptype1, pval1 = param_type(elems[3])
        if ptype0 == 'r' and ptype1 == 'a':
            newline = 'add_r(' + pval0 + ')'
            hout.write(newline + '\n')
        else:
            print(ptype0, pval0)
            print(ptype1, pval1)
            print('error', line)
            input('wait')
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
    else:
        hout.write(line)

hout.close()
hin.close()

