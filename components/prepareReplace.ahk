
readReplaceIni(configPath, inheritedSettings := "", dependencyBranch := "") {
    ; Init
    global SPECIAL_SECTIONS
    global DEFAULT_SETTINGS
    global toggleAbleSections
    global alternativeSectionDisablers

    sectionName := ""
    
    settings := {}
    objectAssign(settings, DEFAULT_SETTINGS)
    if (inheritedSettings != "")
        objectAssign(settings, inheritedSettings)

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
            if (settings["replace"]["toggleAbleSections"] == "true" && !toggleAbleSections.hasKey(sectionName) && !hasValue(SPECIAL_SECTIONS, sectionName)){
                ; Add section replace list
                toggleAbleSections[sectionName] := {}
                toggleAbleSections[sectionName]["state"] := settings["replace"]["toggleAbleSections"] != "true" || settings["replace"]["enableToggleAbleSectionsOnStart"] == "true" ? "On" : "Off"
                toggleAbleSections[sectionName]["hotstrings"] := []

                ; Create a section toggler hotstrings with a preparameterized function
                sectionTogglerHotstringModifierPart := ":" . settings["replace"]["modifiers"] . "X:"
                sectionTogglerHotstringMainPart := settings["replace"]["toggleWrapperLeft"] . sectionName . settings["replace"]["toggleWrapperRight"]
                sectionTogglerHotstring := sectionTogglerHotstringModifierPart . sectionTogglerHotstringMainPart
                sectionTogglerInstance := Func("sectionTogglerBase").Bind(sectionName)
                Hotstring(sectionTogglerHotstring, sectionTogglerInstance)

                ; Add alternative disable
                if (settings["replace"].hasKey("alternativeSectionDisabler") && settings["replace"]["alternativeSectionDisabler"] != "") {
                    ; Add section name as a section to be disabled with the current alternativeSectionDisabler
                    if (!alternativeSectionDisablers.hasKey( settings["replace"]["alternativeSectionDisabler"] ))
                        alternativeSectionDisablers[ settings["replace"]["alternativeSectionDisabler"] ] := []
                    alternativeSectionDisablers[ settings["replace"]["alternativeSectionDisabler"] ].push(sectionName)
                    
                    ; Create a section toggler hotstrings with a preparameterized function
                    alternativeDisableHotstringModifierPart := ":" . settings["replace"]["modifiers"] . "X:"
                    alternativeDisableHotstringMainPart := settings["replace"]["alternativeSectionDisabler"]
                    alternativeDisableHotstring := alternativeDisableHotstringModifierPart . alternativeDisableHotstringMainPart
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

        if (sectionName == SPECIAL_SECTIONS["configSettings"]) {
            ; Config settings
            
            ; Trim
            configSettingKey := trimEscapedString(replaceKey)
            configSettingValue := trimEscapedString(replaceValue)
            ; Resolve escaping
            configSettingKey := unescapeString(configSettingKey)
            configSettingValue := unescapeString(configSettingValue)

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
            ; Resolve escaping
            replaceSettingKey := unescapeString(replaceSettingKey)
            replaceSettingValue := unescapeString(replaceSettingValue)

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
            ; Resolve escaping
            replaceConfigKey := unescapeString(replaceConfigKey)
            replaceConfigValue := unescapeString(replaceConfigValue)

            ; Settings to be passed to linked config
            settingsToPass := {}
            if (replaceConfigKey == "subConfigFile")
                objectAssign(settingsToPass, settings)

            ; Find out whether the provided path is a relative or a full path and make a recurse call
            innerConfigPath := resolveConfigPath(relativePathRoot, replaceConfigValue)

            if (innerConfigPath["error"])
                configParsingError(innerConfigPath["message"], configFileName, A_Index)

            readReplaceIni(innerConfigPath, settingsToPass, dependencyBranch)
        } else {
            ; Create new replace

            ; Trim
            if (settings["config"]["trimReplaceKeys"] == "true")
                replaceKey := trimEscapedString(replaceKey)
            if (settings["config"]["trimReplaceValues"] == "true")
                replaceValue := trimEscapedString(replaceValue)

            ; Resolve escaping
            replaceKey := unescapeString(replaceKey)
            replaceValue := unescapeString(replaceValue)

            ; Compose hotstring
            customHotstringModifierPart := ":" . settings["replace"]["modifiers"] . ":"
            customHotstringMainPart := settings["replace"]["wrapperLeft"] . replaceKey . settings["replace"]["wrapperRight"]
            customHotstring := customHotstringModifierPart . customHotstringMainPart

            customHotstringDefaultState := settings["replace"]["toggleAbleSections"] != "true" || settings["replace"]["enableToggleAbleSectionsOnStart"] == "true" ? "On" : "Off"

            ; Register as a toggleable
            if (settings["replace"]["toggleAbleSections"] == "true")
                toggleAbleSections[sectionName]["hotstrings"].Push({"hotstring": customHotstring, "replaceValue": replaceValue})

            ; Add replace
            Hotstring(customHotstring, replaceValue, customHotstringDefaultState)
        }

    }
}
