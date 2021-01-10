
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
