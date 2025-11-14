#Requires AutoHotkey v2.0

#Include Param\ColorPick.ahk
#Include Param\Config.ahk
#Include Tools\GCDManager.ahk
#Include CheckState.ahk
#Include Tools\CPSTimer.ahk

; ========== 初始化 ==========
global isSoulFlare := 0, isLeech := 0, cnt := 0
global lastAction := "Idle"
global loopHistory := []
global maxHistorySize := 150  ; 30秒数据
global isSoulFlare, isLeech, cnt, lastAction
global bombRuptureComboStart := 0
global bombRuptureComboType := ""  
global loopStartTime := A_TickCount
global loopDuration := A_TickCount
global isDLL

; 初始化 GCD 管理器（如果还没有的话）
global GCD := GCDManager()

; ========== HUD 显示函数 ==========
ShowCombatHUD() {
    ; global showing, lastAction, isSoulFlare, isLeech, GCD, FrameStates
    ; global lastCPS, cpsHistory, bombRuptureComboStart, bombRuptureComboType
    ; global loopDuration, loopHistory, cnt
    ; global isDLL
    
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
    hudText := "=== 性能监控" (isTest ? "(Test)" : "") " ===`n"
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