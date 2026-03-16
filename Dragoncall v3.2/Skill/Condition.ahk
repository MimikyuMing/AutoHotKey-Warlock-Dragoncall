#Requires AutoHotkey v2.0

global EnableSkill := Map() ; 技能开关管理
global SkillCondition := Map() ; 技能条件管理


InitSkillCondition(){
    global SkillCondition
    SkillCondition['Mantra'] := Map()
    SkillCondition['Rupture'] := Map()

    SkillCondition['Mantra']['Normal'] := 6
    SkillCondition['Mantra']['IsLeech'] := 4 
    SkillCondition['Mantra']['IsSoulFlare'] := 2

    SkillCondition['Rupture']['Normal'] := 5
    SkillCondition['Rupture']['IsLeech'] := 3
    SkillCondition['Rupture']['IsSoulFlare'] := 1

}

InitEnableSkill(){
    global EnableSkill
    EnableSkill['Mantra'] := true
    EnableSkill['Rupture'] := true
}