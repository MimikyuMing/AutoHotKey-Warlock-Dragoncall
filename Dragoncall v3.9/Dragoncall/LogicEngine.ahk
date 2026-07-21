#Requires AutoHotkey v2.0


#Include ../Lib/HiResTimer.ahk
#Include ../Lib/LogicRunner.ahk
#Include DragoncallMutex.ahk
#Include CaptureEngine.ahk
#Include ..\Lib\PerformanceMonitor.ahk

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
    static g_enablePriorityUseDragoncall := 0

    ; ---------- 实现抽象方法 ----------
    static _MainLogic() {
        PerformanceMonitor.Start("MainLogic")
        start := HiResTimer.GetTick()
        static lastUsedBombardment := -1
        static lastUsedLeech := -1
        static lastUsedD := -1
        static lastUsedW := -1

        ; 帧级幂等
        if (this.lastFrameId == CaptureEngine.frameId) {
            PerformanceMonitor.End("MainLogic")   ; 提前退出也需结束计时
            return
        }
        this.lastFrameId := CaptureEngine.frameId

        try {
            ; ---------- 1. 开始帧 ----------
            PerformanceMonitor.Start("BeginFrame")
            this.g_Mutex.BeginFrame()
            PerformanceMonitor.End("BeginFrame")

            ; ---------- 2. 基础 Buff 查询 ----------
            PerformanceMonitor.Start("BuffQuery")
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            hasLeechBuff      := StateManager._buffState.Get("Leech", false)
            PerformanceMonitor.End("BuffQuery")

            ; ---------- 3. 睡眠检查 ----------
            PerformanceMonitor.Start("IsInSleep")
            if (this.g_Mutex.IsInSleep()) {
                if (this._HandleSleepState()) {
                    PerformanceMonitor.End("IsInSleep")
                    return
                }
            }
            PerformanceMonitor.End("IsInSleep")

            ; ---------- 4. Action5 : Open 开门 ----------
            PerformanceMonitor.Start("OpenCondition")
            OpenReady := StateManager._skillState.Get("Open_R", false)
            criticalDragoncallReady := this.g_enablePriorityUseDragoncall ? StateManager._skillState.Get("Critical_Dragoncall", false) : false
            openDragonState := this.g_limitationOpen
                ? (
                    (StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)) 
                    && !criticalDragoncallReady
                )
                : true
            local BombardmentPreInput := 200
            local LeechDisableWindow := 800 + 750
            local OpenTiming := 3000

            deltaBombardment := HiResTimer.DeltaMs(lastUsedBombardment, HiResTimer.GetTick())
            deltaLeech       := HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick())

            bombardmentWindow := (deltaBombardment <= BombardmentPreInput)
            leechWindowMin    := (deltaLeech >= LeechDisableWindow)
            leechWindowMax    := (deltaLeech <= OpenTiming)
            leechWindow       := leechWindowMin && leechWindowMax

            open_condition := this.g_Gold_Open 
                        && OpenReady 
                        && hasLeechBuff 
                        && openDragonState 
                        && (bombardmentWindow && leechWindow)
            PerformanceMonitor.End("OpenCondition")

            if (this.g_Mutex.CanExecute(5) && open_condition) {
                PerformanceMonitor.Start("SendOpen")
                this.SendKey("3")
                this.g_Mutex.OnExecuted(5)
                this.lastUsedOpen := HiResTimer.GetTick()
                PerformanceMonitor.End("SendOpen")
                return
            }

            ; ---------- 5. Action2 : Soulflare 超神 ----------
            PerformanceMonitor.Start("SoulflareCondition")
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)
            delaySoulFlare := this.g_Gold_Leech
            PerformanceMonitor.End("SoulflareCondition")

            if (this.g_Mutex.CanExecute(2) && soulFlareReady) {
                if (delaySoulFlare) {
                    if (this.g_Mutex.isSFirst && this.delayTab == 0) {
                        PerformanceMonitor.Start("DelayTabSet")
                        this.delayTab := SetTimer(() => this.DelaySendTab(), -2000)
                        PerformanceMonitor.End("DelayTabSet")
                    }
                } else {
                    PerformanceMonitor.Start("SendSoulflare")
                    this.DelaySendTab()
                    PerformanceMonitor.End("SendSoulflare")
                }
            }

            ; ---------- 6. Action1 : Dragoncall & Wingstorm ----------
            PerformanceMonitor.Start("Action1")
            wingstormReady := this.g_Gold_Wingstorm
                ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
                : StateManager._skillState.Get("Wingstorm_R", false)
            dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)
            criticalDragoncallReady := criticalDragoncallReady := this.g_enablePriorityUseDragoncall ? StateManager._skillState.Get("Critical_Dragoncall", false) : false

            local D_Limit := 300
            local LeechAfterBanWingstorm := 800 + 350
            local OpenAfterBanWingstorm := 600
            local allow_use_W := 
                    !criticalDragoncallReady &&
                    D_Limit <= HiResTimer.DeltaMs(lastUsedD, HiResTimer.GetTick()) && 
                    (LeechAfterBanWingstorm <= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()) 
                    && OpenAfterBanWingstorm <= HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick()))

            if (this.g_Mutex.CanExecute(1)) {
                if (dragoncallReady) {
                    PerformanceMonitor.Start("SendDragoncall")
                    this.SendKey("4")
                    this.g_Mutex.OnExecuted(1)
                    this.writeLogEvent("4", HiResTimer.GetTick())
                    lastUsedD := HiResTimer.GetTick()
                    PerformanceMonitor.End("SendDragoncall")
                } else if (wingstormReady && allow_use_W) {
                    PerformanceMonitor.Start("SendWingstorm")
                    this.SendKey("v")
                    this.g_Mutex.OnExecuted(1)
                    this.writeLogEvent("v", HiResTimer.GetTick())
                    lastUsedW := HiResTimer.GetTick()
                    PerformanceMonitor.End("SendWingstorm")
                }
            }
            PerformanceMonitor.End("Action1")

            ; ---------- 7. Action3 : Leech 掠夺 ----------
            PerformanceMonitor.Start("Action3")
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
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
                        PerformanceMonitor.Start("SendLeech")
                        this.SendKey("f")
                        lastUsedLeech := HiResTimer.GetTick()
                        this.g_Mutex.OnExecuted(3)
                        this.writeLogEvent("f", HiResTimer.GetTick())
                        PerformanceMonitor.End("SendLeech")
                    } else {
                        PerformanceMonitor.End("Action3")
                        return
                    }
                }
            }
            PerformanceMonitor.End("Action3")

            ; ---------- 8. Action4 : Mantra/Rupture/Bombardment ----------
            PerformanceMonitor.Start("Action4")
            if (this.g_Mutex.CanExecute(4)) {
                MantraReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 3 : 4)) 
                            && StateManager._skillState.Get("Mantra_L", false)
                RuptureReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 4 : 4)) 
                            && StateManager._skillState.Get("Rupture_L", false)
                BombardmentReady := StateManager._skillState.Get("RealBombardment_R", false) 
                                || StateManager._skillState.Get("Bombardment_R", false)
                BombardmentReady := true

                if (MantraReady) {
                    PerformanceMonitor.Start("SendMantra")
                    this.SendKey("r")
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("r", HiResTimer.GetTick())
                    PerformanceMonitor.End("SendMantra")
                } else if (RuptureReady) {
                    PerformanceMonitor.Start("SendRupture")
                    this.SendKey("f")
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("f", HiResTimer.GetTick())
                    PerformanceMonitor.End("SendRupture")
                } else if (BombardmentReady) { 
                    PerformanceMonitor.Start("SendBombardment")
                    this.SendKey("t")
                    this.g_Mutex.OnExecuted(4)
                    lastUsedBombardment := HiResTimer.GetTick()
                    this.writeLogEvent("t", lastUsedBombardment)
                    PerformanceMonitor.End("SendBombardment")
                }
            }
            PerformanceMonitor.End("Action4")

        } finally {
            this.g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
            PerformanceMonitor.End("MainLogic")
        }
    }

    static _HandleSleepState() {
        PerformanceMonitor.Start("HandleSleep")
        try{
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
        }finally{
            PerformanceMonitor.End("HandleSleep")
        }
    }

    ; 辅助方法
    static DelaySendTab() {
        if (this.g_Mutex.CanExecute(2) && this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)) {
            this.SendKey("E")
            this.SendKey("{tab}")
            this.g_Mutex.OnExecuted(2)
            this.writeLogEvent("tab", HiResTimer.GetTick())
        }
        this.g_Mutex.isSFirst := false
        this.delayTab := 0
    }
    static writeLogEvent(str, start) {
        ; 不再需要 if (!this.WRITELOG) return
        if (this.g_Mutex.thisFrameAct != 0)
            Log.Write("[MainLogic] curFrame:" CaptureEngine.frameId " keybroad:" str " action:" this.g_Mutex.thisFrameAct "," Round(HiResTimer.DeltaMs(this.startLogic, start), 2) " ms")
    }
}