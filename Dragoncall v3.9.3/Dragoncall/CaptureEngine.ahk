#Requires AutoHotkey v2.0

#Include ..\Lib\CaptureClient.ahk
#Include LogicEngine.ahk
#Include ..\Lib\HiResTimer.ahk
#Include ..\Lib\Globals.ahk
#Include ..\Lib\PerformanceMonitor.ahk
#Include Dragoncall_Config.ahk


; Lib\CaptureEngine.ahk
class CaptureEngine extends CaptureClient {
    static frameId := 0
    static g_CurrentFocus := -1
    static g_LastUpdateStateTime := 0
    static skillNames := [], skillIdx := Map()
    static buffNames := [], buffIdx := Map()
    static coldDownNames := [], coldDownIdx := Map()
    static DetectTimer := 0
    static debugShowSlots := false ; DEBUG: 是否显示技能槽信息
    static debugShowSlotsInterval := 50 ; DEBUG: 显示技能槽信息的间隔（毫秒）
    static debugLastShowTime := 0 ; DEBUG: 上次显示技能槽信息的时间戳

    static Start() {
        ; 直接调用基类的静态方法
        CaptureClient.Start(A_Temp "\CaptureLogic.dll", INI)

        local idx := CaptureClient.BuildNameIndex()
        this.skillNames := idx.skillNames
        this.skillIdx := idx.skillIdx
        this.buffNames := idx.buffNames
        this.buffIdx := idx.buffIdx
        this.coldDownNames := idx.coldDownNames
        this.coldDownIdx := idx.coldDownIdx
        ; 启动定时器
        interval := DETECT_INTERVAL
        this.DetectTimer := SetTimer(ObjBindMethod(CaptureEngine, "UpdateState"), interval)
        ; for name in CaptureEngine.skillNames
        ;     OutputDebug "Skill: " name
    }

    static UpdateState() {
        PerformanceMonitor.Start("CaptureEngine-UpdateState")
        local frameData := CaptureClient.ReadFrame()
        if !IsObject(frameData)
            return

        local start := HiResTimer.GetTick()

        ; 同步状态到 StateManager
        CaptureClient.SyncStates(frameData, this.skillIdx, this.buffIdx, this.coldDownIdx)

        this.frameId := frameData.frameId
        this.g_CurrentFocus := frameData.focus

        ; ---------- Dragoncall 特化逻辑 ----------
        ; 首次启动logicOffStart == 0,不走HiResTimer.DeltaMs的逻辑，如果为-1则表示启动之后进行过一次松开
        /**
         * 1. 首次使用的时候为true，使用之后为false
         * 2. 当松开侧键超过n s 之后，重新按下侧键判断是否>=N
         * 3. 
         */
        static logicOffStart := -1
        if (!LogicEngine.g_LogicEnabled) {
            if (logicOffStart == -1)
                logicOffStart := HiResTimer.GetTick()

        }
        if (LogicEngine.g_LogicEnabled && !LogicEngine.g_Mutex.isSFirst) {
            if (HiResTimer.DeltaMs(logicOffStart, HiResTimer.GetTick()) >= 5 * 1000) {
                LogicEngine.g_Mutex.MarkSFirst()
            }
            logicOffStart := -1
        }
        static l := -1
        if (!LogicEngine.g_Mutex.isSFirst) {
            OutputDebug "state: " LogicEngine.g_Mutex.isSFirst " , timestamp: " HiResTimer.GetTick() " , logicOffStart: " logicOffStart
            l := HiResTimer.GetTick()
        }


        ; 首次观察到Dragoncall亮起
        Dragoncall_Bridge := StateManager._skillState.Get("Critical_Dragoncall", false)
        
        if (Dragoncall_Bridge && !(HiResTimer.DeltaMs(DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) <= 10)) {
            DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd := HiResTimer.GetTick()
        }

        this.g_LastUpdateStateTime := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
        PerformanceMonitor.End("CaptureEngine-UpdateState")
    }

    static Cleanup() {
        ; 1. 停止定时器，防止回调访问已释放的资源
        if this.DetectTimer {
            SetTimer(this.DetectTimer, 0)
            this.DetectTimer := 0
        }
        ; 2. 设置无效标志（可选，但强烈建议）
        CaptureClient.isValid := false
        CaptureClient.Cleanup()
    }
}