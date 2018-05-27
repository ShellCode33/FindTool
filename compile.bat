@echo off
c:\masm32\bin\ml /c /Zd /coff src/find.asm
c:\masm32\bin\Link /SUBSYSTEM:CONSOLE find.obj
