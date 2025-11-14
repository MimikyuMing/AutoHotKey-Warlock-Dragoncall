#Requires AutoHotkey v2.0


CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

; ========== 初始化 ==========
global running := false
global holding := false  
global showing := true
global cnt := 0
global lastCPS := 0
global cpsHistory := []
global isTest := false  ; 添加默认值
global isDLL := false   ; 添加DLL开关
global FrameStates

; ========== 按正确顺序包含文件 ==========

; 1. 首先包含配置和参数文件
#Include lib/Param/Config.ahk
#Include lib/Param/ToggleKey.ahk

; 2. 包含工具类（Tools.ahk应该在ColorPick.ahk之前）
#Include lib/Tools/Tools.ahk
#Include lib/Tools/CPSTimer.ahk

; 3. 包含颜色和位置定义
#Include lib/Param/ColorPick.ahk

; 4. 包含GCD管理器
#Include lib/Tools/GCDManager.ahk

; 5. 包含状态检测（这里声明 FrameStates）
#Include lib/CheckState.ahk

; 5. 最后包含主逻辑（依赖前面所有的配置和工具）
#Include lib/MainLoop.ahk

; ========== 初始化GCD管理器 ==========
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

; ---------- 副使用 ----------
Hotkey HOLD_KEY_2, Toggle_SS
Toggle_SS(*){
    if (!running)      ; 宏总开关
        return
    if (isTest)
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

; ---------- 主使用 ----------
Hotkey HOLD_KEY_1, HoldDown 
Hotkey HOLD_KEY_1 " up", HoldUp

HoldDown(*) {
    if !running
        return
    global holding
    holding := true

    if (isTest){
        while (holding) {
            CombatLoopIteration_Test()  ; 调用优化后的单次循环
            Sleep -1  ; 最高效地让出CPU时间片
        }
    }else{
        ; 直接在while循环中调用单次迭代函数
        while (holding) {
            CombatLoopIteration()  ; 调用优化后的单次循环
            Sleep -1  ; 最高效地让出CPU时间片
        }
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

; ----------开启DLL-----------
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

