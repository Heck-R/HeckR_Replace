#SingleInstance, Force

#Include <HeckerFunc>

;------------------------------------------------

#Include %A_ScriptDir%\components

#Include helperFunctions.ahk
#Include templateFunctions.ahk
#Include prepareReplace.ahk

;------------------------------------------------
; Execution

#Include init.ahk
readReplaceIni(mainConfigFilePath)

;------------------------------------------------

#Include hotkeys.ahk
