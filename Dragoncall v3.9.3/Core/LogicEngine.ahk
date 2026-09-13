#Requires AutoHotkey v2.0

#Include ../Lib/HiResTimer.ahk
#Include ../Lib/LogicRunner.ahk
#Include CaptureEngine.ahk
#Include ..\Lib\PerformanceMonitor.ahk
#Include CoreConfig.ahk

class LogicEngine extends LogicRunner {

    static lastWriteTableSpace := 50

    ; ============================================================
    ; 入口
    ; ============================================================
    static _MainLogic() {
        ctx := this.ctx
        PerformanceMonitor.Start("LogEngine-MainLogic")
        flag := "Null"
        try {
            start := HiResTimer.GetTick()

            ; 帧级幂等
            if (ctx.state.lastFrameId == CaptureEngine.frameId) {
                flag := "幂等"
                return
            }
            ctx.state.lastFrameId := CaptureEngine.frameId

            ; 开始帧
            ctx.mutex.BeginFrame()
            flag := "帧初始化成功"

            ; 睡眠检查
            if (ctx.mutex.IsInSleep() && this._HandleSleepState(ctx)) {
                flag := "睡眠中-" ctx.mutex.CurrentSleepType()
                return
            }

            ; 主逻辑链
            if (this._Open(ctx)) {
                flag := "Open"
                return
            }

            this._SoulFlare(ctx)
            flag := "SoulFlare"

            this._DragoncallOrWingstorm(ctx)
            flag := "Dragoncall Or Wingstorm"

            if (this._Leech(ctx)) {
                flag := "Leech"
                return
            }

            this._Action4(ctx)
            flag := "Finally"
        } finally {
            ctx.state.lastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
            PerformanceMonitor.End("LogEngine-MainLogic-" flag)
        }
    }

    ; ============================================================
    ; 睡眠状态处理
    ; ============================================================
    static _HandleSleepState(ctx) {
        PerformanceMonitor.Start("LogEngine-HandleSleep")
        OutputMsg := ""
        logMsg := ""
        try {
            value := ctx.mutex.CurrentSleepType()
            switch value {
                case 1:
                    return this._HandleOpenSleep(ctx, &logMsg, &OutputMsg)
                case 2:
                    logMsg := "[HandleSleepState Soulflare] Soulflare Sleep! "
                    OutputMsg := "超神睡眠状态中," . HiResTimer.NowBeijing()
                    return false
                case 3:
                    logMsg := "[HandleSleepState Leech] Leech Sleep! "
                    OutputMsg := "掠夺睡眠状态中," . HiResTimer.NowBeijing()
                    return false
                case 4:
                    logMsg := "[HandleSleepState] Type 4 - no action"
                    OutputMsg := "类型4无操作," . HiResTimer.NowBeijing()
                    return false
                case 5:
                    logMsg := "[HandleSleepState X] X Sleep! "
                    OutputMsg := "X睡眠状态中," . HiResTimer.NowBeijing()
                    return true
                default:
                    logMsg := "[HandleSleepState Error] unknow sleep type! Release Data! "
                    ctx.mutex.ReleaseSleep()
                    OutputMsg := "未知异常," . HiResTimer.NowBeijing()
                    return false
            }
        } finally {
            this.writeLogEvent(ctx, HiResTimer.NowBeijing(), logMsg)
            PerformanceMonitor.End("LogEngine-HandleSleep")
        }
    }

    static _HandleOpenSleep(ctx, &logMsg, &OutputMsg) {
        OpenReady := StateManager._skillState.Get("Open_R", false)
        OpenBlackReady := ctx.config.goldOpen && !StateManager._skillState.Get("Open_Black", false) && !OpenReady
        curExpire := ctx.mutex.CurrentSleepExpire()

        if (OpenReady) {
            MaxOvertime := Floor(ctx.mutex.openSleepTime * (1 / 3))
            overtime := HiResTimer.DeltaMs(curExpire, HiResTimer.GetTick())
            if (MaxOvertime <= overtime) {
                logMsg := "[HandleSleepState Open-Ready] Overtime! curOvertime: " . overtime . " "
                ctx.state.lastUsedOpen := -1
                ctx.mutex.ReleaseSleep(1)
                OutputMsg := "Open多帧判断均在亮起,说明没有物理按下," . HiResTimer.NowBeijing()
                return false
            } else if (ctx.mutex.IsInSleep()) {
                logMsg := "[HandleSleepState Open-Ready] Sleeping! "
                OutputMsg := "Open多帧判断是否亮起中,正在sleep," . HiResTimer.NowBeijing()
                return true
            } else {
                logMsg := "[HandleSleepState Open-Ready] Error! Unexpected state"
                OutputMsg := "Open多帧判断异常错误!!!!," . HiResTimer.NowBeijing()
                return false
            }
        } else if (OpenBlackReady) {
            if (ctx.mutex.IsInSleep()) {
                logMsg := "[HandleSleepState Open-Blank] Sleeping! "
                OutputMsg := "Open物理按下/GCD空转中,正在sleep," . HiResTimer.NowBeijing()
                return true
            } else {
                logMsg := "[HandleSleepState Open-Ready] Don't Sleep!Releasing! "
                ctx.mutex.ReleaseSleep(1)
                OutputMsg := "Open物理按下/GCD空转中,不处于Sleep,释放Sleep条件," . HiResTimer.NowBeijing()
                return false
            }
        } else {
            logMsg := "[HandleSleepState Open] OpenReadyNotExist And OpenBlankNotExist Releasing! "
            OutputMsg := "均读取不到Open亮起/暗淡状态!!!!," . HiResTimer.NowBeijing()
            ctx.state.lastUsedOpen := -1
            return true
        }
    }

    ; ============================================================
    ; 开门
    ; ============================================================
    static _Open(ctx) {
        txt := "LogEngine-Logic-Open"
        PerformanceMonitor.Start(txt)
        recorded := false
        try {
            if (!ctx.config.goldOpen)
                return false

            IsColdDownSoulFlare := StateManager._coldDownState.Get("SoulFlare", false)
            SoulFlareReady := StateManager._skillState.Get("SoulFlare", false)
            if (!(IsColdDownSoulFlare || SoulFlareReady))
                return false

            hasLeechBuff := StateManager._buffState.Get("Leech", false)
            OpenReady := StateManager._skillState.Get("Open_R", false)
            if (!(hasLeechBuff && OpenReady))
                return false

            Min_Window := ctx.mutex.leechSleepTime + 500
            Max_Window := Min_Window + 3000
            UsingReady := Min_Window <= HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick())

            if (ctx.config.goldLeech && hasLeechBuff)
                UsingReady := UsingReady && true
            else if (!ctx.config.goldLeech && hasLeechBuff)
                UsingReady := UsingReady && HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick()) <= Max_Window

            if (Max(ctx.state.lastUsedDragoncall, ctx.state.lastUsedWingstorm) <= ctx.state.lastUsedLeech)
                return false

            if (!UsingReady)
                return false

            if (!this._LimitLeechOrOpenCondition(ctx, ctx.config.limitationOpen, false))
                return false

            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            soulflare_flag := ctx.config.isUseOpenHasSoulFlareBuff ? true : !hasSoulFlareBuff

            if (ctx.mutex.CanExecute(5) && soulflare_flag) {
                this.SendKey("3", "LogEngine-Send-Open")
                ctx.mutex.OnExecuted(5)
                ctx.state.lastUsedOpen := HiResTimer.GetTick()
                ctx.state.flag_press_open := true
                recorded := true
                return true
            }

            return false
        } finally {
            if (recorded)
                PerformanceMonitor.End(txt)
            else
                PerformanceMonitor.Cancel(txt)
        }
    }

    ; ============================================================
    ; 掠夺
    ; ============================================================
    static _Leech(ctx) {
        txt := "LogEngine-Logic-Leech"
        PerformanceMonitor.Start(txt)
        recorded := false
        try {
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
            if (!preLeech)
                return false

            allowUsedLeechFromMySelf := ctx.config.isUsedLeechFromMySelf
                ? (
                    ctx.state.BrandTriggerTime <= HiResTimer.GetTick()
                    && (ctx.state.BrandOverTime == -1 ? true : HiResTimer.GetTick() <= ctx.state.BrandOverTime)
                )
                : true

            if (!this._LimitLeechOrOpenCondition(ctx, false, ctx.config.limitationLeech))
                return false

            allowUsedLeech := false
            hasLeechBuff := StateManager._buffState.Get("Leech", false)
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)

            if (!hasLeechBuff) {
                allowUsedLeech := true
            } else {
                if (!hasSoulFlareBuff && ctx.config.isUseLeechHasLeechBuff && allowUsedLeechFromMySelf)
                    allowUsedLeech := true
            }

            LeechReady := StateManager._skillState.Get("Leech_R", false)
            if (allowUsedLeech) {
                if (!LeechReady)
                    return true                 ; 等待 L 亮，无按键

                if (HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick()) >= LOGIC_INTERVAL && ctx.mutex.CanExecute(3)) {
                    this.SendKey("f", "LogEngine-Send-Leech")
                    ctx.state.lastUsedLeech := HiResTimer.GetTick()
                    ctx.mutex.OnExecuted(3)
                    ctx.state.flag_press_leech := true
                    recorded := true
                    return true
                }
            }

            return false
        } finally {
            if (recorded)
                PerformanceMonitor.End(txt)
            else
                PerformanceMonitor.Cancel(txt)
        }
    }

    ; ============================================================
    ; 暴魔灵 / 死灵突袭
    ; ============================================================
    static _DragoncallOrWingstorm(ctx) {
        txt := "LogEngine-Logic-D or W"
        PerformanceMonitor.Start(txt)
        recorded := false
        try {
            gcd_DW := 500
            gcd_flag := HiResTimer.DeltaMs(
                Max(ctx.state.lastUsedDragoncall, ctx.state.lastUsedWingstorm),
                HiResTimer.GetTick()
            ) <= gcd_DW
            if (gcd_flag)
                return

            additional := true
            if (ctx.config.enablePriorityUseDragoncall) {
                additional_1 := false
                additional_2 := false
                additional_3 := false

                if (CoreConfig.Dragoncall_Bridge_first_Observe_Reconrd <= ctx.state.lastUsedDragoncall) {
                    additional_1 := HiResTimer.DeltaMs(CoreConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) <= CoreConfig.Dragoncall_Bridge_Limit
                }

                LeechAfterBanWingstorm := ctx.mutex.leechSleepTime + gcd_DW * 0.2
                if (ctx.state.flag_press_leech) {
                    additional_2 := HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick()) <= LeechAfterBanWingstorm
                }

                OpenAfterBanWingstorm := ctx.mutex.openSleepTime + gcd_DW * 0.2
                if (ctx.state.flag_press_open) {
                    additional_3 := HiResTimer.DeltaMs(ctx.state.lastUsedOpen, HiResTimer.GetTick()) <= OpenAfterBanWingstorm
                }

                additional := !(additional_1 || additional_2 || additional_3)
            }

            if (ctx.mutex.CanExecute(1)) {
                wingstormReady := ctx.config.goldWingstorm
                    ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
                    : StateManager._skillState.Get("Wingstorm_R", false)
                dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)

                if (dragoncallReady) {
                    this.SendKey("4", "LogEngine-Send-Dragoncall")
                    ctx.mutex.OnExecuted(1)
                    ctx.state.lastUsedDragoncall := HiResTimer.GetTick()
                    if (ctx.state.flag_press_leech)
                        ctx.state.flag_press_leech := false
                    if (ctx.state.flag_press_open)
                        ctx.state.flag_press_open := false
                    recorded := true
                } else if (wingstormReady && additional) {
                    this.SendKey("v", "LogEngine-Send-Wingstorm")
                    ctx.mutex.OnExecuted(1)
                    ctx.state.lastUsedWingstorm := HiResTimer.GetTick()
                    recorded := true
                }
            }
        } finally {
            if (recorded)
                PerformanceMonitor.End(txt)
            else
                PerformanceMonitor.Cancel(txt)
        }
    }

    ; ============================================================
    ; Action4: Mantra / Rupture / Bombardment
    ; ============================================================
    static _Action4(ctx) {
        txt := "LogEngine-Logic-Action4"
        PerformanceMonitor.Start(txt)
        recorded := false
        try {
            OpenAfterBanAction4 := 10
            if (HiResTimer.DeltaMs(ctx.state.lastUsedOpen, HiResTimer.GetTick()) <= (ctx.mutex.openSleepTime + OpenAfterBanAction4))
                return

            LeechAfterBanAction4 := 50
            if (HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick()) <= (ctx.mutex.leechSleepTime + LeechAfterBanAction4))
                return

            if (!ctx.mutex.CanExecute(4))
                return

            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
            hasLeechBuff := StateManager._buffState.Get("Leech", false)
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)

            allowUsedLeechFromMySelf := ctx.config.isUsedLeechFromMySelf
                ? (
                    ctx.state.BrandTriggerTime <= HiResTimer.GetTick()
                    && (ctx.state.BrandOverTime == -1 ? true : HiResTimer.GetTick() <= ctx.state.BrandOverTime)
                )
                : true

            if (preLeech) {
                if (!hasLeechBuff) {
                    return
                } else {
                    if (hasSoulFlareBuff) {
                        ; continue
                    } else {
                        if (ctx.config.isUseLeechHasLeechBuff) {
                            LimitUsedLeech := this._LimitLeechOrOpenCondition(ctx, false, ctx.config.limitationLeech)
                            if (LimitUsedLeech && allowUsedLeechFromMySelf)
                                return
                        }
                    }
                }
            }

            LeechAfterBanMantraAndRupture := 1000
            Using_MantraAndRupture := HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick()) >= (ctx.mutex.leechSleepTime + LeechAfterBanMantraAndRupture)

            if (Using_MantraAndRupture) {
                Mantra_Focus := hasSoulFlareBuff ? 2 : (hasLeechBuff ? 3 : 4)
                Using_Mantra_Focus := CaptureEngine.g_CurrentFocus <= Mantra_Focus
                MantraReady := StateManager._skillState.Get("Mantra_L", false)
                if (MantraReady && Using_Mantra_Focus) {
                    this.SendKey("r", "LogEngine-Send-Mantra")
                    ctx.mutex.OnExecuted(4)
                    ctx.state.lastUsedMantra := HiResTimer.GetTick()
                    recorded := true
                    return
                }

                MantraAfterBanRupture := 500
                Using_Rupture := HiResTimer.DeltaMs(ctx.state.lastUsedMantra, HiResTimer.GetTick()) <= MantraAfterBanRupture
                if (Using_Rupture) {
                    Rupture_Focus := hasSoulFlareBuff ? 1 : (hasLeechBuff ? 3 : 3)
                    Using_Rupture_Focus := CaptureEngine.g_CurrentFocus <= Rupture_Focus
                    RuptureReady := StateManager._skillState.Get("Rupture_L", false)
                    if (RuptureReady && Using_Rupture_Focus) {
                        this.SendKey("f", "LogEngine-Send-Rupture")
                        ctx.mutex.OnExecuted(4)
                        ctx.state.lastUsedRupture := HiResTimer.GetTick()
                        recorded := true
                        return
                    }
                }
            }

            Using_Bombardment := true
            BombardLimit := 20
            if (Using_Bombardment && HiResTimer.AddMs(BombardLimit, ctx.state.lastUsedBombardment) >= ctx.state.lastUsedBombardment) {
                this.SendKey("t", "LogEngine-Send-Bombardment")
                ctx.mutex.OnExecuted(4)
                ctx.state.lastUsedBombardment := HiResTimer.GetTick()
                recorded := true
                return
            }
        } finally {
            if (recorded)
                PerformanceMonitor.End(txt)
            else
                PerformanceMonitor.Cancel(txt)
        }
    }

    ; ============================================================
    ; SoulFlare 超神
    ; ============================================================
    static _SoulFlare(ctx) {
        txt := "LogEngine-Logic-SouFlare"
        PerformanceMonitor.Start(txt)
        recorded := false
        try {
            if (!ctx.config.autoSoulFlare)
                return
            soulFlareReady := StateManager._skillState.Get("SoulFlare", false)
            if (!soulFlareReady)
                return
            if (!ctx.mutex.CanExecute(2))
                return

            if (!ctx.config.goldLeech) {
                preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
                hasLeechBuff := StateManager._buffState.Get("Leech", false)
                minWin := 0
                maxWin := 100 + 700
                delta := HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick())
                Using_SoulFlare := minWin <= delta && delta <= maxWin
                Handling_Leech := ctx.mutex.CurrentSleepType() == 3

                if (Handling_Leech || Using_SoulFlare || hasLeechBuff || preLeech) {
                    this.SendKey("e", "LogEngine-SendSoul-flare-E")
                    this.SendKey("{tab}", "LogEngine-SendSoul-flare-TAB")
                    ctx.state.lastUsedSoulFlare := HiResTimer.GetTick()
                    ctx.mutex.OnExecuted(2)
                    SetTimer ObjBindMethod(this, "SetMarkToFalse", ctx), -500
                    recorded := true
                    return
                }
            } else {
                ; 可操作时间 [T+0.8s, T+0.8s+18s-0.7s]
                delta := HiResTimer.DeltaMs(ctx.state.lastUsedLeech + ctx.mutex.leechSleepTime, HiResTimer.GetTick())
                res := 500 <= delta && delta <= 1300
                ; GCD 未结束
                if (!res)
                    return
                this.SendKey("e", "LogEngine-SendSoul-flare-E")
                this.SendKey("{tab}", "LogEngine-SendSoul-flare-TAB")
                ctx.state.lastUsedSoulFlare := HiResTimer.GetTick()
                ctx.mutex.OnExecuted(2)
                SetTimer ObjBindMethod(this, "SetMarkToFalse", ctx), -500
                recorded := true
                return
            }
        } finally {
            if (recorded)
                PerformanceMonitor.End(txt)
            else
                PerformanceMonitor.Cancel(txt)
        }
    }
    ; ============================================================
    ; 辅助方法
    ; ============================================================
    static SetMarkToFalse(ctx) {
        ctx.mutex.isSFirst := false
        ctx.state.delayTab := 0
    }

    static DelaySendTab(ctx) {
        if (!(ctx.mutex.CanExecute(2) && ctx.config.autoSoulFlare && StateManager._skillState.Get("SoulFlare", false))) {
            ctx.state.delayTab := 0
            return
        }
        if (!ctx.mutex.isSFirst)
            this.SendKey("e", "LogEngine-SendSoul-flare-E")
        this.SendKey("{tab}", "LogEngine-SendSoul-flare-TAB")
        ctx.state.lastUsedSoulFlare := HiResTimer.GetTick()
        ctx.mutex.OnExecuted(2)
        SetTimer ObjBindMethod(this, "SetMarkToFalse", ctx), -500
    }

    ; ============================================================
    ; 限制条件
    ; ============================================================
    static _LimitLeechOrOpenCondition(ctx, isGoldOpen := false, isGoldLeech := false) {
        if (!(isGoldLeech || isGoldOpen)) {
            return true
        }

        hasLeechBuff := StateManager._buffState.Get("Leech", false)
        hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
        if (hasLeechBuff && (!hasSoulFlareBuff || isGoldOpen)) {
            critical_Dragon_flag := HiResTimer.DeltaMs(CoreConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) >= CoreConfig.Dragoncall_Bridge_Limit

            dragoncall_ready_flag := StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)

            trueLeechDuration := (ctx.config.leechBuffDuration - 2) * 1000
            skipLimitUseLeechCondition := HiResTimer.DeltaMs(ctx.state.lastUsedLeech, HiResTimer.GetTick()) >= trueLeechDuration

            LimitLeechOrOpenCondition := (skipLimitUseLeechCondition || critical_Dragon_flag || dragoncall_ready_flag)

            time := A_Hour ":" A_Min ":" A_Sec ":" A_MSec
            txt .= "[" time "] LastUsedLeech: " ctx.state.lastUsedLeech ", skipLimitUseLeechCondition: " skipLimitUseLeechCondition ", critical_Dragon_flag: " critical_Dragon_flag ", dragoncall_ready_flag: " dragoncall_ready_flag ", RES:" LimitLeechOrOpenCondition
            OutputDebug txt

            return LimitLeechOrOpenCondition
        }
        return true
    }

    ; ============================================================
    ; 日志
    ; ============================================================
    static writeLogEvent(ctx, now, msg) {
        msg := now "	" msg
        Log.Write(msg)
        if (this.lastWriteTableSpace <= HiResTimer.DeltaMs(ctx.state.lastWriteTable, HiResTimer.GetTick())) {
            Log.Write(ctx.mutex.GetSleepTable(CoreMutex.sleepMap))
            ctx.state.lastWriteTable := HiResTimer.GetTick()
        }
    }
}