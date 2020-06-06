#SingleInstance, Force

#Include <HeckerFunc>

;------------------------------------------------

NONEXISTENT_WORKING_DIRECTORY_NAME := "NonexistentWorkingDirectory"
SetWorkingDir, %NONEXISTENT_WORKING_DIRECTORY_NAME%

;------------------------------------------------
mainConfigFilePath := regexreplace(A_ScriptFullPath, "\.[^.]+$",".ini")

if (!FileExist(mainConfigFilePath)) {
    FileAppend, , %mainConfigFilePath%

    errorMessage := "The main config file did not exist`n"
    errorMessage .= "The file was created to avoid running into this error next time"
    configParsingError(errorMessage)
}

readReplaceIni(mainConfigFilePath)

;------------------------------------------------

readReplaceIni(configPath, inheritedSettings := "", dependencyBranch := "") {
    ; Init
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
            sectionName := format("{:L}", unescapeString(sectionMatch["sectionName"]))
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

        
        if (sectionName == "config settings") {
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
            
        } else if (sectionName == "replace settings") {
            ; Replace settings
            
            ; Trim
            replaceSettingKey := trimEscapedString(replaceKey)
            replaceSettingValue := trimEscapedString(replaceValue)

            ; Update settings
            if (replaceSettingKey == "wrapper"){
                settings["replace"][replaceSettingKey . "Left"] := replaceSettingValue
                settings["replace"][replaceSettingKey . "Right"] := replaceSettingValue
            } else if (replaceSettingKey == "modifiers")
                settings["replace"][replaceSettingKey] := settings["replace"][replaceSettingKey] . replaceSettingValue
            else
                settings["replace"][replaceSettingKey] := replaceSettingValue
            
        } else if (sectionName == "replace configs") {
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
            customHotstringModifierSection := ":" . settings["replace"]["modifiers"] . ":"
            customHotstringMainSection := settings["replace"]["wrapperLeft"] . replaceKey . settings["replace"]["wrapperRight"]

            customHotstring := customHotstringModifierSection . customHotstringMainSection

            Hotstring(customHotstring, replaceValue)
        }

    }
}

; Split the given string with the provided delimiter unless it is escaped by the provided escape character
splitEscapedString(string, delim := "`n", escChar := "``") {
    lastSeparator := 0
    splittedStrings := []

    escaping := false
    Loop, Parse, string
    {
        ; Skip character if it is being escaped
        if (escaping == true){
            escaping := false
            continue
        }
        ; Note that the next character will be escaped
        if (A_LoopField == escChar) {
            escaping := true
            continue
        }

        ; Split if a delimiter is found
        if (A_LoopField == delim) {
            splittedStrings.push(subStr(string, lastSeparator +1, A_Index - lastSeparator -1))
            lastSeparator := A_Index
        }
    }

    if (lastSeparator != strLen(string))
        splittedStrings.push(subStr(string, lastSeparator +1, strLen(string) - lastSeparator))

    return splittedStrings
}

; Trim not escaped whitespaces from both side
trimEscapedString(string, escChar := "``") {
    trimmedString := LTrim(string)

    if (trimmedString == "")
        return ""
    
    ; Searching for first non whitespace
    checkCharPos := strLen(trimmedString)
    while ( checkCharPos > 0 && regExMatch( subStr(trimmedString, checkCharPos, 1) , "\s") > 0 )
        checkCharPos--
    firstWhitespace := checkCharPos + 1

    ; Counting escapes
    escCharNum := 0
    while (subStr(trimmedString, checkCharPos - escCharNum, 1) == escChar){
        checkCharPos--
        escCharNum++
    }

    ; Trimming the end with consideration for escaped whitespaces
    escapeModifier := mod(escCharNum, 2) == 0 ? -1 : 0
    firstActualNonWhitespace := firstWhitespace + escapeModifier
    trimmedString := subStr(trimmedString, 1, firstActualNonWhitespace)

    return trimmedString
}

; Remove escape characters and replace the escaped character with its escaped version if needed
unescapeString(string, escChar := "``") {
    unescapedString := string
    unescapedString := StrReplace(unescapedString, "``n", "`n")
    unescapedString := StrReplace(unescapedString, "``r", "`r")
    unescapedString := StrReplace(unescapedString, "``s", "`s")
    unescapedString := StrReplace(unescapedString, "``t", "`t")
    unescapedString := RegExReplace(unescapedString, "``(.)", "$1")
    return unescapedString
}

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

isFile(filePath) {
    return (fileExist(filePath) && !InStr(fileExist(filePath), "D"))
}
