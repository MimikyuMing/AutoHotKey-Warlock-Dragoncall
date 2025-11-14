#Requires AutoHotkey v2.0

; ========== 初始化 ==========
global isSoulFlare := 0, isLeech := 0, cnt := 0
global lastAction := "Idle"
global loopHistory := []
global maxHistorySize := 150  ; 30秒数据
global bombRuptureComboStart := 0
global bombRuptureComboType := ""  


#Include CheckState.ahk
#Include HUD.ahk


; ========== 全局函数声明 ==========
CombatLoopIteration_Test(){
    global isSoulFlare, isLeech, GCD, cnt, lastAction
    global loopStartTime := A_TickCount
    local executed_G1 := false, executed_G3 := false

    InitFrameStates()

    BuffStateUpdate()

    ; 2. 破裂组合（需要瞬发状态信息）
    executed_G1 := BombRuptureCombo()
    
    ; 3. 瞬发技能检查（需要instant状态）
    if (!executed_G3) {
        executed_G3 := InstantSkills()
    }
    
    ; 4. 内力检查（需要检测技能CD）
    if (!executed_G1) {
        executed_G1 := FocusRecovery()
    }
    
    ; 5. 主GCD技能（需要降临/掠夺状态）
    if (!executed_G1) {
        executed_G1 := MainGCDSkills()
    }
    

    
    global loopDuration := A_TickCount - loopStartTime
    ShowCombatHUD()
    Sleep LOOP_DELAY_MS
}

CombatLoopIteration() {
    global isSoulFlare, isLeech, GCD, cnt, lastAction
    global loopStartTime := A_TickCount
    local executed_G1 := false, executed_G3 := false

    

    InitFrameStates()

    BuffStateUpdate()

    ; 调试：检查 FrameStates 状态
    if (!IsSet(FrameStates)) {
        MsgBox "FrameStates 未定义"
        return
    }
    
    if (!FrameStates) {
        MsgBox "FrameStates 为 null"
        return
    }
    
    if (Type(FrameStates) != "Map") {
        MsgBox "FrameStates 类型错误: " Type(FrameStates)
        return
    }

    ; 2. 破裂组合（需要瞬发状态信息）
    executed_G1 := BombRuptureCombo()
    
    ; 3. 瞬发技能检查（需要instant状态）
    if (!executed_G3) {
        executed_G3 := InstantSkills()
    }
    
    ; 4. 内力检查（需要检测技能CD）
    if (!executed_G1) {
        executed_G1 := FocusRecovery()
    }
    
    ; 5. 主GCD技能（需要降临/掠夺状态）
    if (!executed_G1) {
        executed_G1 := MainGCDSkills()
    }
    

    
    global loopDuration := A_TickCount - loopStartTime
    ShowCombatHUD()
    Sleep LOOP_DELAY_MS
}

BuffStateUpdate(){
    ; 只在需要时检测这些状态
    static lastStateCheck := 0
    if (A_TickCount - lastStateCheck > 300) {
        CheckSoulFlareState()
        CheckLeechState()
        lastStateCheck := A_TickCount
    }
}

BombRuptureCombo() {
    global bombRuptureComboStart, bombRuptureComboType, GCD, cnt, lastAction, FrameStates

    
    if (bombRuptureComboStart > 0 && bombRuptureComboType = "Bombardment_Normal" && !(isLeech || isSoulFlare)) {
        local expectedGCDEnd := bombRuptureComboStart + GCDManager.SKILL_GCD_TIMES["Bombardment_Normal"]
        
        if (A_TickCount >= expectedGCDEnd) {
            CheckRupture()
            if (GCD.IsReady("Rupture") && (FrameStates["Rupture11"] || FrameStates["Rupture1"])) {
                Send 'f'
                ; Sleep DELAY_RUPTURE
                GCD.SetGCD("Rupture")
                cnt++
                lastAction := "Bomb+Rupture"
                bombRuptureComboStart := 0
                bombRuptureComboType := ""
                return true
            }
            bombRuptureComboStart := 0
            bombRuptureComboType := ""
        }
    }
    return false
}


InstantSkills() {
    global GCD, cnt, lastAction, FrameStates

    CheckInstant_DragoncallStates()
    
    ; 暴魔灵检查 - 简化条件，只检查就绪状态和技能状态
    if (FrameStates["Dragoncall_Instant"] && GCD.IsReady("Dragoncall_Instant")) {
        Send "{4 down}"
        Send "{4 up}"
        GCD.SetGCD("Dragoncall_Instant")
        cnt++
        lastAction := "Instant-4"
        ; MainGCDSkills()
        return true
    }else{
        CheckInstant_WingstormStates()
        ; 死灵突袭检查
        if (FrameStates["Wingstorm_Instant"] && GCD.IsReady("Wingstorm_Instant")) {
            Send "{v down}"
            Send "{v up}"
            GCD.SetGCD("Wingstorm_Instant")
            cnt++
            lastAction := "Instant-v"
            ; MainGCDSkills()
            return true
        }
    }  
    return false
}

; 112ms
FocusRecovery() {
    global isSoulFlare, isLeech, GCD, cnt, lastAction, FrameStates

    
    ; ; 强制内力恢复（内力极低时）
    ; if (!isSoulFlare && IsLowFocus(3))  {
    ;     Send 'r'
    ;     ; Sleep DELAY_MANTRA
    ;     if (GCD.IsReady("R")) {
    ;         GCD.SetGCD("R")
    ;     }
    ;     cnt++
    ;     lastAction := "Force R"
    ;     return true
    ; }
    
    ; 正常内力恢复
    local mantraThreshold := isSoulFlare ? MANTRA_FOCUS_SF : (isLeech ? MANTRA_FOCUS_LEECH : MANTRA_FOCUS_NORMAL)
    local ruptureThreshold := isSoulFlare ? RUPTURE_FOCUS_SF : (isLeech ? RUPTURE_FOCUS_LEECH : RUPTURE_FOCUS_NORMAL)
    
    CheckMantra()
    if (FrameStates["Mantra"] && GCD.IsReady("Mantra") && IsLowFocus(mantraThreshold)) {
        Send 'r'
        ; Sleep DELAY_MANTRA
        GCD.SetGCD("Mantra")
        cnt++
        lastAction := "Mantra"
        return true
    }else{
        CheckRupture()
        if ((FrameStates["Rupture11"] || FrameStates["Rupture1"]) && GCD.IsReady("Rupture") && IsLowFocus(ruptureThreshold)) {
            Send 'f'
            ; Sleep DELAY_RUPTURE
            GCD.SetGCD("Rupture")
            cnt++
            lastAction := "Rupture"
            return true
        }
    }
    return false
}

MainGCDSkills() {
    global isSoulFlare, isLeech, GCD, cnt, lastAction, FrameStates
    global bombRuptureComboStart, bombRuptureComboType

    CheckLeechCD()

    ; 掠夺检查
    local isLeechReady := FrameStates["LeechDir1"] || FrameStates["LeechDir11"]
    if (isLeechReady && !isLeech && GCD.IsReady("Leech")) {
        Send 'f'
        ; Sleep DELAY_INSTANT
        GCD.SetGCD("Leech")
        cnt++
        lastAction := "Leech"
        return true
    } 
    
    ; 确定次元弹类型
    local bombardmentType := "Bombardment_Normal"
    if (isSoulFlare) {
        bombardmentType := "Bombardment_True"
    } else if (isLeech || FrameStates["Dragoncall_Instant"] || FrameStates["Wingstorm_Instant"]) {
        bombardmentType := "Bombardment_Instant"
    }
    
    ; 次元弹
    if (GCD.IsReady(bombardmentType) && (bombardmentType == "Bombardment_True" || bombardmentType := "Bombardment_Instant")) {
        Send 't'
        GCD.SetGCD(bombardmentType)
        cnt++
        lastAction := bombardmentType
        return true
    }else if (GCD.IsReady(bombardmentType)){
        GCD.get
        Send 't'
        GCD.SetGCD(bombardmentType)
        cnt++
        lastAction := bombardmentType
        ; 如果是普通次元弹，标记需要接破裂
        if (bombardmentType = "Bombardment_Normal") {
            bombRuptureComboStart := A_TickCount
            bombRuptureComboType := "Bombardment_Normal"
            lastAction := "Bomb-WaitRupture"
        }
    }
    
    return false
}


