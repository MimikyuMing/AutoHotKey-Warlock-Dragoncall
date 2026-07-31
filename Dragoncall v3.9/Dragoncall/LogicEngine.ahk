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
    static lastUsedLeech := -1
    static lastUsedMantra := -1

    ; ---------- 实现抽象方法 ----------
    static _MainLogic() {
        PerformanceMonitor.Start("LogEngine-MainLogic")
        start := HiResTimer.GetTick()
        static lastUsedBombardment := -1
        static lastUsedD := -1
        static lastUsedW := -1
        ; 帧级幂等
        if (this.lastFrameId == CaptureEngine.frameId) {
            PerformanceMonitor.End("LogEngine-MainLogic")   ; 提前退出也需结束计时
            return
        }
        this.lastFrameId := CaptureEngine.frameId

        try {
            ; ---------- 1. 开始帧 ----------
            this.g_Mutex.BeginFrame()

            ; ---------- 2. 基础 Buff 查询 ----------
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            hasLeechBuff      := StateManager._buffState.Get("Leech", false)

            ; ---------- 3. 睡眠检查 ----------
            if (this.g_Mutex.IsInSleep()) {
                if (this._HandleSleepState()) {
                    return
                }
            }

            ; ---------- 4. Action5 : Open 开门 ----------
            OpenReady := StateManager._skillState.Get("Open_R", false)
            criticalDragoncallReady := this.g_enablePriorityUseDragoncall ? StateManager._skillState.Get("Critical_Dragoncall", false) : false
            openDragonState := this.g_limitationOpen
                ? (
                    (StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)) 
                    && !criticalDragoncallReady
                )
                : true
            local BombardmentPreInput := 200
            local LeechDisableWindow := 800 + 500
            local OpenTiming := 3000

            deltaBombardment := HiResTimer.DeltaMs(lastUsedBombardment, HiResTimer.GetTick())
            deltaLeech       := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick())

            bombardmentWindow := (deltaBombardment <= BombardmentPreInput)
            leechWindowMin    := (deltaLeech >= LeechDisableWindow)
            leechWindowMax    := (deltaLeech <= OpenTiming)
            leechWindow       := leechWindowMin && leechWindowMax

            open_condition := this.g_Gold_Open 
                        && OpenReady 
                        && hasLeechBuff 
                        && openDragonState 
                        && (bombardmentWindow && leechWindow)

            if (this.g_Mutex.CanExecute(5) && open_condition) {
                this.SendKey("3","LogEngine-SendOpen")
                this.g_Mutex.OnExecuted(5)
                this.lastUsedOpen := HiResTimer.GetTick()
                return
            }

            ; ---------- 5. Action2 : Soulflare 超神 ----------
            
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)
            delaySoulFlare := this.g_Gold_Leech


            if (this.g_Mutex.CanExecute(2) && soulFlareReady) {
                if (delaySoulFlare) {
                    if (this.g_Mutex.isSFirst && this.delayTab == 0) {
                        this.delayTab := SetTimer(() => this.DelaySendTab(), -2000)
                    }
                } else {
                    /**
                     * 1. f存在,tab存在,則先tab後f
                     * 2. f使用前搖,tab存在,直接tab
                     * 3. f不存在,tab不使用
                     */

                    preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
                    LeechIsUsedOrExist := false

                    ; 判斷是否Leech是否出現圖標
                    ;  tab fps 95 + 60 158 58+5=63
                    ;  F fps 59 ->36/60fps


                    ; used X : f:96fps , tab:138~139fps(中途插入X之后的事情)


                    ; 判斷是否在使用過程中

                    result := 
                        this.lastUsedLeech != 0 
                        && 
                        1500 >= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) 
                        && 
                        15000 <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick())

                    ; 如果处于BUFF的时候
                    LeechIsUsedOrExist := preLeech || result || hasLeechBuff

                    lastResult := soulFlareReady && LeechIsUsedOrExist
                    if(lastResult){
                        this.DelaySendTab()
                    }
                }
            }

            ; ---------- 6. Action1 : Dragoncall & Wingstorm ----------
            wingstormReady := this.g_Gold_Wingstorm
                ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
                : StateManager._skillState.Get("Wingstorm_R", false)
            dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)
            criticalDragoncallReady := this.g_enablePriorityUseDragoncall ? StateManager._skillState.Get("Critical_Dragoncall", false) : false

            local D_Limit := 300
            local LeechAfterBanWingstorm := 800 + 350
            local OpenAfterBanWingstorm := 600
            local allow_use_W := 
                    !criticalDragoncallReady &&
                    D_Limit <= HiResTimer.DeltaMs(lastUsedD, HiResTimer.GetTick()) && 
                    (LeechAfterBanWingstorm <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) 
                    && OpenAfterBanWingstorm <= HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick()))

            if (this.g_Mutex.CanExecute(1)) {
                if (dragoncallReady) {
                    this.SendKey("4","LogEngine-SendDragoncall")
                    this.g_Mutex.OnExecuted(1)
                    lastUsedD := HiResTimer.GetTick()
                } else if (wingstormReady && allow_use_W) {
                    this.SendKey("v","LogEngine-SendWingstorm")
                    this.g_Mutex.OnExecuted(1)
                    lastUsedW := HiResTimer.GetTick()
                }
            }

            ; ---------- 7. Action3 : Leech 掠夺 ----------
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
            LeechReady := StateManager._skillState.Get("Leech_R", false)
            leech_condition := this.g_limitationLeech
                ? StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)
                : true
            allowLeech := false
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)

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

                if(soulFlareReady){
                    return
                }

                if (allowLeech) {
                    if (LeechReady) {
                        this.SendKey("f","LogEngine-SendLeech")
                        this.lastUsedLeech := HiResTimer.GetTick()
                        this.g_Mutex.OnExecuted(3)
                    } else {
                        return
                    }
                }
            }

            ; ---------- 8. Action4 : Mantra/Rupture/Bombardment ----------
            local LeechAfterBanAction4 := 800
            local LeechAfterBanMantraAndRupture := 1000 ; Ban 真言和破裂
            local MantraAfterBanRupture := 500
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)
            if (this.g_Mutex.CanExecute(4) && LeechAfterBanAction4 <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) && (!preLeech || hasSoulFlareBuff) && !soulFlareReady) {
                MantraReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 3 : 4)) 
                            && StateManager._skillState.Get("Mantra_L", false)
                RuptureReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 4 : 4)) 
                            && StateManager._skillState.Get("Rupture_L", false)
                BombardmentReady := StateManager._skillState.Get("RealBombardment_R", false) 
                                || StateManager._skillState.Get("Bombardment_R", false)
                ; BombardmentReady := 490 <= HiResTimer.DeltaUs(lastUsedBombardment, HiResTimer.GetTick())

                BombardmentReady := true

                BanMantraAndRupture := LeechAfterBanMantraAndRupture <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick())
                BanRupture := MantraAfterBanRupture <= HiResTimer.DeltaMs(this.lastUsedMantra, HiResTimer.GetTick()) && BanMantraAndRupture
                if (MantraReady && BanMantraAndRupture) {
                    this.SendKey("r","LogEngine-SendMantra")
                    this.g_Mutex.OnExecuted(4)
                } else if (RuptureReady && BanRupture) {
                    this.SendKey("f","LogEngine-SendRupture")
                    this.g_Mutex.OnExecuted(4)
                } else if (BombardmentReady) { 
                    this.SendKey("t","LogEngine-SendBombardment")
                    this.g_Mutex.OnExecuted(4)
                    lastUsedBombardment := HiResTimer.GetTick()
                }
            }

        } finally {
            this.g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
            PerformanceMonitor.End("LogEngine-MainLogic")
        }
    }

    static _HandleSleepState() {
        PerformanceMonitor.Start("LogEngine-HandleSleep")
        msg := ""
        OutputMsg := ""
        res := false
        try{
            if (this.g_Mutex.CurrentSleepType() == 1) { ; Open Sleep
                OpenReady := StateManager._skillState.Get("Open_R", false)
                openBlackReady := this.g_Gold_Open && !StateManager._skillState.Get("Open_Black", false) && !OpenReady
                expire := this.g_Mutex.CurrentSleepExpire()   ; 取当前 Open 的过期时间
                if (OpenReady) {
                    MaxOvertime := Floor(this.g_Mutex.openSleepTime * (1/3))
                    if (MaxOvertime <= HiResTimer.DeltaMs(expire, HiResTimer.GetTick())) {
                        msg := "[Open-Ready] Overtime! curOvertime: " HiResTimer.DeltaMs(expire, HiResTimer.GetTick()) " "
                        this.lastUsedOpen := -1 ; 物理使用失败,移除限制
                        this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                        OutputMsg := "Open多帧判断均在亮起,说明没有物理按下," HiResTimer.NowBeijing()
                        res:= false
                    } else if (this.g_Mutex.IsInSleep()) {
                        msg := "[Open-Ready] Sleeping! "
                        OutputMsg := "Open多帧判断是否亮起中,正在sleep," HiResTimer.NowBeijing()
                        res:= true
                    }
                    msg := "[Open-Ready] Error! "
                    OutputMsg := "Open多帧判断异常错误!!!!," HiResTimer.NowBeijing()
                    res:= false
                } else if (openBlackReady) {
                    if (this.g_Mutex.IsInSleep()) {
                        msg := "[Open-Blank] Sleeping! "
                        OutputMsg := "Open物理按下/GCD空转中,正在sleep," HiResTimer.NowBeijing()
                        res:= true
                    } else {
                        msg := "[Open-Ready] Don't Sleep!Releasing! "
                        this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                        OutputMsg := "Open物理按下/GCD空转中,不处于Sleep,释放Sleep条件," HiResTimer.NowBeijing()
                        res:= false
                    }
                } else {
                    msg := "[Open] OpenReadyNotExist And OpenBlankNotExist Releasing! "
                    OutputMsg := "均读取不到Open亮起/暗淡状态!!!!," HiResTimer.NowBeijing()
                    ; 不释放睡眠，保持阻塞等待下一帧
                    this.lastUsedOpen := -1 ; 异常状态,移除限制
                    res:= true
                }
            } else if (this.g_Mutex.CurrentSleepType() == 2) { ; Soulflare Sleep
                msg := "[Soulflare] Soulflare Sleep! "
                OutputMsg := "超神睡眠状态中," HiResTimer.NowBeijing()
                res:= false
            } else if (this.g_Mutex.CurrentSleepType() == 3) { ; Leech Sleep
                msg := "[Leech] Leech Sleep! "
                OutputMsg := "掠夺睡眠状态中," HiResTimer.NowBeijing()
                res:= false
            } 
            else if(this.g_Mutex.CurrentSleepType() == 5){ ; X Sleep
                msg := "[X] X Sleep! "
                OutputMsg := "X睡眠状态中," HiResTimer.NowBeijing()
                res:= true
            }
            else {
                msg := "[UnkNowBeijingn] UnkNowBeijingn sleep type! Release Data! "
                this.g_Mutex.ReleaseSleep()                   ; 未知类型直接清空，确保安全
                OutputMsg := "未知异常," HiResTimer.NowBeijing()
                res:= false
            }
            return res
        }finally{
            this.writeLogEvent(HiResTimer.NowBeijing(), msg)
            OutputDebug OutputMsg
            PerformanceMonitor.End("LogEngine-HandleSleep")
        }
    }

    ; 辅助方法
    static DelaySendTab() {
        if (this.g_Mutex.CanExecute(2) && this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)) {
            if(!this.g_Mutex.isSFirst)
                this.SendKey("e","LogEngine-SendSoulflare-E")
            this.SendKey("{tab}", "LogEngine-SendSoulflare-TAB")
            this.g_Mutex.OnExecuted(2)
            SetTimer(() => (this.g_Mutex.isSFirst := false), -1000)
        }
        this.delayTab := 0
    }

    static lastWriteTable := 0
    static lastWriteTableSpace := 50
    static writeLogEvent(now, msg) {
        msg := now "	" msg
        Log.Write(
            msg
        )
        if(this.lastWriteTableSpace <= HiResTimer.DeltaMs(this.lastWriteTable, HiResTimer.GetTick())){
            Log.Write(this.g_Mutex.GetSleepTable(DragoncallMutex.sleepMap))
            this.lastWriteTable := HiResTimer.GetTick()
        }
        
    }
}