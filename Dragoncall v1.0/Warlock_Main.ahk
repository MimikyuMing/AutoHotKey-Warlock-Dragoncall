#Requires AutoHotkey v2.0
#Include lib/Warlock_Dc_MainLoop.ahk
#Include lib/ToggleKey.ahk
#Include lib/Config.ahk

CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

; ========== 初始化 ==========
global running := false
global holding := false  
global showing := true
global cnt := 0
global lastCPS := 0
global cpsHistory := []

; 初始化 GCD 管理器（如果还没有的话）
global GCD := GCDManager()

; ---------- 启动/停止宏 ----------
Hotkey TOGGLE_KEY, ToggleRunning
ToggleRunning(*){
    global running, text
    running := !running
    text := running ? "宏已启动" : "宏已停止"
    CoordMode("ToolTip", "Screen")
    
    if (running) {
        ToolTip(text, 0, 0)
        StartCPSTimer()  ; 启动 CPS 计时器
    } else {
        ToolTip("")
        StopCPSTimer()   ; 停止 CPS 计时器
    }
}

; ---------- ss ----------
Hotkey HOLD_KEY_2, Toggle_SS
Toggle_SS(*){
    if (!running)      ; 宏总开关
        return
    ; 点火异步线程，主线程立即返回
    SetTimer(SS_Timer, -1)   ; -1 表示“执行一次后自动关闭”
}

global SS_RUNNING := false   ; 线程锁，防止连按重复启动

; -------------- 异步 SS 计时器函数 --------------
SS_Timer(*) {
    Send 's'
    Sleep 75
    Send 's'
}

; ---------- 卡刀 ----------
Hotkey HOLD_KEY_1, HoldDown
Hotkey HOLD_KEY_1 " up", HoldUp

HoldDown(*) {
    if !running
        return
    global holding
    holding := true
    
    ; 直接在while循环中调用单次迭代函数
    while (holding) {
        CombatLoopIteration()  ; 调用优化后的单次循环
        Sleep -1  ; 最高效地让出CPU时间片
    }
}

HoldUp(*) {
    if !running
        return
    global holding
    holding := false
    ToolTip("")  ; 清除HUD
}

; ---------- 显示鼠标位置和颜色 ----------
Hotkey SHOW_MOUSEPOS_KEY, ShowMousePos
ShowMousePos(*) {
    pos := GetMousePosXY()
    color := GetPixelColorAt(pos.x, pos.y).hex
    ToolTip("鼠标 X: " pos.x "  Y: " pos.y " color: " color, 0, 0)
    ; 60 秒后隐藏
    SetTimer(ToggleRunning, 0, -60000)
}

; ----------开启HUB标记-----------
Hotkey SHOW_MOUSEPOS_KEY3,isShow
isShow(*){
    global showing
    showing := !showing
}

; 
Hotkey SHOW_DLL_KEY4, isEnableDLL
isEnableDLL(*){
    global isDLL
    isDLL := !isDLL
}


; ---------- 重载脚本 ----------
Hotkey RELOAD_KEY, ReloadScript
ReloadScript(*){
    Reload
}

; ---------- CPS 重置计时器 ----------
global cpsResetTimer := 0

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