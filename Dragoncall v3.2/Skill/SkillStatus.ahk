#Requires AutoHotkey v2.0

#Include ../Tools.ahk
#Include PosAndColor.ahk
#Include ../CalCache.ahk
#Include Observer\SkillPublisher.ahk
#Include Observer\SkillSubscribers.ahk

global SkillStatus := Map() ; 技能状态管理，事件驱动

InitSkillStatus(){
    global SkillStatus
    SkillStatus['Dragoncall'] := false
    SkillStatus['Wingstorm'] := false
    SkillStatus['IsSoulflare'] := false
    SkillStatus['IsLeech'] := false
    SkillStatus['Leech'] := false
    SkillStatus['Rupture'] := false
    SkillStatus['Mantra'] := false
    SkillStatus['Focus'] := 0
}

InitObserver(){
    SkillPublisher.Subscribe('Dragoncall', DragoncallSubscribers())
    SkillPublisher.Subscribe('Wingstorm', WingstormSubscribers())
    SkillPublisher.Subscribe('SoulFlare1', SoulFlare1Subscribers())
    SkillPublisher.Subscribe('SoulFlare2', SoulFlare2Subscribers())
    SkillPublisher.Subscribe('SoulFlare3', SoulFlare3Subscribers())
    SkillPublisher.Subscribe('Leech1', Leech1Subscribers())
    SkillPublisher.Subscribe('Leech2', Leech2Subscribers())
    SkillPublisher.Subscribe('Leech3', Leech3Subscribers())
    SkillPublisher.Subscribe('Leech_Dir1', Leech_Dir1Subscribers())
    SkillPublisher.Subscribe('Leech_Dir11', Leech_Dir11Subscribers())
    SkillPublisher.Subscribe('Mantra', MantraSubscribers())
    SkillPublisher.Subscribe('Rupture_Dir1', Rupture_Dir1Subscribers())
    SkillPublisher.Subscribe('Rupture_Dir11', Rupture_Dir11Subscribers())
    SkillPublisher.Subscribe('Focus', FocusSubscribers())
}

; 

SkillStatusCheck(){
    global SkillPos, SkillCache
    local curSkill_RGBMap := GetRegionColors(SkillPos)
    for skill, cur IN curSkill_RGBMap{
        cache := SkillCache[skill]
        result := IsColorCache(cache, cur)
        SkillPublisher.Notify(skill, result)
    }
    local curFocus_Map := GetRegionColors(FocusPos)
    local f_result := 0

    for focus_id, act IN curFocus_Map{
        refL := FocusCache[focus_id]
        actL := act.red * 0.2126
        + act.green * 0.7152
        + act.blue * 0.0722
        isLow := (actL < refL) ; isLowFocus
        if(!isLow && focus_id > f_result){
            f_result := focus_id
        }
    }
    SkillPublisher.Notify('Focus', f_result)
}