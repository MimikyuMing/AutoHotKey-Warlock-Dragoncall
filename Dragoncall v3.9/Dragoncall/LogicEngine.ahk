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
    static WRITELOG := false
    static g_enablePriorityUseDragoncall := 0

    ; 記錄最後一次使用時間
    static lastUsedLeech := -1
    static lastUsedMantra := -1
    static lastUsedBombardment := -1
    static lastUsedDragoncall := -1
    static lastUsedWingstorm := -1
    static lastUsedOpen := -1
    static lastUsedRupture := -1
    static lastUsedSoulFlare := -1

    ; UsedAfterBanSkill
    static usedOpenAfterBanAction4 := -1
    static usedOpenAfterBanWingstorm := -1
    static usedLeechAfterBanAction4 := -1
    static usedLeechAfterBanMantraAndRupture := -1
    static usedMantraAfterBanRupture := -1
    static usedSoulFlareAfterBanAction4 := -1

    ; ---------- 实现抽象方法 ----------
    static _MainLogic() {
        PerformanceMonitor.Start("LogEngine-MainLogic")
        start := HiResTimer.GetTick()

        ; 帧级幂等
        if (this.lastFrameId == CaptureEngine.frameId) {
            PerformanceMonitor.End("LogEngine-MainLogic")   ; 提前退出也需结束计时
            return
        }
        this.lastFrameId := CaptureEngine.frameId

        try {
            ; ---------- 1. 开始帧 ----------
            this.g_Mutex.BeginFrame()

            ; ---------- 3. 睡眠检查 ----------
            if (this.g_Mutex.IsInSleep()) {
                if (this._HandleSleepState()) {
                    return
                }
            }
            ; ---------- 4. Action5 : Open 开门 ---------
            if(LogicEngine._Open())
                return
            ; ---------- 5. Action2 : Soulflare 超神 ----------
            LogicEngine._SoulFlare()
            ; ---------- 6. Action1 : Dragoncall & Wingstorm ----------
            LogicEngine._DragoncallOrWingstorm()
            ; ---------- 7. Action3 : Leech 掠夺 ----------
            if(LogicEngine._Leech())
                return
            ; ---------- 8. Action4 : Mantra/Rupture/Bombardment ----------
            LogicEngine._Action4()
        } finally {
            this.g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
            PerformanceMonitor.End("LogEngine-MainLogic")
        }
    }


    static _Open() {
        ; 當有掠奪buff + 3 的時候 -> 使用open
        hasLeechBuff := StateManager._buffState.Get("Leech", false)

        OpenReady := StateManager._skillState.Get("Open_R", false)

        open_available_1 := OpenReady && hasLeechBuff ; 當有掠奪buff + 3 的時候 -> 使用open

        ; 當使用掠奪的0.8+0.5s內不使用Open,在使用掠奪的0~3s內才可以使用open
        local open_Leech_Disable_Window := 800 + 500 ; 使用Leech之後 0.8+0.5s內不使用Open
        local open_Leech_Window_Timing := 3000 ; 在使用Leech的0~3s內才可以使用open
        delta_Leech := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick())
        open_available_2 :=
            (delta_Leech >= open_Leech_Disable_Window) ; 0.8+0.5
            &&
            (delta_Leech <= open_Leech_Window_Timing) ; 0~3

        open_available_dragoncall_1 :=
        (
            StateManager._skillState.Get("Dragoncall_L", false)
            &&
            StateManager._skillState.Get("Dragoncall_R", false)
        )

        ; open_available_dragoncall_2 := StateManager._skillState.Get("Critical_Dragoncall", false)
        open_available_dragoncall_2 := StateManager._skillState.Get("Dragoncall_L_Bridge", false)

        open_available_dragoncall := open_available_dragoncall_1 || open_available_dragoncall_2

        open_available_dragoncall_mid :=
            StateManager._skillState.Get("Dragoncall_L", false) &&
            StateManager._skillState.Get("Dragoncall_Mid", false)

        open_available_3 := !(open_available_dragoncall || open_available_dragoncall_mid)

        ; TODO : open邏輯有問題
        open_condition := this.g_Gold_Open
            && open_available_1
            && open_available_2
            && open_available_3

        if (this.g_Mutex.CanExecute(5) && open_condition) {
            this.SendKey("3", "LogEngine-SendOpen")
            this.g_Mutex.OnExecuted(5)
            this.lastUsedOpen := HiResTimer.GetTick()

            local OpenAfterBanAction4 := 100
            this.usedOpenAfterBanAction4 := HiResTimer.AddMs(this.g_Mutex.openSleepTime + OpenAfterBanAction4) ; 100ms 之內不使用Action4,當使用失敗的時候移除限制

            local OpenAfterBanWingstorm := 100
            this.usedOpenAfterBanWingstorm := HiResTimer.AddMs(this.g_Mutex.openSleepTime + OpenAfterBanWingstorm)

            return true
        }
        return false
    }

    static _SoulFlare() {
        hasLeechBuff := StateManager._buffState.Get("Leech", false)
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
                LeechIsUsedOrExist := false

                ; 當preLeech的時候,立即使用sf
                preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)

                ; 判斷是否Leech是否出現圖標
                ;  tab fps 95 + 60 158 58+5=63
                ;  F fps 59 ->36/60fps


                ; used X : f:96fps , tab:138~139fps(中途插入X之后的事情)


                ; 當處於Leech使用過程中,立即使用sf 0.1 + 0.7

                soulflare_leech_using_1 := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= 0.8 * 1000
                soulflare_leech_using_2 := 0 <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick())

                result :=
                    this.lastUsedLeech != 0
                    &&
                    soulflare_leech_using_1
                    &&
                    soulflare_leech_using_2

                ; 如果处于BUFF的时候
                LeechIsUsedOrExist := preLeech || result || hasLeechBuff

                local SoulFlareAfterBanAction4 := 1000

                lastResult := soulFlareReady && LeechIsUsedOrExist
                if (lastResult) {
                    this.DelaySendTab()
                    this.usedSoulFlareAfterBanAction4 := HiResTimer.AddMs(SoulFlareAfterBanAction4)
                }
            }
        }
    }

    static _DragoncallOrWingstorm() {
        wingstormReady := this.g_Gold_Wingstorm
            ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
            : StateManager._skillState.Get("Wingstorm_R", false)
        dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)


        wingstorm_criticalDragoncall_Ready := this.g_enablePriorityUseDragoncall ? StateManager._skillState.Get("Critical_Dragoncall", false) || StateManager._skillState.Get("Dragoncall_L_Bridge", false) : false

        local wingstorm_GCD := 500 + 100
        local LeechAfterBanWingstorm := 800 + 150
        local OpenAfterBanWingstorm := this.g_Mutex.openSleepTime + 150

        ; 當使用Leech之後,優先使用dc(可設置)
        wingstorm_unavailable_1 := this.g_enablePriorityUseDragoncall ? HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= LeechAfterBanWingstorm : false
        ; 當使用Open之後,優先使用dc(可設置)
        wingstorm_unavailable_2 := this.g_enablePriorityUseDragoncall ? HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick()) <= OpenAfterBanWingstorm : false
        ; 暴擊龍
        wingstorm_unavailable_3 := this.g_enablePriorityUseDragoncall ? wingstorm_criticalDragoncall_Ready : false
        ; GCD
        wingstorm_unavailable_4 := wingstorm_GCD <= HiResTimer.DeltaMs(this.lastUsedDragoncall, HiResTimer.GetTick())

        wingstorm_available := (!wingstorm_unavailable_1 || !wingstorm_unavailable_3 || !wingstorm_unavailable_4) && !wingstorm_unavailable_2

        if (this.g_Mutex.CanExecute(1)) {
            if (dragoncallReady) {
                this.SendKey("4", "LogEngine-SendDragoncall")
                this.g_Mutex.OnExecuted(1)
                this.lastUsedDragoncall := HiResTimer.GetTick()
            } else if (wingstormReady && wingstorm_available) {
                this.SendKey("v", "LogEngine-SendWingstorm")
                this.g_Mutex.OnExecuted(1)
                this.lastUsedWingstorm := HiResTimer.GetTick()
            }
        }
    }

    static _Action4() {
        hasLeechBuff := StateManager._buffState.Get("Leech", false)
        hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)

        preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
        soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)

        ; 當使用Open之後,opensleeptime + 10ms內不使用action4
        action4_unavailable_1 := HiResTimer.GetTick() <= this.usedOpenAfterBanAction4
        ; 當使用Leech之後,0.8s內不使用action4
        action4_unavailable_2 := HiResTimer.GetTick() <= this.usedLeechAfterBanAction4
        ; 當preLeech就緒(除非處於soulflare或者未啟用g_isUseLeechHasLeechBuff)的情況下,不使用action4
        action4_unavailable_3 := preLeech && (!hasSoulFlareBuff || !this.g_isUseLeechHasLeechBuff)
        action4_unavailable_4 := soulFlareReady

        ; TODO : 非延遲超神會有禁止1s使用action4,但是會有一個問題就是,後續使用可能會導致戰中停頓1s
        action4_unavailable_5 := this.usedSoulFlareAfterBanAction4 == -1 ? false : HiResTimer.GetTick() <= this.usedSoulFlareAfterBanAction4

        local enabledSoulFlareBanAction4 := false
        action4_unavailable_6 := enabledSoulFlareBanAction4 ? action4_unavailable_5 : false

        action4_available := (!action4_unavailable_1 || !action4_unavailable_2 || !action4_unavailable_3 || !action4_unavailable_4) && !action4_unavailable_6


        if (this.g_Mutex.CanExecute(4) && action4_available) {
            MantraReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 3 : 4))
                && StateManager._skillState.Get("Mantra_L", false)
            RuptureReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 2 : 2))
                && StateManager._skillState.Get("Rupture_L", false)

            mantraAndRupture_unavailable := HiResTimer.GetTick() <= this.usedLeechAfterBanMantraAndRupture

            if (!mantraAndRupture_unavailable) {
                if (MantraReady) {
                    this.SendKey("r", "LogEngine-SendMantra")
                    this.g_Mutex.OnExecuted(4)
                    this.lastUsedMantra := HiResTimer.GetTick()
                    local MantraAfterBanRupture := 500
                    this.usedMantraAfterBanRupture := HiResTimer.AddMs(MantraAfterBanRupture)
                } else if (RuptureReady && HiResTimer.GetTick() >= this.usedMantraAfterBanRupture) {
                    this.SendKey("f", "LogEngine-SendRupture")
                    this.g_Mutex.OnExecuted(4)
                    this.lastUsedRupture := HiResTimer.GetTick()
                }
            }
            
            bombardment_available := StateManager._skillState.Get("RealBombardment_R", false) || StateManager._skillState.Get("Bombardment_R", false)
            
            BombardmentReady := bombardment_available && HiResTimer.GetTick() >= Min(
                HiResTimer.AddMs(700, this.lastUsedRupture), HiResTimer.AddMs(1000, this.lastUsedMantra)
            )
            
            
            if (BombardmentReady) {
                this.SendKey("t", "LogEngine-SendBombardment")
                this.g_Mutex.OnExecuted(4)
                this.lastUsedBombardment := HiResTimer.GetTick()
            }

        }
    }

    static _Leech() {
        hasLeechBuff := StateManager._buffState.Get("Leech", false)
        hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)

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

            if (soulFlareReady) {
                return true
            }

            if (allowLeech) {
                if (LeechReady) {
                    this.SendKey("f", "LogEngine-SendLeech")
                    this.lastUsedLeech := HiResTimer.GetTick()

                    local LeechAfterBanAction4 := 800
                    local LeechAfterBanMantraAndRupture := 1000 ; Ban 真言和破裂

                    this.usedLeechAfterBanAction4 := HiResTimer.AddMs(LeechAfterBanAction4)
                    this.usedLeechAfterBanMantraAndRupture := HiResTimer.AddMs(LeechAfterBanMantraAndRupture)

                    this.g_Mutex.OnExecuted(3)
                } else {
                    return true
                }
            }
            return false
        }
    }

    static _HandleSleepState() {
        PerformanceMonitor.Start("LogEngine-HandleSleep")
        msg := ""
        OutputMsg := ""
        res := false
        try {
            if (this.g_Mutex.CurrentSleepType() == 1) { ; Open Sleep
                OpenReady := StateManager._skillState.Get("Open_R", false)
                openBlackReady := this.g_Gold_Open && !StateManager._skillState.Get("Open_Black", false) && !OpenReady
                expire := this.g_Mutex.CurrentSleepExpire()   ; 取当前 Open 的过期时间
                if (OpenReady) {
                    MaxOvertime := Floor(this.g_Mutex.openSleepTime * (1 / 3))
                    if (MaxOvertime <= HiResTimer.DeltaMs(expire, HiResTimer.GetTick())) {
                        msg := "[Open-Ready] Overtime! curOvertime: " HiResTimer.DeltaMs(expire, HiResTimer.GetTick()) " "
                        this.lastUsedOpen := -1 ; 物理使用失败,移除限制
                        this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                        OutputMsg := "Open多帧判断均在亮起,说明没有物理按下," HiResTimer.NowBeijing()
                        this.usedOpenAfterBanAction4 := -1
                        res := false
                    } else if (this.g_Mutex.IsInSleep()) {
                        msg := "[Open-Ready] Sleeping! "
                        OutputMsg := "Open多帧判断是否亮起中,正在sleep," HiResTimer.NowBeijing()
                        res := true
                    }
                    msg := "[Open-Ready] Error! "
                    OutputMsg := "Open多帧判断异常错误!!!!," HiResTimer.NowBeijing()
                    res := false
                } else if (openBlackReady) {
                    if (this.g_Mutex.IsInSleep()) {
                        msg := "[Open-Blank] Sleeping! "
                        OutputMsg := "Open物理按下/GCD空转中,正在sleep," HiResTimer.NowBeijing()
                        res := true
                    } else {
                        msg := "[Open-Ready] Don't Sleep!Releasing! "
                        this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                        OutputMsg := "Open物理按下/GCD空转中,不处于Sleep,释放Sleep条件," HiResTimer.NowBeijing()
                        res := false
                    }
                } else {
                    msg := "[Open] OpenReadyNotExist And OpenBlankNotExist Releasing! "
                    OutputMsg := "均读取不到Open亮起/暗淡状态!!!!," HiResTimer.NowBeijing()
                    ; 不释放睡眠，保持阻塞等待下一帧
                    this.lastUsedOpen := -1 ; 异常状态,移除限制
                    this.usedOpenAfterBanAction4 := -1
                    res := true
                }
            } else if (this.g_Mutex.CurrentSleepType() == 2) { ; Soulflare Sleep
                msg := "[Soulflare] Soulflare Sleep! "
                OutputMsg := "超神睡眠状态中," HiResTimer.NowBeijing()
                res := false
            } else if (this.g_Mutex.CurrentSleepType() == 3) { ; Leech Sleep
                msg := "[Leech] Leech Sleep! "
                OutputMsg := "掠夺睡眠状态中," HiResTimer.NowBeijing()
                res := false
            }
            else if (this.g_Mutex.CurrentSleepType() == 5) { ; X Sleep
                msg := "[X] X Sleep! "
                OutputMsg := "X睡眠状态中," HiResTimer.NowBeijing()
                res := true
            }
            else {
                msg := "[UnkNowBeijingn] UnkNowBeijingn sleep type! Release Data! "
                this.g_Mutex.ReleaseSleep()                   ; 未知类型直接清空，确保安全
                OutputMsg := "未知异常," HiResTimer.NowBeijing()
                res := false
            }
            return res
        } finally {
            this.writeLogEvent(HiResTimer.NowBeijing(), msg)
            OutputDebug OutputMsg
            PerformanceMonitor.End("LogEngine-HandleSleep")
        }
    }

    ; 辅助方法
    static DelaySendTab() {
        if (this.g_Mutex.CanExecute(2) && this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)) {
            if (!this.g_Mutex.isSFirst)
                this.SendKey("e", "LogEngine-SendSoulflare-E")
            this.SendKey("{tab}", "LogEngine-SendSoulflare-TAB")
            this.lastUsedSoulFlare := HiResTimer.GetTick()
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
        if (this.lastWriteTableSpace <= HiResTimer.DeltaMs(this.lastWriteTable, HiResTimer.GetTick())) {
            Log.Write(this.g_Mutex.GetSleepTable(DragoncallMutex.sleepMap))
            this.lastWriteTable := HiResTimer.GetTick()
        }

    }
}