#Requires AutoHotkey v2.0

#Include ../RunningStatus.ahk
#Include ../Gui.ahk
#Include ../Timer.ahk


InitHotKeys(){
    global StartOrStopKey, ToggleKey, DoggeKey, ShowOrHideKey, ReloadKey
    StartOrStopKey := '^F11' ; isRunning 切换热键
    ToggleKey := 'XButton2' ; isHolding 热键
    DoggeKey := 'XButton1'
    ShowOrHideKey := '^F3'  ; isShowing 切换热键
    ReloadKey := '^F5'
}

InitHotKeys()
InitRunningStatus()
; 热键绑定

Hotkey StartOrStopKey, Running

Running(*) {
    global RunningStatus    
    RunningStatus['isRunning'] := !RunningStatus['isRunning']
    if (RunningStatus['isRunning']) {
        RunningStatus['isShowing'] := true
        ; 1. 启动状态检测定时器
        StartCheckTimer()
        StartGuiTimer()
        ShowOrHideGui()
        ToolTip("宏已启动", 0, 0)
        SetTimer(() => ToolTip(), 2000)
    } else {
        RunningStatus['isHolding'] := false
        RunningStatus['isShowing'] := false
        StopCheckTimer()
        StopGuiTimer()
        ShowOrHideGui()
        ToolTip("宏已停止", 0, 0)
        SetTimer(() => ToolTip(), 2000)
    }
}

Hotkey ToggleKey, CombatStart
CombatStart(*){
    ; 1. 启动逻辑定时器
    if (RunningStatus['isRunning']) 
        StartExecuteTimer()
}


Hotkey ToggleKey " up", CombatStop
CombatStop(*){
    if (RunningStatus['isRunning']) 
        StopExecuteTimer()
}

Hotkey DoggeKey, Dogge
Dogge(*){
    if (RunningStatus['isRunning']){
        SetTimer(DoggeProxy.Bind(),-1, 15)
    }
}

DoggeProxy(){
    Send 's'
    Sleep 75
    Send 's'
}

Hotkey ReloadKey, ReloadScript, "P10"
ReloadScript(*){
    Reload
}

Hotkey ShowOrHideKey, ShowOrHideGui, "P8"
ShowOrHideGui(*){
    RunningStatus['isShowing'] := !RunningStatus['isShowing']
    UpdateGui()
}