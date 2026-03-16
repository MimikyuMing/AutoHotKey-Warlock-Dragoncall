#Requires AutoHotkey v2.0
global DefaultConfigFilePath := A_ScriptDir "\config.ini"
configFile := A_ScriptDir "\config.ini"
; SkillPos := IniRead(configFile, "SkillPos", "Dragoncall")

Global SkillNameList := ["Dragoncall", "Wingstorm", "Leech_Dir1", "Leech_Dir11", "Mantra", "Rupture_Dir1", "Rupture_Dir11"]


readConfig(Section, Key, Path:=DefaultConfigFilePath){
    result := IniRead(DefaultConfigFilePath, Section, Key)
    return result
}

readPosConfig(Section, Key, Path:=DefaultConfigFilePath){
    posStr := IniRead(DefaultConfigFilePath, Section, Key)
    if (posStr = "")
        return {x: 0, y: 0} ; 默认值
    coords := StrSplit(posStr, ",")
    if (coords.Length != 2)
        return {x: 0, y: 0} ; 格式错误，返回默认值
    return {x: coords[1], y: coords[2]}
}

readColorConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

readBarSpaceConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

readBuffsNumberConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}





global SkillPos := Map()
global SkillColor := Map()
global FocusPos := Map()

for skillName In SkillNameList {
    SkillPos[skillName] := readPosConfig("SkillPos", skillName)
    SkillColor[skillName] := readColorConfig("SkillColor", skillName)
}

Loop 10 {
    FocusPos[A_Index] := readPosConfig("SkillPos", "Focus_" . A_Index)
}
FocusColor := readColorConfig("SkillColor", "Focus")


MsgText := ""
for skillName In SkillNameList {
    MsgText .= skillName ": " SkillPos[skillName].x ", " SkillPos[skillName].y " , COLOR: " SkillColor[skillName]  "`n"
}

Loop 10 {
    MsgText .=  "Focus_" . A_Index . ": " FocusPos[A_Index].x ", " FocusPos[A_Index].y " , COLOR: " FocusColor  "`n"
}

MsgBox MsgText


global BuffsMap := Map()
global BuffsNameList := ["Leech", "SoulFlare"]
BuffsBarColumn := readBarSpaceConfig("BarSpace", "BuffsBarColumn")
BuffsBarRow := readBarSpaceConfig("BarSpace", "BuffsBarRow")

Horizontal := readBarSpaceConfig("BuffsNumber", "Horizontal")
Vertical := readBarSpaceConfig("BuffsNumber", "Vertical")

BuffsBase := Map()
for buffsName in BuffsNameList{
    Pos := readPosConfig("BuffsBasePos", buffsName)
    Color := readColorConfig("BuffsBaseColor", buffsName)
    PosAndColor := {x: Pos.x, y: Pos.y, c: Color}
    BuffsBase.Set(buffsName, PosAndColor)
}


loop BuffsNameList.Length{
    buffsArr := Map()
    j := 0, i := 0
    cur := A_Index
    loop Horizontal{ ;2
        j := j + 1
        i := 0
        loop Vertical{ ;10
            i := i + 1
            PosMap := {x: BuffsBase[BuffsNameList[cur]].x - (i-1)*BuffsBarRow, y: BuffsBase[BuffsNameList[cur]].y + (j-1)*BuffsBarColumn , c: BuffsBase[BuffsNameList[cur]].c}
            index := (j-1)* Vertical + i
            if (index < Vertical){
                index := "0" . index
            }
            buffsArr.Set(BuffsNameList[cur] . "_" . index , PosMap)
        }
    }
    BuffsMap.Set(BuffsNameList[cur], buffsArr)
}

MsgTest := ""
for buffsName, buffsArr in BuffsMap{
    MsgTest .= buffsName ": " "`n"
    for buff_index, posMap in buffsArr{

        MsgTest .= buff_index . ": " . posMap.x ", " . posMap.y " , COLOR: " . posMap.c "`n"
    }
}

MsgBox MsgTest





