#Requires AutoHotkey v2.0


#Include ../Lib/HiResTimer.ahk
#Include ../Lib/LogicRunner.ahk
#Include DragoncallMutex.ahk
#Include CaptureEngine.ahk
#Include ..\Lib\PerformanceMonitor.ahk
#Include Dragoncall_Config.ahk

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
    static g_isUseOpenHasSoulFlareBuff := false
    static g_isUsedLeechFromMySelf := false

    ; 記錄最後一次使用時間
    static lastUsedLeech := -1
    static lastUsedMantra := -1
    static lastUsedBombardment := -1
    static lastUsedDragoncall := -1
    static lastUsedWingstorm := -1
    static lastUsedOpen := -1
    static lastUsedRupture := -1
    static lastUsedSoulFlare := -1

    static BrandOverTime := -1
    static BrandTriggerTime := -1

    static flag_press_open := 0
    static flag_press_leech := 0

    static leechBuffDuration := this.g_Gold_Leech ? 18 : 15 ;s

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
            if (LogicEngine._Open())
                return
            ; ---------- 5. Action2 : Soulflare 超神 ----------
            LogicEngine._SoulFlare()
            ; ; ---------- 6. Action1 : Dragoncall & Wingstorm ----------
            LogicEngine._DragoncallOrWingstorm()
            ; ; ---------- 7. Action3 : Leech 掠夺 ----------
            if (LogicEngine._Leech())
                return
            ; ---------- 8. Action4 : Mantra/Rupture/Bombardment ----------
            LogicEngine._Action4()
        } finally {
            this.g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
            PerformanceMonitor.End("LogEngine-MainLogic")
        }
    }


    /**
     * 當擁有Leech Buff的時候
     * 1. 並且擁有Open圖標 -> flag-1
     * 2. 當上一次使用Leech的時間處於[Leech Sleep + 0.5s,Leech Sleep + 0.5s + 3s]的時候 -> flag-2
     * 3. 當Dragoncall小於指定百分比cd的 -> flag-3
     * 4. 當Dragoncall暴擊之後,一定時間內不使用OPEN -> flag-no-1
     * 5. 當處於SoulFlare buff的時候,可選是否使用Open
     * total :
     * 1. 當flag-1 && 2 && 3 && !flag-no-1 的時候可使用open
     * @returns {Boolean} 
     */
    static _Open() {
        PerformanceMonitor.Start("LogEngine-Logic-Open")
        try {
            ; 當沒有勾選GoldOpen的時候,跳過使用OPEN邏輯執行
            if (!this.g_Gold_Open) {
                return
            }

            IsColdDownSoulFlare:= StateManager._coldDownState.Get("SoulFlare", false)
            SoulFlareReady := StateManager._skillState.Get("SoulFlare", false)
            if(!IsColdDownSoulFlare && !SoulFlareReady){
                return
            }
            ; 1. 當擁有Leech Buff的時候並且擁有Open圖標 -> flag-1
            hasLeechBuff := StateManager._buffState.Get("Leech", false)
            OpenReady := StateManager._skillState.Get("Open_R", false)
            local ready_flag := hasLeechBuff && OpenReady

            ; 2. 當上一次使用Leech的時間處於[Leech Sleep + 0.5s,Leech Sleep + 0.5s + 3s]的時候 -> flag-2
            local open_Leech_Disable_Window := this.g_Mutex.leechSleepTime + 500 ; 使用Leech之後 0.8+0.5s內不使用Open
            local open_Leech_Window_Timing := open_Leech_Disable_Window + 3000 ; 在使用Leech的0~3s內才可以使用open

            ; 当有GOLDLEECH的时候,只要有Leechbuff就直接使用
            local using_flag := open_Leech_Disable_Window <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) && (
                this.g_Gold_Leech ? hasLeechBuff : HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= open_Leech_Window_Timing
            )

            ; Limit 暴擊龍/當前cd>=閾值 -> 不可使用Open
            local LimitUsedOpen := this._LimitLeechOrOpenCondition(this.g_limitationOpen, true)

            ; OutputDebug dragoncall_ready_flag


            ; 5. 當處於SoulFlare buff的時候,可選是否使用Open
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            local soulflare_flag := this.g_isUseOpenHasSoulFlareBuff ? true : !hasSoulFlareBuff

            local open_available :=
                ready_flag && ; 圖標+buff就緒
                using_flag && ; 使用時機
                LimitUsedOpen &&
                soulflare_flag

            if (this.g_Mutex.CanExecute(5) && open_available) {
                this.SendKey("3", "LogEngine-Send-Open")
                this.g_Mutex.OnExecuted(5)
                this.lastUsedOpen := HiResTimer.GetTick()
                this.flag_press_open := true
                return true
            }
            return false
        }
        finally {
            PerformanceMonitor.End("LogEngine-Logic-Open")
        }
    }

    /**
     * 當sf準備就緒的時候
     * 1. 當掠奪可用的時候,立即使用sf
     * 2. 當處於掠奪使用時,立即使用sf
     * 3. 當掠奪不可用的時候,不使用sf
     * 
     * 1. 當擁有GOLD LEECH之後,SF應該在LEECH之後使用
     * 2. 當LEECH可用的時候,延遲使用SF
     * 3. 當處於LEECH使用時,延遲使用SF
     * 4. 當LEECH不可用的時候,不使用SF
     * 5. 當LEECH BUFF存在的時候,並且上一次使用時間<=n的時候,立即使用
     */
    static _SoulFlare() {
        PerformanceMonitor.Start("LogEngine-Logic-SouFlare")
        try {
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)

            if (this.g_Mutex.CanExecute(2) && soulFlareReady) {
                ; 1. 當掠奪可用的時候,立即使用sf
                preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
                hasLeechBuff := StateManager._buffState.Get("Leech", false)
                local leech_flag := preLeech

                ; 2. 當處於掠奪使用時,立即使用sf
                local soulflare_leechAfter_minWindows := 0
                local soulflare_leechAfter_maxWindows := 100 + 700

                local using_leechUsing_flag := soulflare_leechAfter_minWindows <= HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) && HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= soulflare_leechAfter_maxWindows

                local handleLeeching := this.g_Mutex.CurrentSleepType() == 3

                local soulflare_available := soulFlareReady && (leech_flag || hasLeechBuff || handleLeeching || using_leechUsing_flag)

                delaySoulFlare := this.g_Gold_Leech

                if (soulflare_available) {
                    if (hasLeechBuff) {
                        this.DelaySendTab()
                        return
                    }
                    ; else if (delaySoulFlare && this.g_Mutex.isSFirst && this.delayTab == 0) {

                    ;Leech之后的1~2.5s内禁用
                    local disableUsedSF := !(1000 <= HiResTimer.DeltaMs(this.lastUsedLeech + this.g_Mutex.leechSleepTime, HiResTimer.GetTick()) && HiResTimer.DeltaMs(this.lastUsedLeech + this.g_Mutex.leechSleepTime, HiResTimer.GetTick()) <= 2500)
                    ; OutputDebug disableUsedSF
                    if (delaySoulFlare && this.delayTab == 0 && disableUsedSF) {
                        return
                    }

                    if (delaySoulFlare && this.delayTab == 0) {
                        this.delayTab := SetTimer(() => this.DelaySendTab(), -1500)
                    } else {
                        this.DelaySendTab()
                    }
                }
            }
        }
        finally {
            PerformanceMonitor.End("LogEngine-Logic-SouFlare")
        }
    }

    /**
     * 當Dragoncall就緒的時候,立即使用
     * 
     * 優先暴魔靈:
     * 當上一次使用Dragoncall的時間小於GCD,則不使用v
     * 如果暴擊龍亮起,短時間內不再使用v(直到首次打出4)
     * 當Leech使用之後,短時間內不再使用v(直到首次打出4)
     * 當Open使用之後,短時間內不再使用v(直到首次打出4)
     * 
     */
    static _DragoncallOrWingstorm() {
        PerformanceMonitor.Start("LogEngine-Logic-D or W")
        try {
            wingstormReady := this.g_Gold_Wingstorm
                ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
                : StateManager._skillState.Get("Wingstorm_R", false)
            dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)


            priorityUsedDragoncall := true

            if (this.g_enablePriorityUseDragoncall) {
                leech_ban_wingstorm_flag := false
                open_ban_wingstorm_flag := false
                critical_Dragon_flag := false

                ; 當上一次使用Dragoncall的時間小於GCD,則不使用v
                local wingstorm_GCD := 550 - 200
                wingstorm_gcd_flag := HiResTimer.DeltaMs(
                    Max(this.lastUsedDragoncall, this.lastUsedWingstorm), HiResTimer.GetTick()
                ) <= wingstorm_GCD

                ; 如果暴擊龍亮起,短時間內不再使用v(直到首次打出4)
                if (DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd <= this.lastUsedDragoncall) {
                    critical_Dragon_flag := HiResTimer.DeltaMs(DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) <= DragoncallConfig.Dragoncall_Bridge_Limit
                }


                ; 當Leech使用之後,短時間內不再使用v(直到首次打出4)
                local LeechAfterBanWingstorm := this.g_Mutex.leechSleepTime + +wingstorm_GCD * 0.2

                if (this.flag_press_leech) {
                    leech_ban_wingstorm_flag := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= LeechAfterBanWingstorm
                }


                ; 當Open使用之後,短時間內不再使用v(直到首次打出4)
                local OpenAfterBanWingstorm := this.g_Mutex.openSleepTime + wingstorm_GCD * 0.2
                if (this.flag_press_open) {
                    open_ban_wingstorm_flag := HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick()) <= OpenAfterBanWingstorm
                }

                priorityUsedDragoncall := !(wingstorm_gcd_flag || critical_Dragon_flag || leech_ban_wingstorm_flag || open_ban_wingstorm_flag)
            }

            if (this.g_Mutex.CanExecute(1)) {
                if (dragoncallReady) {
                    this.SendKey("4", "LogEngine-Send-Dragoncall")
                    this.g_Mutex.OnExecuted(1)
                    this.lastUsedDragoncall := HiResTimer.GetTick()
                    if (this.flag_press_leech) {
                        this.flag_press_leech := false
                    }
                    if (this.flag_press_open) {
                        this.flag_press_open := false
                    }
                } else if (wingstormReady && priorityUsedDragoncall) {
                    this.SendKey("v", "LogEngine-Send-Wingstorm")
                    this.g_Mutex.OnExecuted(1)
                    this.lastUsedWingstorm := HiResTimer.GetTick()
                    ; OutputDebug "press wingstorm "
                }
            }
        }
        finally {
            PerformanceMonitor.End("LogEngine-Logic-D or W")
        }
    }

    /**
     * 1. 使用Open之後短時間內不觸發action4
     * 2. 使用Leech之後短時間內不觸發action4
     * 3. 當preLeech亮起的時候並且不處於SF狀態下,break操作
     * 4. 當preLeech亮起的時候,並且處於L狀態下,根據ini參數break操作
     * 5. 當preLeech亮起的時候,並且不處於L狀態下,break操作
     * 
     * 1. 判斷內力是否小於指定值,小於則判斷當前條件是否可使用真言
     * 2. 判斷內力是否小於指定值,小於則判斷當前條件是否可使用破裂
     * 3. 上述兩種情況均不滿足的情況下,使用次元彈
     */
    static _Action4() {
        PerformanceMonitor.Start("LogEngine-Logic-Action4")
        try {
            ; 當使用Open之後,opensleeptime + 10ms內不使用action4
            local OpenAfterBanAction4 := 10 
            action4_unavailable_1 := HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick()) <= (this.g_Mutex.openSleepTime + OpenAfterBanAction4)

            if (action4_unavailable_1) {
                return
            }


            ; 當使用Leech之後,0.8s內不使用action4
            local LeechAfterBanAction4 := 50
            action4_unavailable_2 := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= (this.g_Mutex.leechSleepTime + LeechAfterBanAction4)

            if (action4_unavailable_2) {
                return
            }

            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
            hasLeechBuff := StateManager._buffState.Get("Leech", false)
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)

            /**
             * 1. L 亮 NE-SL NE-L -> return 优先L执行
             * 2. L 亮 NE-SL EX-L -> INI是否允许使用L? -yes-> return
             * 3. L 亮 EX-SL NE-L -> return 优先L执行
             * 4. L 亮 EX-SL EX-L -> continue
             */
            local allowUsedLeechFromMySelf := this.g_isUsedLeechFromMySelf ?
            (
                this.BrandTriggerTime <= HiResTimer.GetTick()
                &&
                this.BrandOverTime == -1 ? true : HiResTimer.GetTick() <= this.BrandOverTime
            ) : true
            if (preLeech && allowUsedLeechFromMySelf) {
                if (hasSoulFlareBuff && hasLeechBuff) {
                    ; continue
                }
                else if (hasSoulFlareBuff && !hasLeechBuff) {
                    ; return 优先SF,L执行
                    return
                }
                else if (!hasSoulFlareBuff && hasLeechBuff) {
                    ; INI是否允许使用L? -yes-> return
                    if (this.g_isUseLeechHasLeechBuff) {
                        local LimitUsedLeech := this._LimitLeechOrOpenCondition(this.g_limitationLeech)
                        if(LimitUsedLeech){
                            return
                        }
                    } else {
                        ; continue
                    }
                }
                else if (!hasSoulFlareBuff && !hasLeechBuff) {
                    return
                }
            }
            local LeechAfterBanMantraAndRupture := 1000
            mantraAndRupture_unavailable := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) <= (this.g_Mutex.leechSleepTime + LeechAfterBanMantraAndRupture)

            if (!mantraAndRupture_unavailable) {
                ; Mantra and Rupture
                MantraReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 3 : 4))
                    && StateManager._skillState.Get("Mantra_L", false)
                if (MantraReady) {
                    this.SendKey("r", "LogEngine-Send-Mantra")
                    this.g_Mutex.OnExecuted(4)
                    this.lastUsedMantra := HiResTimer.GetTick()
                    return
                }

                local MantraAfterBanRupture := 500
                Rupture_unavailable := HiResTimer.DeltaMs(this.lastUsedMantra, HiResTimer.GetTick()) <= MantraAfterBanRupture
                RuptureReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 3 : 3))
                    && StateManager._skillState.Get("Rupture_L", false)

                if (RuptureReady && !Rupture_unavailable) {
                    this.SendKey("f", "LogEngine-Send-Rupture")
                    this.g_Mutex.OnExecuted(4)
                    this.lastUsedRupture := HiResTimer.GetTick()
                    return
                }
            }

            /**
             * 1. 首先检测是否图标亮起?
             * 2. 检测上一次真言/破裂/掠夺的使用时间+gcd时间,谁更加接近CurTick
             * 3. 若当前时间小于最后使用时间的gcd,表示gcd还未结束,return
             * 4. 否则表示gcd结束,可用
             */
            bombardment_available := StateManager._skillState.Get("RealBombardment", false) || StateManager._skillState.Get("Bombardment", false)
            bombardment_available := true
            MantraGCD := this.lastUsedMantra + 1000
            RuptureGCD := this.lastUsedRupture + 700
            LeechGCD := this.lastUsedLeech + this.g_Mutex.leechSleepTime
            cap_res := Max(MantraGCD, RuptureGCD)
            cap_res := Max(cap_res, LeechGCD)

            ; if (HiResTimer.GetTick() < cap_res) {
            ;     return
            ; }
            local BombardLimit := LOGIC_INTERVAL * 0.5
            BombardLimit := 0
            if (bombardment_available && HiResTimer.AddMs(BombardLimit, this.lastUsedBombardment) >= this.lastUsedBombardment) {
                this.SendKey("t", "LogEngine-Send-Bombardment")
                this.g_Mutex.OnExecuted(4)
                this.lastUsedBombardment := HiResTimer.GetTick()
                return
            }
        }
        finally {
            PerformanceMonitor.End("LogEngine-Logic-Action4")
        }

    }

    /**
     * 1. Leech 图标亮了 就停止所有后续操作,直到Leech成功按出
     * 2. 当Leech Dark的时候,表示Leech可用,但不一定在必用的情况
     * 3. 当Leech R的时候,表示可以按下Leech触发效果
     * 
     * 1. 当在SF buff的情况下,如果没有Leech buff则变成必须使用Leech
     * 2. 当不处于SF状态下,并且处于Leech状态下,根据参数决定是否必须使用Leech
     * 3. 当不处于SF状态并且不处于Leech状态下,必须使用Leech
     * 
     * return true表示跳过后续
     * @returns {Boolean} 
     */
    static _Leech() {
        PerformanceMonitor.Start("LogEngine-Logic-Leech")

        try {
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)
            LeechReady := StateManager._skillState.Get("Leech_R", false)

            if (!preLeech) {
                return false
            }

            ; 必用状态
            hasLeechBuff := StateManager._buffState.Get("Leech", false)
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            allowLeech := false

            local allowUsedLeechFromMySelf := this.g_isUsedLeechFromMySelf ?
            (
                this.BrandTriggerTime <= HiResTimer.GetTick()
                &&
                this.BrandOverTime == -1 ? true : HiResTimer.GetTick() <= this.BrandOverTime
            ) : true

            if (hasSoulFlareBuff) {
                if (!hasLeechBuff) {
                    allowLeech := true
                }
            } else if (!hasSoulFlareBuff) {
                if (!hasLeechBuff) {
                    allowLeech := true
                }
                else if (this.g_isUseLeechHasLeechBuff && hasLeechBuff && allowUsedLeechFromMySelf) {
                    local LimitUsedLeech := this._LimitLeechOrOpenCondition(this.g_limitationLeech)
                    allowLeech := true && LimitUsedLeech
                }
                else {
                    allowLeech := false
                }
            }
            allowLeech := allowLeech

            /**
             * 1. Leech图标就绪
             * 1.1 
             * 2. Leech图标未好
             */


            if (allowLeech) {
                if (preLeech && !LeechReady) {
                    ; OutputDebug "waiting Leech"
                    return true
                }

                if (preLeech && LeechReady && HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) >= LOGIC_INTERVAL) {
                    this.SendKey("f", "LogEngine-Send-Leech")
                    this.lastUsedLeech := HiResTimer.GetTick()
                    this.g_Mutex.OnExecuted(3)
                    ; OutputDebug "use Leech, " HiResTimer.GetTick()
                    this.flag_press_leech := true
                    return true
                }
            }
            ; OutputDebug "skip Leech"
            return false

        } finally {
            PerformanceMonitor.End("LogEngine-Logic-Leech")

        }
    }

    static _Old_HandleSleepState() {
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
                        res := false
                    } else if (this.g_Mutex.IsInSleep()) {
                        msg := "[Open-Ready] Sleeping! "
                        OutputMsg := "Open多帧判断是否亮起中,正在sleep," HiResTimer.NowBeijing()
                        res := true
                    } else {
                        msg := "[Open-Ready] Error! "
                        OutputMsg := "Open多帧判断异常错误!!!!," HiResTimer.NowBeijing()
                        res := false
                    }
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
            ; OutputDebug OutputMsg
            PerformanceMonitor.End("LogEngine-HandleSleep")
        }
    }

    static _HandleSleepState() {
        PerformanceMonitor.Start("LogEngine-HandleSleep")
        OutputMsg := ""
        logMsg := ""
        try {
            value := this.g_Mutex.CurrentSleepType()
            switch value {
                case 1:  ; 开门
                    return this._HandleOpenSleep(&logMsg, &OutputMsg)
                case 2:  ; 超神
                    logMsg := "[HandleSleepState Soulflare] Soulflare Sleep! "
                    OutputMsg := "超神睡眠状态中," . HiResTimer.NowBeijing()
                    return false
                case 3:  ; 掠夺
                    logMsg := "[HandleSleepState Leech] Leech Sleep! "
                    OutputMsg := "掠夺睡眠状态中," . HiResTimer.NowBeijing()
                    return false
                case 4:  ; 暂无
                    logMsg := "[HandleSleepState] Type 4 - no action"
                    OutputMsg := "类型4无操作," . HiResTimer.NowBeijing()
                    return false
                case 5:  ; 警戒斩
                    logMsg := "[HandleSleepState X] X Sleep! "
                    OutputMsg := "X睡眠状态中," . HiResTimer.NowBeijing()
                    return true
                default:
                    logMsg := "[HandleSleepState Error] unknow sleep type! Release Data! "
                    this.g_Mutex.ReleaseSleep()
                    OutputMsg := "未知异常," . HiResTimer.NowBeijing()
                    return false
            }
        } finally {
            this.writeLogEvent(HiResTimer.NowBeijing(), logMsg)
            ; OutputDebug(OutputMsg)
            PerformanceMonitor.End("LogEngine-HandleSleep")
        }
    }

    static _HandleOpenSleep(&logMsg, &OutputMsg) {
        OpenReady := StateManager._skillState.Get("Open_R", false)
        OpenBlackReady := this.g_Gold_Open && !StateManager._skillState.Get("Open_Black", false) && !OpenReady
        curExpire := this.g_Mutex.CurrentSleepExpire()

        if (OpenReady) {
            MaxOvertime := Floor(this.g_Mutex.openSleepTime * (1 / 3))
            overtime := HiResTimer.DeltaMs(curExpire, HiResTimer.GetTick())
            if (MaxOvertime <= overtime) {
                logMsg := "[HandleSleepState Open-Ready] Overtime! curOvertime: " . overtime . " "
                this.lastUsedOpen := -1
                this.g_Mutex.ReleaseSleep(1)
                OutputMsg := "Open多帧判断均在亮起,说明没有物理按下," . HiResTimer.NowBeijing()
                return false
            } else if (this.g_Mutex.IsInSleep()) {
                logMsg := "[HandleSleepState Open-Ready] Sleeping! "
                OutputMsg := "Open多帧判断是否亮起中,正在sleep," . HiResTimer.NowBeijing()
                return true
            } else {
                logMsg := "[HandleSleepState Open-Ready] Error! Unexpected state"
                OutputMsg := "Open多帧判断异常错误!!!!," . HiResTimer.NowBeijing()
                return false
            }
        } else if (OpenBlackReady) {
            if (this.g_Mutex.IsInSleep()) {
                logMsg := "[HandleSleepState Open-Blank] Sleeping! "
                OutputMsg := "Open物理按下/GCD空转中,正在sleep," . HiResTimer.NowBeijing()
                return true
            } else {
                logMsg := "[HandleSleepState Open-Ready] Don't Sleep!Releasing! "
                this.g_Mutex.ReleaseSleep(1)
                OutputMsg := "Open物理按下/GCD空转中,不处于Sleep,释放Sleep条件," . HiResTimer.NowBeijing()
                return false
            }
        } else {
            logMsg := "[HandleSleepState Open] OpenReadyNotExist And OpenBlankNotExist Releasing! "
            OutputMsg := "均读取不到Open亮起/暗淡状态!!!!," . HiResTimer.NowBeijing()
            this.lastUsedOpen := -1
            return true
        }
    }

    static InitLastUsed() {
        this.lastUsedSoulFlare := HiResTimer.AddMs(-15000)
        this.lastUsedMantra := HiResTimer.AddMs(-15000)
        this.lastUsedLeech := HiResTimer.AddMs(-15000)
        this.lastUsedBombardment := HiResTimer.AddMs(-15000)
        this.lastUsedDragoncall := HiResTimer.AddMs(-15000)
        this.lastUsedWingstorm := HiResTimer.AddMs(-15000)
        this.lastUsedOpen := HiResTimer.AddMs(-15000)
        this.lastUsedRupture := HiResTimer.AddMs(-15000)
    }

    ; 辅助方法
    static DelaySendTab() {
        if (this.g_Mutex.CanExecute(2) && this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)) {
            if (!this.g_Mutex.isSFirst)
                this.SendKey("e", "LogEngine-SendSoul-flare-E")
            this.SendKey("{tab}", "LogEngine-SendSoul-flare-TAB")
            ; OutputDebug "use SoulFlare, " HiResTimer.GetTick()
            this.lastUsedSoulFlare := HiResTimer.GetTick()
            this.g_Mutex.OnExecuted(2)
            SetTimer ObjBindMethod(this, "SetMarkToFalse"), -500
        }
    }

    static SetMarkToFalse() {
        this.g_Mutex.isSFirst := false
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

    /**
     * return true表示可用Leech,False表示不可用Leech
     * @param conditon 
     * @returns {Boolean} 
     */
    static _LimitLeechOrOpenCondition(conditon, isOpen:=false){

        if(!conditon){
            return true
        }

        hasLeechBuff := StateManager._buffState.Get("Leech", false)
        hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
        if(hasLeechBuff && (!hasSoulFlareBuff || isOpen)){
             ; 4. 當Dragoncall暴擊之後,一定時間內不使用Leech ->true表示大於指定時間,可以使用Leech
            local critical_Dragon_flag := HiResTimer.DeltaMs(DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) >= DragoncallConfig.Dragoncall_Bridge_Limit

            ; 3. 當Dragoncall小於指定百分比cd的 -> true表示當前Dragoncall的冷卻時間>=指定百分比,可以使用Leech
            ; true 表示 L亮,MID不亮 -> cur cd < target -> used LimitSkill
            local dragoncall_ready_flag := StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)

            ; 並且距離上次使用Leech的時間大於指定間隔,可以無視該條件
            local trueLeechDuration := (this.leechBuffDuration - 2) * 1000 ; ms
            ; TRUE表示跳过,FLASE表示不跳过
            local skipLimitUseLeechCondition := HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) >= trueLeechDuration
            ; 当(critical_Dragon_flag,dragoncall_ready_flag)其中一个满足的时候表示可以使用Leech
            ; 當skipLimitUseLeechCondition满足的时候,无视后续的条件直接使用Leech
            

            ; 也就是說 三者有一者滿足即直接使用Leech
            LimitLeechOrOpenCondition := (skipLimitUseLeechCondition ||  critical_Dragon_flag || dragoncall_ready_flag)


            time := A_Hour ":"  A_Min  ":"  A_Sec  ":"  A_MSec
            txt.= "[" time "] LastUsedLeech: " this.lastUsedLeech ", skipLimitUseLeechCondition: " skipLimitUseLeechCondition ", critical_Dragon_flag: " critical_Dragon_flag ", dragoncall_ready_flag: " dragoncall_ready_flag ", RES:" LimitLeechOrOpenCondition
            OutputDebug txt

            return LimitLeechOrOpenCondition
        }
        return true
    }


    ; static _Open_1(){
    ;     PerformanceMonitor.Start("LogEngine-Logic-Open")
    ;     try{
    ;         ; 檢測是否啟用自動Open
    ;         if(!this.g_Gold_Open){
    ;             return
    ;         }

    ;         ; 1.檢測超神是否進入冷卻,進入冷卻則跳過邏輯,直接進行後續Action
    ;         local IsColdDownSoulFlare:= StateManager._coldDownState.Get("SoulFlare", false)
    ;         local SoulFlareReady := StateManager._skillState.Get("SoulFlare", false)
    ;         ; 2.如果冷卻欄位沒有match到 並且 技能欄位中沒有超神圖標,則跳過當前邏輯,執行後續action
    ;         if(!IsColdDownSoulFlare && !SoulFlareReady){
    ;             return
    ;         }
    ;         ; 3.走主要逻辑
    ;         hasLeechBuff := StateManager._buffState.Get("Leech", false)
    ;         ; 3.1 检测当前使用Open时机是否符合条件
    ;         ; 3.1.1 如果没有Gold——Leech的话，则可以按照15(SF+OP)-15-15(OP)-15的法则,进行分配，因此当前的时机是在掠夺后摇之后的0~3s使用Open
    ;         local Disable_Window := this.g_Mutex.leechSleepTime + 500 ; 使用Leech之後 0.8+0.5s內不使用Open
    ;         local Max_Window := Disable_Window + 3000 ; 在使用Leech的0~3s內才可以使用open
    ;         local using_flag := Disable_Window <= HiResTimer.DeltaMs(this.g_Mutex.lastUsedLeech, HiResTimer.GetTick())
    ;         if(!this.g_Gold_Leech){
    ;             using_flag := using_flag && HiResTimer.DeltaMs(this.g_Mutex.lastUsedLeech, HiResTimer.GetTick()) <= Max_Window
    ;         }
    ;         ; 3.1.2 如果有GoldLeech则无视该条件
    ;         if(this.g_Gold_Leech){
    ;             using_flag := using_flag && hasLeechBuff
    ;         }
    ;         ; 3.2 检测当前是否处于Leech状态，并且Open是否已经准备就绪
    ;         local ready_flag := hasLeechBuff && StateManager._skillState.Get("Open_R", false)
    ;         ; 3.3 是否启用限制条件
    ;         local LimitUsedOpen := _LimitLeechOrOpenCondition(this.g_limitationOpen, this.leechBuffDuration, this.g_Mutex.lastUsedLeech, true)


    ;         ; 4. 最终聚合
    ;         local available := ready_flag && LimitUsedOpen && using_flag

    ;         if(this.g_Mutex.CanExecute(5) && available){
    ;             this.SendKey("3", "LogEngine-Send-Open")
    ;             this.g_Mutex.OnExecuted(5)
    ;             this.lastUsedOpen := HiResTimer.GetTick()
    ;             return true
    ;         }
    ;         return false
    ;     } finally{
    ;         PerformanceMonitor.End("LogEngine-Logic-Open")
    ;     }
    ; }

    ; /**
    ;  * 
    ;  * @returns {Boolean} return true 表示等待Leech打出，false 表示continue
    ;  */
    ; static _Leech_1(){
    ;     PerformanceMonitor.Start("LogEngine-Logic-Leech")

    ;     try {
    ;         ; 1. 检测Leech图标
    ;         preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false)

    ;         if (!preLeech) {
    ;             return false
    ;         }

    ;         hasLeechBuff := StateManager._buffState.Get("Leech", false)
    ;         hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)

    ;         allowLeech := false

    ;         ; 2. 判断是否启用只打自己的烙印
    ;         local allowUsedLeechFromMySelf := this.g_isUsedLeechFromMySelf ?
    ;         (
    ;             this.BrandTriggerTime <= HiResTimer.GetTick()
    ;             &&
    ;             this.BrandOverTime == -1 ? true : HiResTimer.GetTick() <= this.BrandOverTime
    ;         ) : true

    ;         ; 3. 按照不同条件判断是否当前可用Leech
    ;         if (hasSoulFlareBuff) {
    ;             if (!hasLeechBuff) {
    ;                 allowLeech := true
    ;             }
    ;         } else if (!hasSoulFlareBuff) {
    ;             if (!hasLeechBuff) {
    ;                 allowLeech := true
    ;             }
    ;             else if (this.g_isUseLeechHasLeechBuff && hasLeechBuff && allowUsedLeechFromMySelf) {
    ;                 local LimitUsedLeech := this._LimitLeechOrOpenCondition(this.g_limitationLeech)
    ;                 allowLeech := true && LimitUsedLeech
    ;             }
    ;             else {
    ;                 allowLeech := false
    ;             }
    ;         }
    ;         /**
    ;          * 1. Leech图标就绪
    ;          * 1.1 
    ;          * 2. Leech图标未好
    ;          */

    ;         LeechReady := StateManager._skillState.Get("Leech_R", false)
    ;         if (allowLeech && preLeech) {
    ;             if (!LeechReady) {
    ;                 ; OutputDebug "waiting Leech"
    ;                 return true
    ;             }

    ;             if (LeechReady && HiResTimer.DeltaMs(this.lastUsedLeech, HiResTimer.GetTick()) >= LOGIC_INTERVAL) {
    ;                 this.SendKey("f", "LogEngine-Send-Leech")
    ;                 this.lastUsedLeech := HiResTimer.GetTick()
    ;                 this.g_Mutex.OnExecuted(3)
    ;                 ; OutputDebug "use Leech, " HiResTimer.GetTick()
    ;                 this.flag_press_leech := true
    ;                 return true
    ;             }
    ;         }
    ;         ; OutputDebug "skip Leech"
    ;         return false

    ;     } finally {
    ;         PerformanceMonitor.End("LogEngine-Logic-Leech")

    ;     }
    ; }




}


 