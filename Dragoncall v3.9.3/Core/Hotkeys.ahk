#Requires AutoHotkey v2.0

#Include LogicEngine.ahk

; 侧键按下启动逻辑
$*XButton2:: {
    if (App.ctx.state.logicEnabled)
        return
    App.ctx.state.logicEnabled := true
    LogicEngine.ScheduleNextLogic()
}

; 侧键松开停止逻辑
$*XButton2 Up:: {
    App.ctx.state.logicEnabled := false
    SetTimer ObjBindMethod(LogicEngine, "LogicExecuter"), 0
    App.ctx.mutex.ReleaseSleep()
    LogicEngine.g_LogicTimerPending := false
}

; 鼠标侧键1模拟组合键
$*XButton1:: {
    SendInput '^{Numpad9}'
}

; 烙印触发时间记录（技能X）
~$X:: {
    TetherBladeReady := StateManager._skillState.Get("TetherBlade", false)
    if (TetherBladeReady) {
        App.ctx.mutex.SetSleep(5, App.ctx.mutex.xSleepTime)
        if (App.ctx.state.BrandTriggerTime <= HiResTimer.GetTick()) {
            App.ctx.state.BrandTriggerTime := HiResTimer.GetTick()
            temp := HiResTimer.AddMs(4 * 1000, App.ctx.state.BrandTriggerTime)
            if (temp >= App.ctx.state.BrandOverTime) {
                App.ctx.state.BrandOverTime := temp
            }
        }
    }
}

; 烙印触发时间记录（技能2）
~$2:: {
    SoulShackleReady := StateManager._skillState.Get("SoulShackle", false)
    if (SoulShackleReady) {
        if (App.ctx.state.BrandTriggerTime <= HiResTimer.GetTick()) {
            App.ctx.state.BrandTriggerTime := HiResTimer.GetTick()
            temp := HiResTimer.AddMs(8 * 1000, App.ctx.state.BrandTriggerTime)
            if (temp >= App.ctx.state.BrandOverTime) {
                App.ctx.state.BrandOverTime := temp
            }
        }
    }
}

; 重启
F11:: {
    App.Cleanup()
    Reload
}

; 手动 Leech 记录
~$F:: {
    LeechReady := StateManager._skillState.Get("Leech_R", false)
    if (LeechReady) {
        App.ctx.state.lastUsedLeech := HiResTimer.GetTick()
        App.ctx.mutex.OnExecuted(3)
    }
}

; 手动 SoulFlare 记录
~$Tab:: {
    soulFlareReady := StateManager._skillState.Get("SoulFlare", false)
    if (soulFlareReady) {
        App.ctx.mutex.OnExecuted(2)
        SetTimer ObjBindMethod(LogicEngine, "SetMarkToFalse", App.ctx), -500
    }
}

; 手动 Open 记录
~$3:: {
    OpenReady := StateManager._skillState.Get("Open_R", false)
    if (OpenReady) {
        App.ctx.mutex.OnExecuted(5)
        App.ctx.state.lastUsedOpen := HiResTimer.GetTick()
    }
}