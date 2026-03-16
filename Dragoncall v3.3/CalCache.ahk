#Requires AutoHotkey v2.0


#Include Skill\PosAndColor.ahk

global FocusCache := Map()
global SkillCache := Map()
global BuffsCache := Map()

InitCalCache(){
    global SkillCache, SkillColor, FocusCache, FocusPos, BuffsCache
    
    for id, value IN SkillColor{
        color := Integer(SkillColor[id])
        r1 := (color >> 16) & 0xFF
        g1 := (color >> 8) & 0xFF
        b1 := color & 0xFF
        SkillCache[id] := {red:r1, blue:b1, green:g1}
    }

    for id, value IN FocusPos{
        color := 0xFEFFFF
        local refL := ((color >> 16) & 0xFF) * 0.2126 + ((color >> 8) & 0xFF) * 0.7152 + (color & 0xFF) * 0.0722
        FocusCache[id] := refL
    }

    global Leech_Color, SoulFlare_Color
    Leech_Color := Integer(readColorConfig("BuffsBaseColor", "Leech"))
    SoulFlare_Color := Integer(readColorConfig("BuffsBaseColor", "SoulFlare"))
    color := Leech_Color
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF
    BuffsCache['Leech'] := {red:r1, blue:b1, green:g1}
    color := SoulFlare_Color
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF
    BuffsCache['SoulFlare'] := {red:r1, blue:b1, green:g1}
}