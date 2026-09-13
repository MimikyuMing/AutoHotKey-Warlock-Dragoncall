#Requires AutoHotkey v2.0

/**
 * 運行時狀態
 */

#Include CoreMutex.ahk

class RuntimeContext {
    config := ""
    state  := ""
    mutex  := ""

    __New() {
        this.config := RuntimeContext.ConfigSection()
        this.state  := RuntimeContext.StateSection()
        this.mutex := CoreMutex()
        this.InitState()
    }


    InitState() {
        base := HiResTimer.AddMs(-15000)
        s := this.state
        s.lastUsedSoulFlare    := base
        s.lastUsedMantra       := base
        s.lastUsedLeech        := base
        s.lastUsedBombardment  := base
        s.lastUsedDragoncall   := base
        s.lastUsedWingstorm    := base
        s.lastUsedOpen         := base
        s.lastUsedRupture      := base
        s.BrandOverTime        := -1
        s.BrandTriggerTime     := -1
        s.flag_press_open      := 0
        s.flag_press_leech     := 0
        s.delayTab             := 0
        s.lastFrameId          := 0
        s.lastLogicTimeUs      := 0
        s.lastWriteTable       := 0
    }

    class ConfigSection {
        ; 从 INI 读，只读
        goldWingstorm              := false
        goldOpen                   := false
        autoSoulFlare              := false
        isUseLeechHasLeechBuff     := false
        limitationOpen             := false
        limitationLeech            := false
        goldLeech                  := false
        enablePriorityUseDragoncall := 0
        isUseOpenHasSoulFlareBuff  := false
        isUsedLeechFromMySelf      := false

        leechBuffDuration := this.goldLeech ? 18 : 15
    }

    class StateSection {
        ; 运行时可变
        lastUsedLeech := -1
        lastUsedMantra := -1
        lastUsedBombardment := -1
        lastUsedDragoncall := -1
        lastUsedWingstorm := -1
        lastUsedOpen := -1
        lastUsedRupture := -1
        lastUsedSoulFlare := -1
        BrandOverTime := -1
        BrandTriggerTime := -1

        ; 标记
        flag_press_open := 0
        flag_press_leech := 0
        delayTab := 0

        ; 引擎状态
        logicEnabled         := false
        lastFrameId          := 0
        lastLogicTimeUs      := 0
        lastWriteTable       := 0
    }
}