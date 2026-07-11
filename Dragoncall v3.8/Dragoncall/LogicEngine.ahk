#Requires AutoHotkey v2.0


#Include ../Lib/HiResTimer.ahk
#Include ../Lib/LogicRunner.ahk
#Include DragoncallMutex.ahk
#Include CaptureEngine.ahk

class LogicEngine extends LogicRunner {
    ; 覆盖 mutex 为游戏专用类型
    static g_Mutex := DragoncallMutex()

    ; 游戏配置
    static g_Gold_Wingstorm := false
    static g_Gold_Open := false
    static g_AutoSoulFlare := false
    static g_isUseLeechHasLeechBuff := false
    static g_limitationOpen := false
    static g_limitationLeech := false
    static g_Gold_Leech := false
    static FrameCount := 5
    static delayTab := 0
    static lastUsedOpen := -1
    static WRITELOG := false

    ; ---------- 实现抽象方法 ----------
    static _MainLogic() {
        start := HiResTimer.GetTick()
        static lastUsedBombardment := -1
        static lastUsedLeech := -1
        static lastUsedD := -1
        static lastUsedW := -1
        ; 帧级幂等
        if (this.lastFrameId == CaptureEngine.frameId)
            return
        this.lastFrameId := CaptureEngine.frameId
        try {
            this.g_Mutex.BeginFrame()
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            hasLeechBuff := StateManager._buffState.Get("Leech", false)

            if (this.g_Mutex.IsInSleep()) {
                if(this._HandleSleepState()){
                    return
                }
            }

            ; Action5 : Open
            OpenReady := StateManager._skillState.Get("Open_R", false)
            

            openDragonState := this.g_limitationOpen
                ? StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)
                : true
            local BombardmentPreInput := 200
            local LeechDisableWindow := 800 + 750 ; 1400 ms 0.8s前摇 + 0.75s 禁用期
            ; 伏压下 -1s 暴击 -1s total = 1 + C(48.98% + 24%) * 1 ≈ 1.7298s (C为暴击率)
            ; 超神下 -3s total = 3 
            local OpenTiming := 3000 ; 最大窗口期

            open_condition := this.g_Gold_Open && OpenReady && hasLeechBuff && openDragonState && ((BombardmentPreInput >= HiResTimer.DeltaMs(lastUsedBombardment, HiResTimer.GetTick())) || (LeechDisableWindow >= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()))) && (OpenTiming >= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()))
            if (this.g_Mutex.CanExecute(5) && open_condition) {
                SendInput "3"
                this.g_Mutex.OnExecuted(5)
                ; this.writeLogEvent("3", start)
                this.lastUsedOpen := HiResTimer.GetTick()
                return
            }

            

            ; Action2 - Soulflare
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)
            delaySoulFlare := this.g_Gold_Leech
            if (this.g_Mutex.CanExecute(2) && soulFlareReady) {
                if(delaySoulFlare){
                    if(this.g_Mutex.isSFirst && this.delayTab == 0){
                        ; ToolTip "????" , 0 , 0
                        this.delayTab := SetTimer(() => 
                            this.DelaySendTab()
                        , -2000)
                    }
                }else
                    this.DelaySendTab()
            }

            ; Action1 : Dragoncall & Wingstorm
            wingstormReady := this.g_Gold_Wingstorm
                ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
                : StateManager._skillState.Get("Wingstorm_R", false)
            dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)
            local D_Limit := 300
            local LeechAfterBanWingstorm := 800 + 350
            local OpenAfterBanWingstorm := 600
            local allow_use_W := 
                D_Limit <= HiResTimer.DeltaMs(lastUsedD, HiResTimer.GetTick()) && 
                (
                    LeechAfterBanWingstorm <= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()) 
                && 
                    OpenAfterBanWingstorm <= HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick())
                )  ; 掠夺之后0.8(前摇) + 0.35s内不能用,以保证首次使用必须是暴魔灵,并且开门使用后的0.6s内不能用,以确保首次使用的是暴魔灵
            if (this.g_Mutex.CanExecute(1)) {
                if (dragoncallReady) {
                    SendInput "4"
                    this.g_Mutex.OnExecuted(1)
                    this.writeLogEvent("4", start)
                    lastUsedD := HiResTimer.GetTick()
                } else if (wingstormReady && allow_use_W) {
                    SendInput "v"
                    this.g_Mutex.OnExecuted(1)
                    this.writeLogEvent("v", start)
                    lastUsedW := HiResTimer.GetTick()
                }
            }

            ; Action3 : Leech
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false) ; 改成Leech Dark的RGB
            LeechReady := StateManager._skillState.Get("Leech_R", false)
            leech_condition := this.g_limitationLeech
                ? StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)
                : true
            allowLeech := false
            if (this.g_Mutex.CanExecute(3) && preLeech) {
                if (hasSoulFlareBuff) {
                    if (!hasLeechBuff)
                        allowLeech := true
                } else if (!hasSoulFlareBuff) {
                    if (!hasLeechBuff)
                        allowLeech := true
                    else if (this.g_isUseLeechHasLeechBuff && leech_condition)
                        allowLeech := true
                }
                if (allowLeech) {
                    if (LeechReady) {
                        SendInput "f"
                        lastUsedLeech := HiResTimer.GetTick()
                        this.g_Mutex.OnExecuted(3)
                        this.writeLogEvent("f", start)
                    } else {
                        return
                    }
                }
            }

            ; Action4 - Mantra/Rupture/Bombardment
            if (this.g_Mutex.CanExecute(4)) {
                MantraReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 4 : 5)) && StateManager._skillState.Get("Mantra_L", false)
                RuptureReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 4 : 4)) && StateManager._skillState.Get("Rupture_L", false)
                BombardmentReady := StateManager._skillState.Get("RealBombardment_R", false) || StateManager._skillState.Get("Bombardment_R", false)
                BombardmentReady := true
                if (MantraReady) {
                    SendInput "r"
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("r", start)
                } else if (RuptureReady) {
                    SendInput "f"
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("f", start)
                } else if (BombardmentReady) { 
                    SendInput "t"
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("t", start)
                    lastUsedBombardment := HiResTimer.GetTick()
                }
            }
        } finally {
            ; ToolTip this.g_Mutex.CurrentSleepType() , 0 , 0
            this.g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
        }
    }

    static _HandleSleepState() {
        if (this.g_Mutex.CurrentSleepType() == 1) { ; Open Sleep
            OpenReady := StateManager._skillState.Get("Open_R", false)
            openBlackReady := this.g_Gold_Open && !StateManager._skillState.Get("Open_Black", false) && !OpenReady
            expire := this.g_Mutex.CurrentSleepExpire()   ; 取当前 Open 的过期时间
            if (OpenReady) {
                MaxOvertime := Floor(this.g_Mutex.openSleepTime * (1/3))
                if (MaxOvertime <= HiResTimer.DeltaMs(expire, HiResTimer.GetTick())) {
                    msg := "[Open-Ready] Overtime! curOvertime: " HiResTimer.DeltaMs(expire, HiResTimer.GetTick()) " curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    this.lastUsedOpen := -1 ; 物理使用失败,移除限制
                    this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                    OutputDebug "Open多帧判断均在亮起,说明没有物理按下," HiResTimer.Now()
                    return false
                } else if (this.g_Mutex.IsInSleep()) {
                    msg := "[Open-Ready] Sleeping! curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    OutputDebug "Open多帧判断是否亮起中,正在sleep," HiResTimer.Now()
                    return true
                }
                msg := "[Open-Ready] Error! curtimestamp:" HiResTimer.GetTick()
                KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                OutputDebug "Open多帧判断异常错误!!!!," HiResTimer.Now()
                return false
            } else if (openBlackReady) {
                if (this.g_Mutex.IsInSleep()) {
                    msg := "[Open-Blank] Sleeping! curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    OutputDebug "Open物理按下/GCD空转中,正在sleep," HiResTimer.Now()
                    return true
                } else {
                    msg := "[Open-Ready] Don't Sleep!Releasing! curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                    OutputDebug "Open物理按下/GCD空转中,不处于Sleep,释放Sleep条件," HiResTimer.Now()
                    return false
                }
            } else {
                msg := "[Open] OpenReadyNotExist And OpenBlankNotExist Releasing! curtimestamp:" HiResTimer.GetTick()
                KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                OutputDebug "均读取不到Open亮起/暗淡状态!!!!," HiResTimer.Now()
                ; 不释放睡眠，保持阻塞等待下一帧
                this.lastUsedOpen := -1 ; 异常状态,移除限制
                return true
            }
        } else if (this.g_Mutex.CurrentSleepType() == 2) { ; Soulflare Sleep
            msg := "[Soulflare] Soulflare Sleep! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            OutputDebug "超神睡眠状态中," HiResTimer.Now()
            return true
        } else if (this.g_Mutex.CurrentSleepType() == 3) { ; Leech Sleep
            msg := "[Leech] Leech Sleep! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            OutputDebug "掠夺睡眠状态中," HiResTimer.Now()
            return true
        } 
        else if(this.g_Mutex.CurrentSleepType() == 5){ ; X Sleep
            msg := "[X] X Sleep! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            OutputDebug "X睡眠状态中," HiResTimer.Now()
            return true
        }
        else {
            msg := "[Unknown] Unknown sleep type! Release Data! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            this.g_Mutex.ReleaseSleep()                   ; 未知类型直接清空，确保安全
            OutputDebug "未知异常," HiResTimer.Now()
            return false
        }
    }

    ; 辅助方法
    static DelaySendTab() {
        if (this.g_Mutex.CanExecute(2) && this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)) {
            SendInput "{tab}"
            this.g_Mutex.OnExecuted(2)
            this.writeLogEvent("tab", HiResTimer.GetTick())
        }
        this.g_Mutex.isSFirst := false
        this.delayTab := 0
    }
    static writeLogEvent(str, start) {
        if (!this.WRITELOG)
            return
        if (this.g_Mutex.thisFrameAct != 0)
            Log.Write("[MainLogic] curFrame:" CaptureEngine.frameId " keybroad:" str " action:" this.g_Mutex.thisFrameAct "," Round(HiResTimer.DeltaMs(this.startLogic, start), 2) " ms")
    }
}