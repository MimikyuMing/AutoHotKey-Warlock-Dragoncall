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
    SkillPublisher.Subscribe('Leech_Dir1', Leech_Dir1Subscribers())
    SkillPublisher.Subscribe('Leech_Dir11', Leech_Dir11Subscribers())
    SkillPublisher.Subscribe('Mantra', MantraSubscribers())
    SkillPublisher.Subscribe('Rupture_Dir1', Rupture_Dir1Subscribers())
    SkillPublisher.Subscribe('Rupture_Dir11', Rupture_Dir11Subscribers())
    SkillPublisher.Subscribe('Focus', FocusSubscribers())

    SkillPublisher.Subscribe('Leech', LeechSubscribers())
    SkillPublisher.Subscribe('SoulFlare', SoulFlareSubscribers())
}

; 

SkillStatusCheck(){
    global SkillPos, SkillCache, Leech_Color, SoulFlare_Color, BuffsCache, FocusPos, FocusCache, BuffsMap

    ; 合并所有需要采样的坐标为一个 map，使用唯一键以便从单次 GetRegionColors 结果中取回
    local combinedPositions := Map()

    ; 技能坐标 (保留原 skill 名称作为后缀)
    for skill, pos in SkillPos {
        combinedPositions["Skill_" . skill] := pos
    }

    ; 内力坐标 (Focus)
    for fid, pos in FocusPos {
        combinedPositions["Focus_" . fid] := pos
    }

    ; Buffs 坐标，BuffsMap 的每个值是一个数组
    for buffsName, posArr in BuffsMap {
        for idx, pos in posArr {
            combinedPositions["Buffs_" . buffsName . "_" . idx] := pos
        }
    }

    ; 只调用一次屏幕采样
    local allColors := GetRegionColors(combinedPositions)

    ; 从 allColors 中拆分回三组数据：技能、内力、Buffs
    local curSkill_RGBMap := Map()
    for skill, pos in SkillPos {
        curSkill_RGBMap[skill] := allColors.Has("Skill_" . skill) ? allColors["Skill_" . skill] : {red:0,green:0,blue:0}
    }

    local curFocus_Map := Map()
    for fid, pos in FocusPos {
        curFocus_Map[fid] := allColors.Has("Focus_" . fid) ? allColors["Focus_" . fid] : {red:0,green:0,blue:0}
    }

    local curBuffs_MapCollection := Map()
    for buffsName, posArr in BuffsMap {
        local arr := []
        for idx, pos in posArr {
            key := "Buffs_" . buffsName . "_" . idx
            arr.Push(allColors.Has(key) ? allColors[key] : {red:0,green:0,blue:0})
        }
        curBuffs_MapCollection[buffsName] := arr
    }

    ; 处理技能状态通知（保持原逻辑）
    for skill, cur IN curSkill_RGBMap{
        cache := SkillCache[skill]
        result := IsColorCache(cache, cur)
        SkillPublisher.Notify(skill, result)
    }

    ; 处理内力 (Focus)
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

    ; 处理 Buffs（每个 buffsName 对应的坐标数组按原逻辑遍历）
    for skill, posArr IN curBuffs_MapCollection{
        local result := false
        for idx, cur in posArr{
            cache := BuffsCache[skill]
            last_result := result
            result := IsColorCache(cache, cur)
            if(last_result || result){
                break
            }
        }
        SkillPublisher.Notify(skill, result)
    }

    ; ; 在返回之前弹出一个 MsgBox，显示三组真实 RGB，方便调试观察
    ; msg := "Skills:`n"
    ; for skill, col in curSkill_RGBMap {
    ;     msg .= skill " - R:" col.red " G:" col.green " B:" col.blue "`n"
    ; }

    ; msg .= "`nFocus:`n"
    ; for fid, col in curFocus_Map {
    ;     msg .= fid " - R:" col.red " G:" col.green " B:" col.blue "`n"
    ; }

    ; msg .= "`nBuffs:`n"
    ; for bname, arr in curBuffs_MapCollection {
    ;     msg .= bname " (" arr.Length() "):`n"
    ;     for idx, col in arr {
    ;         msg .= "  " idx ": R:" col.red " G:" col.green " B:" col.blue "`n"
    ;     }
    ; }

    ; MsgBox(msg)

    ; 返回三组真实 RGB 数据，方便调用者使用或调试
    return {Skills: curSkill_RGBMap, Focus: curFocus_Map, Buffs: curBuffs_MapCollection}
}