#! /bin/zsh -

# -attach9rw /Users/bertrandjesenberger/Desktop/temp/dhd.dhd

VICE=/Applications/vice-arm64-gtk3-3.6.2-dev-r42514/bin/x64sc
KICKASS=../KickAss.jar
EXOMIZER=./exomizer
PPKICK=ppkick.py

python3 ${PPKICK} bios.asm bios_pp.asm
python3 ${PPKICK} byg_shell.asm byg_shell_pp.asm

java -jar ${KICKASS} byg_shell_pp.asm -o byg_shell_full.prg

if [[ $? == 0 ]]
then
    ${EXOMIZER} sfx 0xfce2 byg_shell_full.prg -n -q -o byg_shell.prg
    ${VICE} --silent -9 /Users/bertrandjesenberger/Desktop/temp/dhd.dhd --autostart byg_shell.prg
    print -P "\n%F{green}Compile OK 💾\n"
else
    print -P "\n%F{red}💣💣💣 Boom, compile error !\n"
fi
