#SingleInstance, Force

;------------------------------------------------

mainConfigFilePath := regexreplace(A_ScriptFullPath, "\.[^.]+$",".ini")

if (!FileExist(mainConfigFilePath)) {
    FileAppend, , %mainConfigFilePath%

    errorMessage := "The main config file did not exist`n"
    errorMessage .= "The file was created to avoid running into this error next time"
    configParsingError(errorMessage)
}

readReplaceIni(mainConfigFilePath, {})

;------------------------------------------------

readReplaceIni(configPath, inheritedSettings) {
    ; Init
    sectionName := ""
    settings := inheritedSettings.clone()

    ; Split the ini file path to folder and file name
    regExMatch(configPath, "O)^(?<configFolder>.+\\)(?<configFileName>[^\\]+)$", pathMatch)
    configFolder := pathMatch["configFolder"]
    configFileName := pathMatch["configFileName"]

    relativePathRoot := configFolder
    
    ; Read the config file line by line
    Loop, read, %configPath%
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
        if (settings["trimReplaceKeys"] == "true")
            replaceKey := trimEscapedString(replaceKey)
        if (settings["trimReplaceValues"] == "true")
            replaceValue := trimEscapedString(replaceValue)

        ; Resolve escaping
        replaceKey := unescapeString(replaceKey)
        replaceValue := unescapeString(replaceValue)

        
        if (sectionName == "replace settings") {
            ; Settings
            
            ; Trim
            settingKey := trimEscapedString(replaceKey)
            settingValue := trimEscapedString(replaceValue)
            ; Update settings
            if (settingKey == "replaceModifiers")
                settings[settingKey] := settings["replaceModifiers"] . settingValue
            else if (settingKey == "relativePathRoot")
                relativePathRoot := configFolder . settingValue . (SubStr(settingValue, 0) == "\" ? "" : "\")
            else
                settings[settingKey] := settingValue
            
        } else if (sectionName == "replace configs") {
            ; Replace configs
            
            ; Trim
            settingKey := trimEscapedString(replaceKey)
            settingValue := trimEscapedString(replaceValue)

            ; Settings to be passed to linked config
            settingsToPass := settingKey == "subConfigFile" ? settings.clone() : {}

            ; Find out whether the provided path is a relative or a full path and make a recurse call
            relativeConfigPath := relativePathRoot . settingValue
            
            if (fileExist(relativeConfigPath)){
                readReplaceIni(relativeConfigPath, settingsToPass)
            } else if (fileExist(settingValue)){
                readReplaceIni(settingValue, settingsToPass)
            } else {
                errorMessage := "The provided config file cannot be found`n"
                errorMessage .= "Neither as a relative path '" . relativeConfigPath . "'`n"
                errorMessage .= "Nor as a full path '" . settingValue . "'"
                configParsingError(errorMessage, configFileName, A_Index)
            }

        } else {
            ; Replaces
            Hotstring(":" . settings["replaceModifiers"] . ":" . replaceKey, replaceValue)
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