#Requires AutoHotkey v2.0

#Include ..\Lib\StatusMonitor.ahk
#Include ..\Lib\StateManager.ahk

class DragoncallStatusMonitor extends StatusMonitor {

    intervalMs := 10 ; 100 ms
    posX := 720
    posY := 570

    Start(){
        super.Start(this.intervalMs, this.posX, this.posY)
    }

    Report(){
        msg := ""
        hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
        hasLeechBuff      := StateManager._buffState.Get("Leech", false)
        if(hasLeechBuff)
            msg .= "搶奪: " hasLeechBuff "`n"
        if(hasSoulFlareBuff)
            msg .= "降臨: " hasSoulFlareBuff "`n"
        return msg
    }
}