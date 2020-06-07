#SingleInstance, Force

#Include <HeckerFunc>

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
; Read replaces

readReplaceIni(mainConfigFilePath)
return

;------------------------------------------------

readReplaceIni(configPath, inheritedSettings := "", dependencyBranch := "") {
    ; Init
    global SPECIAL_SECTIONS
    global toggleAbleSections
    global alternativeSectionDisablers

    sectionName := ""
    
    settings := {}
    settings["config"] := inheritedSettings == "" ? {} : inheritedSettings["config"].clone()
    settings["replace"] := inheritedSettings == "" ? {} : inheritedSettings["replace"].clone()

    ; Split the ini file path to folder and file name
    regExMatch(configPath, "O)^(?<configFolder>.+\\)(?<configFileName>[^\\]+)$", pathMatch)
    configFolder := pathMatch["configFolder"]
    configFileName := pathMatch["configFileName"]

    relativePathRoot := configFolder

    ; Check for circular dependencies
    if (dependencyBranch == "")
        dependencyBranch := []
    for dependencyIndex, dependencyPath in dependencyBranch {
        if (dependencyPath == configPath){
            errorMessage := "Circular dependencies detected`n"
            errorMessage .= "`n"
            errorMessage .= "Dependecy list:`n"
            errorMessage .= join("`n", dependencyBranch*)
            errorMessage .= "`n"
            errorMessage .= "`n"
            errorMessage .= "The next dependency would be '" . configPath . "', but it was already dependency number " . dependencyIndex
            configParsingError(errorMessage, configFileName)
        }
    }
    dependencyBranch.push(configPath)
    
    ; Read the config file line by line
    loop, read, %configPath%
    {
        lineParts := splitEscapedString(A_LoopReadLine, ";")
        replaceCommand := lineParts[1]
        ; The whole line is a comment or empty
        if (trim(replaceCommand) == "")
            continue
        
        ; Section marker
        if (regExMatch(replaceCommand, "O)^\s*\[(?<sectionName>.+)\]\s*$", sectionMatch) > 0) {
            ; Set current section name
            sectionName := format("{:L}", unescapeString(sectionMatch["sectionName"]))

            ; Register section as toggle able
            if (settings["replace"]["toggleAbleSections"] == "true" && !toggleAbleSections.hasKey(sectionName)){
                ; Add section replace list
                toggleAbleSections[sectionName] := []

                ; Create a section toggler hotstrings with a preparameterized function
                sectionTogglerHotstring := ":*X:" . settings["replace"]["toggleWrapperLeft"] . sectionName . settings["replace"]["toggleWrapperRight"]
                sectionTogglerInstance := Func("sectionTogglerBase").Bind(sectionName)
                Hotstring(sectionTogglerHotstring, sectionTogglerInstance)

                ; Add alternative disable
                if (settings["replace"].hasKey("alternativeSectionDisabler") && settings["replace"]["alternativeSectionDisabler"] != "") {
                    ; Add section name as a section to be disabled with the current alternativeSectionDisabler
                    if (!alternativeSectionDisablers.hasKey( settings["replace"]["alternativeSectionDisabler"] ))
                        alternativeSectionDisablers[ settings["replace"]["alternativeSectionDisabler"] ] := []
                    alternativeSectionDisablers[ settings["replace"]["alternativeSectionDisabler"] ].push(sectionName)
                    
                    ; Create a section toggler hotstrings with a preparameterized function
                    alternativeDisableHotstring := ":*X:" . settings["replace"]["alternativeSectionDisabler"]
                    alternativeDisableInstance := Func("alternativeDisableBase").Bind(settings["replace"]["alternativeSectionDisabler"])
                    Hotstring(alternativeDisableHotstring, alternativeDisableInstance)
                }
            }

            continue
        }
        
        ; Split key and value
        replaceParts := splitEscapedString(replaceCommand, "=")
        
        ; No key
        if (replaceParts[1] == "")
            configParsingError("The line is malformed: No key found", configFileName, A_Index)
        ; No "=" found
        if (replaceParts.MaxIndex() == 1)
            configParsingError("The line is malformed: No value found", configFileName, A_Index)
        ; Too many "="s
        if (replaceParts.MaxIndex() > 2)
            configParsingError("The line is malformed: Too many '=' signs", configFileName, A_Index)

        ; Extract key and value
        replaceKey := replaceParts[1]
        replaceValue := replaceParts[2]

        ; Trim
        if (settings["config"]["trimReplaceKeys"] == "true")
            replaceKey := trimEscapedString(replaceKey)
        if (settings["config"]["trimReplaceValues"] == "true")
            replaceValue := trimEscapedString(replaceValue)

        ; Resolve escaping
        replaceKey := unescapeString(replaceKey)
        replaceValue := unescapeString(replaceValue)

        if (sectionName == SPECIAL_SECTIONS["configSettings"]) {
            ; Config settings
            
            ; Trim
            configSettingKey := trimEscapedString(replaceKey)
            configSettingValue := trimEscapedString(replaceValue)

            ; Update settings
            if (configSettingKey == "relativePathRoot") {
                relativePathRoot := resolveFolderPath(configFolder, configSettingValue)

                if (relativePathRoot["error"])
                    configParsingError(relativePathRoot["message"], configFileName, A_Index)
            } else
                settings["config"][configSettingKey] := configSettingValue
            
        } else if (sectionName == SPECIAL_SECTIONS["replaceSettings"]) {
            ; Replace settings
            
            ; Trim
            replaceSettingKey := trimEscapedString(replaceKey)
            replaceSettingValue := trimEscapedString(replaceValue)

            ; Update settings
            if (replaceSettingKey == "wrapper" || replaceSettingKey == "toggleWrapper"){
                settings["replace"][replaceSettingKey . "Left"] := replaceSettingValue
                settings["replace"][replaceSettingKey . "Right"] := replaceSettingValue
            } else if (replaceSettingKey == "modifiers")
                settings["replace"][replaceSettingKey] := settings["replace"][replaceSettingKey] . replaceSettingValue
            else
                settings["replace"][replaceSettingKey] := replaceSettingValue
            
        } else if (sectionName == SPECIAL_SECTIONS["replaceConfigs"]) {
            ; Replace configs
            
            ; Trim
            replaceConfigKey := trimEscapedString(replaceKey)
            replaceConfigValue := trimEscapedString(replaceValue)

            ; Settings to be passed to linked config
            settingsToPass := {}
            settingsToPass["config"] := replaceConfigKey == "subConfigFile" ? settings["config"].clone() : {}
            settingsToPass["replace"] := replaceConfigKey == "subConfigFile" ? settings["replace"].clone() : {}

            ; Find out whether the provided path is a relative or a full path and make a recurse call
            innerConfigPath := resolveConfigPath(relativePathRoot, replaceConfigValue)

            if (innerConfigPath["error"])
                configParsingError(innerConfigPath["message"], configFileName, A_Index)

            readReplaceIni(innerConfigPath, settingsToPass, dependencyBranch)
        } else {
            ; Create new replace

            ; Compose hotstring
            customHotstringModifierPart := ":" . settings["replace"]["modifiers"] . ":"
            customHotstringMainPart := settings["replace"]["wrapperLeft"] . replaceKey . settings["replace"]["wrapperRight"]
            customHotstring := customHotstringModifierPart . customHotstringMainPart

            customHotstringDefaultState := settings["replace"]["toggleAbleSections"] != "true" || settings["replace"]["enableToggleAbleSectionsOnStart"] == "true" ? "On" : "Off"

            ; Register as a toggleable
            if (settings["replace"]["toggleAbleSections"] == "true")
                toggleAbleSections[sectionName].push(customHotstring)

            ; Add replace
            Hotstring(customHotstring, replaceValue, customHotstringDefaultState)
        }

    }
}

;------------------------------------------------
; Template functions for hotstrings

; The base function for toggling sections
sectionTogglerBase(sectionName) {
    global toggleAbleSections

    ; Toggle replace
    for hotstringIndex, hotstringDefinition in toggleAbleSections[sectionName] {
        Hotstring(hotstringDefinition, , "Toggle")
    }
}

; The base function for toggling sections
alternativeDisableBase(alternativeDisableHotstringBase) {
    global toggleAbleSections
    global alternativeSectionDisablers

    ; Disable replace
    for sectionIndex, sectionName in alternativeSectionDisablers[alternativeDisableHotstringBase] {
        for hotstringIndex, hotstringDefinition in toggleAbleSections[sectionName] {
            Hotstring(hotstringDefinition, , "Off")
        }
    }
}

;------------------------------------------------
; Path handling

; Try to resolve the given folder path as a relative path, or as a full path
resolveFolderPath(rootPath, folderToResolve) {
    ; Create possible paths
    relativeFolderPath := rootPath . folderToResolve

    ; Try possible paths
    resultFolder := ""
    if (InStr(fileExist(relativeFolderPath), "D"))
        resultFolder :=  relativeFolderPath
    else if (InStr(fileExist(folderToResolve), "D"))
        resultFolder :=  folderToResolve
    
    if (resultFolder)
        return resultFolder . (SubStr(resultFolder, 0) == "\" ? "" : "\")
    
    ; Returning error object
    errorMessage := "The provided path cannot be found`n"
    errorMessage .= "Neither as a relative path '" . relativeFolderPath . "'`n"
    errorMessage .= "Nor as a full path '" . folderToResolve . "'"

    errorObj := {}
    errorObj["error"] := true
    errorObj["message"] := errorMessage

    return errorObj
}

; Try to resolve the given file path as a relative path, a relative sub path, or as a full path
resolveConfigPath(rootPath, fileToResolve) {
    hasExtension := RegExMatch(fileToResolve, ".ini$") > 0
    
    RegExMatch(fileToResolve, "O)(?<configNameNoExt>[^\\]+?)(.ini)?$", configMatch)
    configNameNoExt := configMatch["configNameNoExt"]

    ; Create possible paths
    relativeConfigPath := ""
    relativeSubConfigPath := ""
    fullConfigPath := ""

    if (hasExtension) {
        relativeConfigPath := rootPath . fileToResolve
        fullConfigPath := fileToResolve
    } else {
        relativeConfigPath := rootPath . fileToResolve . ".ini"
        relativeSubConfigPath := rootPath . fileToResolve . "\" . configNameNoExt . ".ini"
        fullConfigPath := fileToResolve . ".ini"
    }
    
    ; Try possible paths
    if (isFile(relativeConfigPath))
        return relativeConfigPath
    else if (isFile(relativeSubConfigPath))
        return relativeSubConfigPath
    else if (isFile(fullConfigPath))
        return fullConfigPath

    ; Returning error object
    errorMessage := "The provided path cannot be found`n"
    errorMessage .= "Neither as a relative path '" . relativeConfigPath . "'`n"
    if (relativeSubConfigPath)
        errorMessage .= "Nor as a relative path '" . relativeSubConfigPath . "'`n"
    errorMessage .= "Nor as a full path '" . fullConfigPath . "'"

    errorObj := {}
    errorObj["error"] := true
    errorObj["message"] := errorMessage

    return errorObj
}

;------------------------------------------------
; Error handling

configParsingError(message, configFile := "", line := "") {
    errorMessage := ""
    
    errorMessage .= "Error during the parsing of the config files!`n"
    errorMessage .= "`n"
    if (configFile != "") {
        errorMessage .= "Place of error:`n"
        errorMessage .= "In file '" . configFile . "'`n"
        if (line != "")
            errorMessage .= "At line '" . line . "'`n"
    }
    if (configFile != "")
        errorMessage .= "`n"
    errorMessage .= "Cause:`n"
    errorMessage .= message . "`n"
    errorMessage .= "`n"
    errorMessage .= "The program exits"

    MsgBox, 0x40030, HeckR_Replace - Error, %errorMessage%

    ExitApp -1
}
