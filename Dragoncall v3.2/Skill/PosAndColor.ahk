#Requires AutoHotkey v2.0

global SkillColor := Map() ; 技能坐标管理
global SkillPos := Map() ; 技能颜色管理
global FocusPos := Map() ; 内力坐标管理


InitSkillPointAndColor(){
    global SkillColor, SkillPos, FocusPos
    ; 暴魔靈 
    SkillColor['Dragoncall'] := 0x174980
    SkillPos['Dragoncall'] := {x: 935, y: 963}
    
    ; 死靈突襲 
    SkillColor['Wingstorm'] := 0x1CA8D4
    SkillPos['Wingstorm'] := {x: 1117, y: 965}
    
    ; 降臨
    SkillColor['SoulFlare1'] := 0x00379b
    SkillPos['SoulFlare1'] := {x: 782, y: 630}
    
    SkillColor['SoulFlare2'] := 0x00379b
    SkillPos['SoulFlare2'] := {x: 734, y: 630}
    
    SkillColor['SoulFlare3'] := 0x00379b
    SkillPos['SoulFlare3'] := {x: 686, y: 630}
    
    ; 掠夺
    SkillColor['Leech1'] := 0x192953
    SkillPos['Leech1'] := {x: 773, y: 621}
    
    SkillColor['Leech2'] := 0x192953
    SkillPos['Leech2'] := {x: 725, y: 621} ; 773-725
    
    SkillColor['Leech3'] := 0x192953
    SkillPos['Leech3'] := {x: 677, y: 621}
    
    ; 掠奪1点方向
    SkillColor['Leech_Dir1'] := 0x799EF1
    SkillPos['Leech_Dir1'] := {x: 1203, y: 616}
    
    ; 掠奪11点方向
    SkillColor['Leech_Dir11'] := 0x1C74F0
    SkillPos['Leech_Dir11'] := {x: 1208, y: 605}
    
    ; 真言
    SkillColor['Mantra'] := 0x00A5D3
    SkillPos['Mantra'] := {x: 1158, y: 973}
    
    ; 破裂
    SkillColor['Rupture_Dir1'] := 0x21B8F0
    SkillPos['Rupture_Dir1'] := {x: 1203, y: 606}
    
    SkillColor['Rupture_Dir11'] := 0xA717D6
    SkillPos['Rupture_Dir11'] := {x: 1207, y: 603}
    
    ; 焦点表格 (focusTbl)
    
    FocusPos[1]  := {x: 823, y: 893, c: 0xFEFFFF}
    FocusPos[2]  := {x: 852, y: 893, c: 0xFEFFFF}
    FocusPos[3]  := {x: 882, y: 893, c: 0xFEFFFF}
    FocusPos[4]  := {x: 911, y: 893, c: 0xFEFFFF}
    FocusPos[5]  := {x: 941, y: 893, c: 0xFEFFFF}
    FocusPos[6]  := {x: 970, y: 893, c: 0xFEFFFF}
    FocusPos[7]  := {x:1000, y: 893, c: 0xFEFFFF}
    FocusPos[8]  := {x:1029, y: 893, c: 0xFEFFFF}
    FocusPos[9]  := {x:1059, y: 893, c: 0xFEFFFF}
    FocusPos[10] := {x:1088, y: 893, c: 0xFEFFFF}

}