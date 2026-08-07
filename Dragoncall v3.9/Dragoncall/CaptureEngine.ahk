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
    static DetectTimer := 0

    static Start() {
        ; 直接调用基类的静态方法
        CaptureClient.Start(A_Temp "\CaptureLogic.dll", INI)

        local idx := CaptureClient.BuildNameIndex()
        this.skillNames := idx.skillNames
        this.skillIdx   := idx.skillIdx
        this.buffNames  := idx.buffNames
        this.buffIdx    := idx.buffIdx
        ; 启动定时器
        interval := DETECT_INTERVAL   
        this.DetectTimer := SetTimer(ObjBindMethod(CaptureEngine, "UpdateState"), interval)
        for name in CaptureEngine.skillNames
            OutputDebug "Skill: " name
    }

    static UpdateState() {
        PerformanceMonitor.Start("CaptureEngine-UpdateState")
        local frameData := CaptureClient.ReadFrame()
        if !IsObject(frameData)
            return

        local start := HiResTimer.GetTick()

        ; 同步状态到 StateManager
        CaptureClient.SyncStates(frameData, this.skillIdx, this.buffIdx)

        this.frameId := frameData.frameId
        this.g_CurrentFocus := frameData.focus

        ; ---------- Dragoncall 特化逻辑 ----------
        ; 首次启动logicOffStart == 0,不走HiResTimer.DeltaMs的逻辑，如果为-1则表示启动之后进行过一次松开
        /**
         * 1. 首次使用的时候为true，使用之后为false
         * 2. 当松开侧键超过n s 之后，重新按下侧键判断是否>=N
         * 3. 
         */
        static logicOffStart := 0
        if(!LogicEngine.g_LogicEnabled){
            if (logicOffStart == -1)
                logicOffStart := HiResTimer.GetTick()
            
        }
        if(LogicEngine.g_LogicEnabled && !LogicEngine.g_Mutex.isSFirst){
            if(HiResTimer.DeltaMs(logicOffStart, HiResTimer.GetTick()) >= 5 * 1000){
                LogicEngine.g_Mutex.MarkSFirst()
            }
            logicOffStart := -1
        }




        ; 首次观察到Dragoncall亮起
        Dragoncall_Bridge := StateManager._skillState.Get("Dragoncall_L_Bridge", false)
        if(Dragoncall_Bridge){
            if(DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd == -1){
                DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd := HiResTimer.GetTick()
                OutputDebug "首次观察到Dragoncall亮起,记录时间戳: " DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd
            }else {
                ; 有值,判断是否超过ResetLimit阈值,重置
                if(HiResTimer.DeltaMs(DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd, HiResTimer.GetTick()) >= DragoncallConfig.Dragoncall_Bridge_Limit_Reset){
                    ; Reset
                    DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd := HiResTimer.GetTick()
                    OutputDebug "Dragoncall亮起时间超过阈值，重置时间戳: " DragoncallConfig.Dragoncall_Bridge_first_Observe_Reconrd
                }
            }

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