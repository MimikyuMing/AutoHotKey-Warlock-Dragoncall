#Requires AutoHotkey v2.0
#Include Tools.ahk
#Include ColorPick.ahk
#Include Config.ahk
#Include GCDManager.ahk

; ========== 初始化 ==========
global isSoulFlare := 0, isLeech := 0, cnt := 0
global FrameStates := Map()
global lastAction := "Idle"
global loopHistory := []
global maxHistorySize := 150  ; 30秒数据
global isSoulFlare, isLeech, GCD, cnt, lastAction
global bombRuptureComboStart := 0
global bombRuptureComboType := ""  
global loopStartTime := A_TickCount

; ========== 全局函数声明 ==========
CombatLoopIteration_Test(){
    global isSoulFlare, isLeech, GCD, cnt, lastAction
    global loopStartTime := A_TickCount
    UpdateAllStates_Fast()
    local executed := false
    
    global loopDuration := A_TickCount - loopStartTime
    ShowCombatHUD()
}

CombatLoopIteration() {
    global isSoulFlare, isLeech, GCD, cnt, lastAction
    global bombRuptureComboStart := 0
    global bombRuptureComboType := ""  
    global loopStartTime := A_TickCount

    UpdateAllStates_Fast()
    
    local executed := false

    ; 先检查破裂组合（最高优先级）
    executed := CheckBombRuptureCombo()

    ; 1. 瞬发技能检查 - 提高优先级，简化判断
    if (!executed) {
        executed := CheckInstantSkills()
    }

    ; 2. 内力检查
    if (!executed) {
        executed := CheckFocusRecovery()
    }
    
    ; 3. 主GCD组技能
    if (!executed) {
        executed := CheckMainGCDSkills()
    }
    
    if (!executed) {
        lastAction := "Idle"
    }
    ; 计算循环耗时
    global loopDuration := A_TickCount - loopStartTime
    
    ShowCombatHUD()
    Sleep LOOP_DELAY_MS
}

; 109ms
UpdateAllStates_Fast() {
    global FrameStates, isSoulFlare, isLeech
    
    static lastSoulFlareCheck := 0
    static lastLeechCheck := 0
    static lastLeechCDCheck := 0
    
    ; === 必须实时检测（每帧）===
    FrameStates["Dragoncall_Instant"] := IsColorMatchAt_Opt(pos_4_instant, Color_4_instant) ; 1
    FrameStates["Wingstorm_Instant"] := IsColorMatchAt_Opt(pos_v, Color_v_instant) ; 2
    FrameStates["Mantra"] := IsColorMatchAt_Opt(pos_r_2, Color_r_2) ; 
    FrameStates["Rupture11"] := IsColorMatchAt_Opt(pos_f_11, Color_f_11)
    if (!FrameStates["Rupture11"]) {
        FrameStates["Rupture1"] := IsColorMatchAt_Opt(pos_f, Color_f)
    } else {
        FrameStates["Rupture1"] := false
    }
    
    ; === 降临状态（每500ms检测一次）===
    if (A_TickCount - lastSoulFlareCheck > 500) {
        FrameStates["Tab1"] := IsColorMatchAt_Opt(pos_tab, Color_tab)
        if (FrameStates["Tab1"]) {
            isSoulFlare := true
            FrameStates["Tab2"] := false
            FrameStates["Tab3"] := false
        } else {
            FrameStates["Tab2"] := IsColorMatchAt_Opt(pos_tab_2, Color_tab_2)
            if (FrameStates["Tab2"]) {
                isSoulFlare := true
                FrameStates["Tab3"] := false
            } else {
                FrameStates["Tab3"] := IsColorMatchAt_Opt(pos_tab_3, Color_tab_3)
                isSoulFlare := FrameStates["Tab3"]
            }
        }
        lastSoulFlareCheck := A_TickCount
    }
    
    ; === 掠夺CD（每300ms检测一次）===
    if (A_TickCount - lastLeechCDCheck > 300) {
        FrameStates["LeechDir11"] := IsColorMatchAt_Opt(pos_f_2_11, Color_f_2_11)
        if (!FrameStates["LeechDir11"]) {
            FrameStates["LeechDir1"] := IsColorMatchAt_Opt(pos_f_2, Color_f_2)
        } else {
            FrameStates["LeechDir1"] := false
        }
        lastLeechCDCheck := A_TickCount
    }
    
    ; === 掠夺状态（每400ms检测一次）===
    if (A_TickCount - lastLeechCheck > 400) {
        FrameStates["Leech1"] := IsColorMatchAt_Opt(pos_leech_1, Color_leech_1)
        if (FrameStates["Leech1"]) {
            isLeech := true
            FrameStates["Leech2"] := false
            FrameStates["Leech3"] := false
        } else {
            FrameStates["Leech2"] := IsColorMatchAt_Opt(pos_leech_2, Color_leech_2)
            if (FrameStates["Leech2"]) {
                isLeech := true
                FrameStates["Leech3"] := false
            } else {
                FrameStates["Leech3"] := IsColorMatchAt_Opt(pos_leech_3, Color_leech_3)
                isLeech := FrameStates["Leech3"]
            }
        }
        lastLeechCheck := A_TickCount
    }
}

UpdateAllStates_Old() {
    global FrameStates, isSoulFlare, isLeech

    ; Instant技能状态 - 独立检测（不需要短路）
    FrameStates["Dragoncall_Instant"] := IsColorMatchAt_Opt(pos_4_instant, Color_4_instant)
    FrameStates["Wingstorm_Instant"] := IsColorMatchAt_Opt(pos_v, Color_v_instant)

    ; 真言
    FrameStates["Mantra"] := IsColorMatchAt_Opt(pos_r_2, Color_r_2)
    
    ; 破裂cd - 短路检测
    FrameStates["Rupture11"] := IsColorMatchAt_Opt(pos_f_11, Color_f_11)
    if (!FrameStates["Rupture11"]) {
        FrameStates["Rupture1"] := IsColorMatchAt_Opt(pos_f, Color_f)
    } else{
        FrameStates["Rupture1"] := false
    }
    
    ; 降临状态 - 短路检测
    FrameStates["Tab1"] := IsColorMatchAt_Opt(pos_tab, Color_tab)
    if (FrameStates["Tab1"]) {
        isSoulFlare := true
        FrameStates["Tab2"] := false  ; 明确设置为false
        FrameStates["Tab3"] := false
    } else {
        FrameStates["Tab2"] := IsColorMatchAt_Opt(pos_tab_2, Color_tab_2)
        if (FrameStates["Tab2"]) {
            isSoulFlare := true
            FrameStates["Tab3"] := false
        } else {
            FrameStates["Tab3"] := IsColorMatchAt_Opt(pos_tab_3, Color_tab_3)
            isSoulFlare := FrameStates["Tab3"]
        }
    }
    
    
    
    ; 掠夺状态 - 短路检测
    FrameStates["Leech1"] := IsColorMatchAt_Opt(pos_leech_1, Color_leech_1)
    if (FrameStates["Leech1"]) {
        isLeech := true
        FrameStates["Leech2"] := false
        FrameStates["Leech3"] := false
    } else {
        FrameStates["Leech2"] := IsColorMatchAt_Opt(pos_leech_2, Color_leech_2)
        if (FrameStates["Leech2"]) {
            isLeech := true
            FrameStates["Leech3"] := false
        } else {
            FrameStates["Leech3"] := IsColorMatchAt_Opt(pos_leech_3, Color_leech_3)
            isLeech := FrameStates["Leech3"]
        }
    }
    
    
    
    ; 掠夺cd - 短路检测
    FrameStates["LeechDir11"] := IsColorMatchAt_Opt(pos_f_2_11, Color_f_2_11)
    if (!FrameStates["LeechDir11"]) {
        FrameStates["LeechDir1"] := IsColorMatchAt_Opt(pos_f_2, Color_f_2)
    }else{
        FrameStates["LeechDir1"] := false
    }
}

UpdateAllStates() {
    global FrameStates, isSoulFlare, isLeech
    
    ; 降临状态 - 检查3个点
    FrameStates["Tab1"] := IsColorMatchAt_Opt(pos_tab, Color_tab)
    FrameStates["Tab2"] := IsColorMatchAt_Opt(pos_tab_2, Color_tab_2)  
    FrameStates["Tab3"] := IsColorMatchAt_Opt(pos_tab_3, Color_tab_3)
    isSoulFlare := FrameStates["Tab1"] || FrameStates["Tab2"] || FrameStates["Tab3"]
    
    ; Instant技能状态
    FrameStates["Dragoncall_Instant"] := IsColorMatchAt_Opt(pos_4_instant, Color_4_instant)
    FrameStates["Wingstorm_Instant"] := IsColorMatchAt_Opt(pos_v, Color_v_instant)
    
    ; 掠夺状态 - 检查3个点
    FrameStates["Leech1"] := IsColorMatchAt_Opt(pos_leech_1, Color_leech_1)
    FrameStates["Leech2"] := IsColorMatchAt_Opt(pos_leech_2, Color_leech_2)
    FrameStates["Leech3"] := IsColorMatchAt_Opt(pos_leech_3, Color_leech_3)
    isLeech := FrameStates["Leech1"] || FrameStates["Leech2"] || FrameStates["Leech3"]
    
    ; 破裂相关状态
    FrameStates["Mantra"] := IsColorMatchAt_Opt(pos_r_2, Color_r_2)
    FrameStates["Rupture1"] := IsColorMatchAt_Opt(pos_f, Color_f)
    FrameStates["Rupture11"] := IsColorMatchAt_Opt(pos_f_11, Color_f_11)
    FrameStates["LeechDir1"] := IsColorMatchAt_Opt(pos_f_2, Color_f_2)
    FrameStates["LeechDir11"] := IsColorMatchAt_Opt(pos_f_2_11, Color_f_2_11)
}

IsLowFocus_Fast(number := 10) {
    if (number < 1 || number > 10)
        return false
    
    local p := focusTbl[number]
    local actC := PixelGetColor(p.x, p.y, "RGB")
    
    ; 计算参考颜色的亮度（ITU-R BT.709）
    local refL := ((p.c >> 16) & 0xFF) * 0.2126
               + ((p.c >> 8)  & 0xFF) * 0.7152
               + ( p.c        & 0xFF) * 0.0722
    
    ; 计算实际颜色的亮度
    local actL := ((actC >> 16) & 0xFF) * 0.2126
               + ((actC >> 8)  & 0xFF) * 0.7152
               + ( actC        & 0xFF) * 0.0722
    
    ; 比参考颜色暗表示内力不足
    return actL < refL
}


; ========== HUD 显示函数 ==========
ShowCombatHUD() {
    global showing, lastAction, isSoulFlare, isLeech, GCD, FrameStates
    global lastCPS, cpsHistory, bombRuptureComboStart, bombRuptureComboType
    global loopDuration, loopHistory, cnt
    global isDLL
    
    if (!showing)
        return
    
    ; 初始化循环时间历史记录
    static historyStartTime := 0
    
    ; 第一次调用时初始化
    if (historyStartTime = 0) {
        historyStartTime := A_TickCount
    }
    
    ; 添加当前循环时间到历史记录
    if (loopDuration > 0) {
        loopHistory.Push({time: A_TickCount, duration: loopDuration})
    }
    
    ; 移除30秒前的数据
    currentTime := A_TickCount
    while (loopHistory.Length > 0 && currentTime - loopHistory[1].time > 30000) {
        loopHistory.RemoveAt(1)
    }
    
    ; 计算统计信息
    avgLoopTime := 0
    minLoopTime := 0
    maxLoopTime := 0
    
    if (loopHistory.Length > 0) {
        total := 0
        minLoopTime := loopHistory[1].duration
        maxLoopTime := loopHistory[1].duration
        
        for _, record in loopHistory {
            total += record.duration
            if (record.duration < minLoopTime)
                minLoopTime := record.duration
            if (record.duration > maxLoopTime)
                maxLoopTime := record.duration
        }
        avgLoopTime := Round(total / loopHistory.Length)
    }
    
    ; 计算CPS
    avgCPS := 0
    if (cpsHistory.Length > 0) {
        total := 0
        for _, cps in cpsHistory {
            total += cps
        }
        avgCPS := Round(total / cpsHistory.Length, 1)
    }
    
    ; 详细的调试信息
    hudText := "=== 性能监控 ===`n"
    hudText .= (isDLL) ? "DLL: " (isDLL ? "Enable" : "Unable") "`n" : ""
    hudText .= "当前循环: " loopDuration "ms`n"
    hudText .= "平均循环: " avgLoopTime "ms (" loopHistory.Length " samples)`n"
    hudText .= "最低循环: " minLoopTime "ms`n"
    hudText .= "最高循环: " maxLoopTime "ms`n"
    hudText .= "循环延迟: " LOOP_DELAY_MS "ms`n"
    hudText .= "总间隔: " (loopDuration + LOOP_DELAY_MS) "ms`n"
    hudText .= "最后动作: " lastAction "`n"
    hudText .= "状态: " (isSoulFlare ? "降临" : (isLeech ? "掠夺" : "常规")) "`n"
    hudText .= "循环次数: " cnt "/s`n"

    hudText .= "`n=== 技能状态 ===`n"
    
    ; 暴魔灵
    local dragoncallReady := GCD.IsReady("Dragoncall_Instant")
    local dragoncallRemaining := GCD.GetRemaining("Dragoncall_Instant")
    hudText .= "暴魔灵: " (FrameStates["Dragoncall_Instant"] ? "可用" : "不可用")
    hudText .= " | GCD: " (dragoncallReady ? "就绪" : dragoncallRemaining "ms") "`n"
    
    ; 死灵突袭
    local wingstormReady := GCD.IsReady("Wingstorm_Instant")
    local wingstormRemaining := GCD.GetRemaining("Wingstorm_Instant")
    hudText .= "死灵突袭: " (FrameStates["Wingstorm_Instant"] ? "可用" : "不可用")
    hudText .= " | GCD: " (wingstormReady ? "就绪" : wingstormRemaining "ms") "`n"
    
    ; 显示在屏幕右上角
    ToolTip(hudText, A_ScreenWidth, A_ScreenHeight)
}

CheckBombRuptureCombo() {
    global bombRuptureComboStart, bombRuptureComboType, GCD, cnt, lastAction, FrameStates
    
    if (bombRuptureComboStart > 0 && bombRuptureComboType = "Bombardment_Normal" && !(isLeech || isSoulFlare)) {
        local expectedGCDEnd := bombRuptureComboStart + GCDManager.SKILL_GCD_TIMES["Bombardment_Normal"]
        
        if (A_TickCount >= expectedGCDEnd) {
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

CheckInstantSkills() {
    global GCD, cnt, lastAction, FrameStates
    
    ; 暴魔灵检查 - 简化条件，只检查就绪状态和技能状态
    if (FrameStates["Dragoncall_Instant"] && GCD.IsReady("Dragoncall_Instant")) {
        Send '4'
        GCD.SetGCD("Dragoncall_Instant")
        cnt++
        lastAction := "Instant-4"
        CheckMainGCDSkills()
        return true
    }
    
    ; 死灵突袭检查
    if (FrameStates["Wingstorm_Instant"] && GCD.IsReady("Wingstorm_Instant")) {
        Send 'v'
        GCD.SetGCD("Wingstorm_Instant")
        cnt++
        lastAction := "Instant-v"
        CheckMainGCDSkills()
        return true
    }
    
    return false
}

CheckFocusRecovery() {
    global isSoulFlare, isLeech, GCD, cnt, lastAction, FrameStates
    
    ; 强制内力恢复（内力极低时）
    if (IsLowFocus_Fast(3) && !isSoulFlare) {
        Send 'r'
        ; Sleep DELAY_MANTRA
        if (GCD.IsReady("R")) {
            GCD.SetGCD("R")
        }
        cnt++
        lastAction := "Force R"
        return true
    }
    
    ; 正常内力恢复
    local mantraThreshold := isSoulFlare ? MANTRA_FOCUS_SF : (isLeech ? MANTRA_FOCUS_LEECH : MANTRA_FOCUS_NORMAL)
    local ruptureThreshold := isSoulFlare ? RUPTURE_FOCUS_SF : (isLeech ? RUPTURE_FOCUS_LEECH : RUPTURE_FOCUS_NORMAL)
    
    if (IsLowFocus_Fast(mantraThreshold) && GCD.IsReady("Mantra") && FrameStates["Mantra"]) {
        Send 'r'
        ; Sleep DELAY_MANTRA
        GCD.SetGCD("Mantra")
        cnt++
        lastAction := "Mantra"
        return true
    }
    
    if (IsLowFocus_Fast(ruptureThreshold) && GCD.IsReady("Rupture") && (FrameStates["Rupture11"] || FrameStates["Rupture1"])) {
        Send 'f'
        ; Sleep DELAY_RUPTURE
        GCD.SetGCD("Rupture")
        cnt++
        lastAction := "Rupture"
        return true
    }
    
    return false
}

CheckMainGCDSkills() {
    global isSoulFlare, isLeech, GCD, cnt, lastAction, FrameStates
    global bombRuptureComboStart, bombRuptureComboType
    
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
    if (GCD.IsReady(bombardmentType)) {
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
        return true
    }
    
    return false
}

