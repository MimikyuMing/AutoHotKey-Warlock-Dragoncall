#Requires AutoHotkey v2.0

#Include SkillStatus.ahk
#Include Condition.ahk
#Include ../Tools.ahk
#Include ../Gui.ahk

global Limit := 10
global FocusSkill_Limit := 200
global LastExecuteTime := 0

SkillLoop(){
    global SkillCnt, SkillCntLastTime:=0 ; 操作数最终结果
    global LastExecuteTime ; 上一次执行时间戳
    global SkillStatus

    if(A_TickCount - SkillCntLastTime >= 1000){
        SkillCnt := 0
    }

    local cnt := 0

    ; 瞬发逻辑
    local gcd_group1 := false
    static slow_focus_time := A_TickCount

    global GoldWingstorm
    ; 1. 暴魔灵
    if(SkillStatus['Dragoncall']){
        Send '4'
        cnt++
    }

    ; 2. 死灵突袭
    if(GoldWingstorm || SkillStatus['Wingstorm']){
        Send 'v'
        cnt++
    }

    ; if(!GoldWingstorm){
    ;     ; 1. 暴魔灵
    ;     if(SkillStatus['Dragoncall']){
    ;         Send '4'
    ;         cnt++
    ;     }

    ;     ; 2. 死灵突袭
    ;     if(SkillStatus['Wingstorm']){
    ;         Send 'v'
    ;         cnt++
    ;     }
    ; }else{
    ;     if(SkillStatus['Dragoncall']){
    ;         Send '4'
    ;         cnt++
    ;         Send 'v'
    ;         cnt++
    ;     }
    ; }

    ; 3. 掠夺
    if(!gcd_group1 && !SkillStatus['IsLeech'] && SkillStatus['Leech']){
        Send 'f'
        cnt++
        gcd_group1 := true
    }

    ; 4. 真言
    if(!gcd_group1 && EnableSkill.get('Mantra') && !(!SkillStatus['IsLeech'] && SkillStatus['Leech'])){
        local MantraRequired := SkillStatus['IsSoulFlare'] ? 
            SkillCondition.get('Mantra').get('IsSoulFlare') :
                (SkillStatus['IsLeech'] ? SkillCondition.get('Mantra').get('IsLeech') : SkillCondition.get('Mantra').get('Normal')
            )
        ; if(SkillStatus['Mantra'] && isLowFocus(MantraRequired)){
        ;     Send 'r'
        ;     cnt++
        ;     gcd_group2 := true
        ;     slow_focus_flag := A_TickCount
        ; }
        if(SkillStatus['Mantra'] && MantraRequired >= SkillStatus['Focus']){
            Send 'r'
            cnt++
            gcd_group1 := true
            slow_focus_flag := A_TickCount
        }

    }

    ; 5. 破裂
    if(!gcd_group1 && EnableSkill.get('Rupture') && !(!SkillStatus['IsLeech'] && SkillStatus['Leech'])){
        local RuptureRequired := SkillStatus['IsSoulFlare'] ? 
            SkillCondition.get('Rupture').get('IsSoulFlare') :
                (SkillStatus['IsLeech'] ? SkillCondition.get('Rupture').get('IsLeech') : SkillCondition.get('Rupture').get('Normal')
            )
            if(SkillStatus['Rupture'] && MantraRequired >= SkillStatus['Focus']){
                Send 'f'
                cnt++
                gcd_group1 := true
                slow_focus_flag := A_TickCount
            }
        ; if(SkillStatus['Rupture'] && isLowFocus(RuptureRequired)){
        ;     Send 'f'
        ;     cnt++
        ;     gcd_group2 := true
        ;     slow_focus_flag := A_TickCount
        ; }
    }
    local RandomLimit := Limit
    ; 6. 次元弹: 当执行时间小于Config.Limit的时候,限制执行,以减轻高频带来的卡顿
    if(!(!SkillStatus['IsLeech'] && SkillStatus['Leech']) && (A_TickCount - LastExecuteTime >= RandomLimit)){
        Send 't'
        cnt++
        LastExecuteTime := A_TickCount
        gcd_group1 := true
    }


    
    SkillCnt := cnt
    SkillCntLastTime := A_TickCount
}