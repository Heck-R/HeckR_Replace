
; The base function for toggling sections
sectionTogglerBase(sectionName) {
    global toggleAbleSections
    ; Toggle replace
    toggleAbleSections[sectionName]["state"] := toggleAbleSections[sectionName]["state"] == "Off" ? "On" : "Off"
    for hotstringIndex, hotstringData in toggleAbleSections[sectionName]["hotstrings"] {
        Hotstring(hotstringData["hotstring"], hotstringData["replaceValue"], toggleAbleSections[sectionName]["state"])
    }
}

; The base function for toggling sections
alternativeDisableBase(alternativeDisableHotstringBase) {
    global toggleAbleSections
    global alternativeSectionDisablers

    ; Disable replace
    for sectionIndex, sectionName in alternativeSectionDisablers[alternativeDisableHotstringBase]
        if (toggleAbleSections[sectionName]["state"] == "On") {
            toggleAbleSections[sectionName]["state"] := "Off"
            for hotstringIndex, hotstringData in toggleAbleSections[sectionName]["hotstrings"]
                Hotstring(hotstringData["hotstring"], , "Off")
        }
}
