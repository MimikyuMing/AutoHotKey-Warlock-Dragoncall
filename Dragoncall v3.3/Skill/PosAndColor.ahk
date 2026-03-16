#Requires AutoHotkey v2.0

#Include ../Tools.ahk

global BuffsMap := Map()
global BuffsNameList := ["Leech", "SoulFlare"]
global SkillPos := Map()
global SkillColor := Map()
global FocusPos := Map()
Global SkillNameList := ["Dragoncall", "Wingstorm", "Leech_Dir1", "Leech_Dir11", "Mantra", "Rupture_Dir1", "Rupture_Dir11"]


InitSkillPointAndColor(){
    global SkillPos, SkillColor, FocusPos, BuffsBarColumn, BuffsBarRow, Horizontal, Vertical, BuffsBase, BuffsMap, SkillNameList
    ; 技能坐标和颜色配置
    for skillName In SkillNameList {
        SkillPos[skillName] := readPosConfig("SkillPos", skillName)
        SkillColor[skillName] := readColorConfig("SkillColor", skillName)
    }

    ; 内力坐标和颜色配置
    Loop 10 {
        FocusPos[A_Index] := readPosConfig("SkillPos", "Focus_" . A_Index)
    }
    FocusColor := readColorConfig("SkillColor", "Focus")

    ; Buffs坐标和颜色配置
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
        buffsArr := Array()
        j := 0, i := 0
        cur := A_Index
        loop Horizontal{
            j := j + 1
            i := 0
            loop Vertical{
                i := i + 1
                PosMap := {x: BuffsBase[BuffsNameList[cur]].x - (i-1)*BuffsBarRow, y: BuffsBase[BuffsNameList[cur]].y + (j-1)*BuffsBarColumn , c: BuffsBase[BuffsNameList[cur]].c}
                buffsArr.Push(PosMap)
            }
        }
        BuffsMap.Set(BuffsNameList[cur], buffsArr)
    }
    
}