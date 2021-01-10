
;------------------------------------------------
; Setting constants

; Special section names which should be treated differently from standard replace sections
SPECIAL_SECTIONS := {}
SPECIAL_SECTIONS["configSettings"] := "config settings"
SPECIAL_SECTIONS["replaceSettings"] := "replace settings"
SPECIAL_SECTIONS["replaceConfigs"] := "replace configs"

;------------------------------------------------
; Setting variables

; The set of sections which can be toggled, and the replaces associated with them
; Example: {toggleAbleSectionName1: [replaceHotstring1, replaceHotstring2, ...], ...}
toggleAbleSections := {}

; The set of alternative disable hotstrings, and the section names associated with them
; Example: {alternativeDisableHotstring: [sectionNameToDisable1, sectionNameToDisable2, ...], ...}
alternativeSectionDisablers := {}

;------------------------------------------------
; Prepare environment

; Set working dir to a non-eyistent path, so relative paths in the configs will not yield undesired results
SetWorkingDir, NonexistentWorkingDirectory

; Main config ini
mainConfigFilePath := regexreplace(A_ScriptFullPath, "\.[^.]+$",".ini")

if (!FileExist(mainConfigFilePath)) {
    FileAppend, , %mainConfigFilePath%

    errorMessage := "The main config file did not exist`n"
    errorMessage .= "The file was created to avoid running into this error next time"
    configParsingError(errorMessage)
}

;------------------------------------------------
; Default settings

DEFAULT_SETTINGS := {}

DEFAULT_SETTINGS["config"] := {}
DEFAULT_SETTINGS["config"]["trimReplaceKeys"] := "true"
DEFAULT_SETTINGS["config"]["trimReplaceValues"] := "true"

DEFAULT_SETTINGS["replace"] := {}
