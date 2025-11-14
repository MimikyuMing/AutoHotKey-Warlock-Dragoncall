#Requires AutoHotkey v2.0

; ---------- CPS 重置计时器 ----------
global cpsResetTimer := 0

; ========== HUD 统计变量 ==========
global lastCPS := 0          ; 每秒计数
global cpsHistory := []      ; CPS 历史记录（用于计算平均值）
global MAX_CPS_HISTORY := 10 ; 保留最近10秒的数据

; 启动 CPS 计时器
StartCPSTimer() {
    SetTimer(ResetCPS, 1000)  ; 每秒执行一次
}

; 停止 CPS 计时器
StopCPSTimer() {
    SetTimer(ResetCPS, 0)
}

; 重置 CPS 计数
ResetCPS() {
    global cnt, lastCPS, cpsHistory, MAX_CPS_HISTORY
    
    lastCPS := cnt  ; 记录这一秒的计数
    
    ; 添加到历史记录
    cpsHistory.Push(lastCPS)
    if (cpsHistory.Length > MAX_CPS_HISTORY) {
        cpsHistory.RemoveAt(1)
    }
    
    cnt := 0  ; 重置计数器
}
