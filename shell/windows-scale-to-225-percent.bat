@ECHO OFF

explorer ms-settings:display

ping -n 2 127.0.0.1 > nul

:VBSDynamicBuild

SET TempVBSFile=%tmp%\~tmpSendKeysTemp.vbs
IF EXIST "%TempVBSFile%" DEL /F /Q "%TempVBSFile%"

ECHO Set WshShell = WScript.CreateObject("WScript.Shell") >>"%TempVBSFile%"
ECHO Wscript.Sleep 500                                    >>"%TempVBSFile%"
ECHO WshShell.SendKeys "{TAB 2}{DOWN 3}"                  >>"%TempVBSFile%"
ECHO Wscript.Sleep 500                                    >>"%TempVBSFile%"
ECHO WshShell.SendKeys "%%{F4}"                           >>"%TempVBSFile%"

WSCRIPT //nologo "%TempVBSFile%"
EXIT