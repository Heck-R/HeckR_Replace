
;------------------------------------------------
; Unicode insertion by character code

unicodeInsertionActive := false
characterCodeInput := ""
inputBase := "" ; hex / dec

hexaAlternativeKeys := {}
hexaAlternativeKeys["Div"] := "a"
hexaAlternativeKeys["Mult"] := "b"
hexaAlternativeKeys["Sub"] := "c"
hexaAlternativeKeys["Add"] := "d"
hexaAlternativeKeys["Enter"] := "e"
hexaAlternativeKeys["Dot"] := "f"

prepareUnicodeInserion() {
    global

    characterCodeInput := ""
    unicodeInsertionActive := true
}

#if !unicodeInsertionActive

    !NumpadAdd::
        inputBase := "hex"
        prepareUnicodeInserion()
    return

    !NumpadSub::
        inputBase := "dec"
        prepareUnicodeInserion()
    return

#if unicodeInsertionActive

    Alt up::
        if (inputBase == "dec") {
            characterCodeInput := format("{:x}", characterCodeInput)
        }

        unicodeInsertionActive := false
        SendInput {U+%characterCodeInput%}
    return

    !0::
    !1::
    !2::
    !3::
    !4::
    !5::
    !6::
    !7::
    !8::
    !9::
    !a::
    !b::
    !c::
    !d::
    !e::
    !f::
    !Numpad1::
    !Numpad2::
    !Numpad3::
    !Numpad0::
    !Numpad4::
    !Numpad5::
    !Numpad6::
    !Numpad7::
    !Numpad8::
    !Numpad9::
    !NumpadDiv::
    !NumpadMult::
    !NumpadSub::
    !NumpadAdd::
    !NumpadEnter::
    !NumpadDot::
        RegExMatch(A_ThisHotkey, "O)^!(Numpad)?(.*)$", hotkeyMatch)
        hexaChar := RegExMatch(hotkeyMatch[2], "^[0-9a-f]$") ? hotkeyMatch[2] : hexaAlternativeKeys[hotkeyMatch[2]]

        characterCodeInput .= hexaChar
    return

#if
