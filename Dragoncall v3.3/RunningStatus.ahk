#Requires AutoHotkey v2.0

global RunningStatus := Map() ; 运行状态管理

InitRunningStatus(){
    global RunningStatus
    RunningStatus['isRunning'] := false
    RunningStatus['isHolding'] := false
    RunningStatus['isShowing'] := false
}