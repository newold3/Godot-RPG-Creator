@echo off
echo Limpiando caché de Git...

REM Eliminar archivos de caché de Git
git rm -r --cached .

REM Eliminar archivos .gitignore
git rm --cached .gitignore

REM Limpiar objetos que no son referenciados
git gc --prune=now

REM Limpiar reflog
git reflog expire --all --expire=now

echo Caché de Git limpiada completamente.
pause