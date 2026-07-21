#Requires AutoHotkey v2.0

#Include ..\Lib\CaptureClient.ahk
#Include LogicEngine.ahk
#Include ..\Lib\HiResTimer.ahk
#Include ..\Lib\Globals.ahk
#Include ..\Lib\PerformanceMonitor.ahk


; Lib\CaptureEngine.ahk
class CaptureEngine extends CaptureClient {
    static frameId := 0
    static g_CurrentFocus := -1
    static g_LastUpdateStateTime := 0
    static skillNames := [], skillIdx := Map()
    static buffNames := [], buffIdx := Map()
    static DetectTimer := 0
    static RealtimeMode := 0

    static Start() {
        ; 直接调用基类的静态方法
        CaptureClient.Start(A_Temp "\CaptureLogic.dll", INI)

        ; 构建名称索引
        local idx := CaptureClient.BuildNameIndex()
        this.skillNames := idx.skillNames
        this.skillIdx   := idx.skillIdx
        this.buffNames  := idx.buffNames
        this.buffIdx    := idx.buffIdx

        ; 启动定时器
        interval := (this.RealtimeMode ? 1 : DETECT_INTERVAL)   ; 实时=1ms
        this.DetectTimer := SetTimer(ObjBindMethod(CaptureEngine, "UpdateState"), interval)
    }

    static UpdateState() {
        PerformanceMonitor.Start("UpdateState")
        local frameData := CaptureClient.ReadFrame()
        if !IsObject(frameData)
            return

        local start := HiResTimer.GetTick()

        ; 同步状态到 StateManager
        CaptureClient.SyncStates(frameData, this.skillIdx, this.buffIdx)

        this.frameId := frameData.frameId
        this.g_CurrentFocus := frameData.focus

        ; ---------- Dragoncall 特化逻辑 ----------
        static logicOffStart := 0
        if (!LogicEngine.g_LogicEnabled) {
            if (logicOffStart == 0)
                logicOffStart := HiResTimer.GetTick()
            else if (HiResTimer.SubMs(5000, HiResTimer.GetTick()) > logicOffStart) {
                logicOffStart := 0
                LogicEngine.g_Mutex.MarkSFirst()
            }
            LogicEngine.startLogic := HiResTimer.GetTick()
        } else {
            logicOffStart := 0
        }
        this.g_LastUpdateStateTime := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
        PerformanceMonitor.End("UpdateState")
    }

    static Cleanup() {
        CaptureClient.Cleanup()
    }
}