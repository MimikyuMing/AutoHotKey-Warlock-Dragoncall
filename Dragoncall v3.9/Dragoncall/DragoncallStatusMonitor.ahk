#Requires AutoHotkey v2.0

#Include ..\Lib\StatusMonitor.ahk
#Include ..\Lib\StateManager.ahk

class DragoncallStatusMonitor extends StatusMonitor {

    Start(obj, duration, intervalMs, posX, posY) {
        gameHwnd := WinExist("ahk_exe BNSR.exe")
        this.displayDuration := duration
        super.Start(obj, duration, intervalMs, posX, posY, gameHwnd)
    }

    Report() {
        msg := ""
        hasLeechBuff      := StateManager._buffState.Get("Leech", false)
        if(!hasLeechBuff)
            msg .= "搶奪: " hasLeechBuff "`n"
        return msg
    }
}