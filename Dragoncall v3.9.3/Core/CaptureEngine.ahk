#Requires AutoHotkey v2.0

#Include CoreConfig.ahk

class CaptureEngine extends CaptureClient {
    static frameId := 0
    static g_CurrentFocus := -1
    static g_LastUpdateStateTime := 0
    static skillNames := [], skillIdx := Map()
    static buffNames := [], buffIdx := Map()
    static coldDownNames := [], coldDownIdx := Map()
    static DetectTimer := 0
    static debugShowSlots := false
    static debugShowSlotsInterval := 50
    static debugLastShowTime := 0

    static Start() {
        CaptureClient.Start(A_Temp "\CaptureLogic.dll", App.configPath)

        local idx := CaptureClient.BuildNameIndex()
        this.skillNames := idx.skillNames
        this.skillIdx := idx.skillIdx
        this.buffNames := idx.buffNames
        this.buffIdx := idx.buffIdx
        this.coldDownNames := idx.coldDownNames
        this.coldDownIdx := idx.coldDownIdx

        interval := DETECT_INTERVAL
        this.DetectTimer := SetTimer(ObjBindMethod(CaptureEngine, "UpdateState"), interval)
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

        ; ---------- isSFirst 判定 ----------
        static logicOffStart := -1
        if (!App.ctx.state.logicEnabled) {
            if (logicOffStart == -1)
                logicOffStart := HiResTimer.GetTick()
        }
        if (App.ctx.state.logicEnabled && !App.ctx.mutex.isSFirst) {
            if (HiResTimer.DeltaMs(logicOffStart, HiResTimer.GetTick()) >= 5 * 1000) {
                App.ctx.mutex.MarkSFirst()
            }
            logicOffStart := -1
        }
        static l := -1
        if (!App.ctx.mutex.isSFirst) {
            ; OutputDebug "state: " App.ctx.mutex.isSFirst " , timestamp: " HiResTimer.GetTick() " , logicOffStart: " logicOffStart
            l := HiResTimer.GetTick()
        }

        ; ---------- Dragoncall 桥接观察 ----------
        Dragoncall_Bridge := StateManager._skillState.Get("Critical_Dragoncall", false)
        if (Dragoncall_Bridge && !(HiResTimer.DeltaMs(CoreConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) <= 10)) {
            CoreConfig.Dragoncall_Bridge_first_Observe_Reconrd := HiResTimer.GetTick()
        }

        this.g_LastUpdateStateTime := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
        PerformanceMonitor.End("CaptureEngine-UpdateState")
    }

    static Cleanup() {
        if this.DetectTimer {
            SetTimer(this.DetectTimer, 0)
            this.DetectTimer := 0
        }
        CaptureClient.isValid := false
        CaptureClient.Cleanup()
    }
}