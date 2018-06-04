@echo off
c:\masm32\bin\ml /c /Zd /coff src/find.asm
if errorlevel 1 goto errasm

c:\\masm32\bin\Link /SUBSYSTEM:CONSOLE /out:"find.exe" find.obj
if errorlevel 1 goto errlink

goto done

:errasm
echo.
echo Assembly error
goto done

:errlink
echo.
echo Link error
goto done

:done
echo on
