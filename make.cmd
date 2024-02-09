@echo off

SET PATH=tools;%PATH%

:echo BDOS proto
:asw -lU src\bdos\cpm64-bdos.asm > cpm64-bdos.lst
:p2bin src\bdos\cpm64-bdos.p cpm64-bdos.bin

:xit

echo ROM-disk Control Program 3.0
asw -lU -i . src\romctrl.asm > romctrl.lst
p2bin src\romctrl.p roms\romctrl.rom

