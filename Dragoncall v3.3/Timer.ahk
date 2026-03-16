#Requires AutoHotkey v2.0

#Include RunningStatus.ahk
#Include Skill\SkillLoop.ahk
#Include Gui.ahk
#Include Skill\SkillStatus.ahk

global GuiTimerId := 0
global ExecuteTimerId := 0
global CheckTimerId := 0

StartGuiTimer(){
    global GuiTimerId
    GuiTimerId := SetTimer(GuiProxy.Bind(), -GuiDelay)
}


StopGuiTimer(){
    global GuiTimerId
    if (GuiTimerId){
        SetTimer(GuiTimerId, 0)
        GuiTimerId := 0
    }
}

StartExecuteTimer(){
    global ExecuteTimerId
    if (!RunningStatus['isRunning'])
        return
    RunningStatus['isHolding'] := true
    ExecuteTimerId := SetTimer(SkillMainProxy.Bind(), -SkillLoopDelay)

}



StopExecuteTimer(){
    global ExecuteTimerId
    RunningStatus['isHolding'] := false
    if (ExecuteTimerId){
        SetTimer(ExecuteTimerId, 0)
        ExecuteTimerId := 0
    }
}

StartCheckTimer(){  
    global CheckTimerId
    CheckTimerId := SetTimer(SkillStatusProxy.Bind(), -SkillStatusDelay)
}



StopCheckTimer(){
    global CheckTimerId
    if (CheckTimerId){
        SetTimer(CheckTimerId, 0)
        CheckTimerId := 0
    }
}

; 代理对象

global SkillLoopDelay := 10
global SkillStatusDelay := 20
global GuiDelay := 100

SkillMainProxy(*){
    global SkillTimestamp, ExecuteTimerId, ExecutionStats, SkillLoopDelay

    local startTimestamp := A_TickCount

    SkillLoop()

    local endTimestamp := A_TickCount
    local duration := endTimestamp - startTimestamp
    UpdateExecutionStats(duration, SkillCnt)

    ; 循环尾部：如果还在运行则重设一次性定时器
    if (RunningStatus['isHolding'] && RunningStatus['isRunning']) {
        ExecuteTimerId := SetTimer(SkillMainProxy.Bind(), -SkillLoopDelay)
    }
}

SkillStatusProxy(*){
    global SkillStatusTimestamp, CheckTimerId, DetectionStats
    local startTimestamp := A_TickCount  

    SkillStatusCheck()

    local endTimestamp := A_TickCount
    local duration := endTimestamp - startTimestamp

    UpdateDetectionStats(duration)
    
    ; 设置全局时间戳（供GUI使用）
    SkillStatusTimestamp := duration

    ; 循环尾部：如果还在运行则重设一次性定时器
    if (RunningStatus['isRunning']) {
        CheckTimerId := SetTimer(SkillStatusProxy.Bind(), -SkillStatusDelay)
    }
}

GuiProxy(*){
    global GuiTimerId
    UpdateLoop()
    ; 循环尾部：如果还在运行则重设一次性定时器
    if (RunningStatus['isRunning']) {
        GuiTimerId := SetTimer(GuiProxy.Bind(), -GuiDelay)
    }
}

UpdateExecutionStats(duration, operationsCount) {
    global ExecutionStats
    
    ; 更新基础统计
    ExecutionStats.lastDuration := duration
    ExecutionStats.totalExecutions++
    ExecutionStats.totalDuration += duration
    
    ; 更新最小/最大耗时
    if (duration < ExecutionStats.minDuration) {
        ExecutionStats.minDuration := duration
    }
    if (duration > ExecutionStats.maxDuration) {
        ExecutionStats.maxDuration := duration
    }
    
    ; 更新平均耗时
    ExecutionStats.avgDuration := Round(ExecutionStats.totalDuration / ExecutionStats.totalExecutions)
    
    ; 添加到历史记录
    ExecutionStats.history.Push({
        timestamp: A_TickCount,
        duration: duration,
        operations: operationsCount
    })
    
    ; 清理历史记录
    if (ExecutionStats.history.Length > ExecutionStats.maxHistorySize) {
        ExecutionStats.history.RemoveAt(1)
    }
    
    ; 清理30秒前的历史记录
    local cutoffTime := A_TickCount - 30000
    while (ExecutionStats.history.Length > 0 && ExecutionStats.history[1].timestamp < cutoffTime) {
        ExecutionStats.history.RemoveAt(1)
    }
}

UpdateDetectionStats(duration) {
    global DetectionStats
    
    ; 更新基础统计
    DetectionStats.lastDuration := duration
    DetectionStats.totalDetections++
    DetectionStats.totalDuration += duration
    
    ; 更新最小/最大耗时
    if (duration < DetectionStats.minDuration) {
        DetectionStats.minDuration := duration
    }
    if (duration > DetectionStats.maxDuration) {
        DetectionStats.maxDuration := duration
    }
    
    ; 更新平均耗时
    DetectionStats.avgDuration := Round(DetectionStats.totalDuration / DetectionStats.totalDetections)
    
    ; 添加到历史记录
    DetectionStats.history.Push({
        timestamp: A_TickCount,
        duration: duration
    })
    
    ; 清理历史记录
    if (DetectionStats.history.Length > DetectionStats.maxHistorySize) {
        DetectionStats.history.RemoveAt(1)
    }
    
    ; 清理30秒前的历史记录
    local cutoffTime := A_TickCount - 30000
    while (DetectionStats.history.Length > 0 && DetectionStats.history[1].timestamp < cutoffTime) {
        DetectionStats.history.RemoveAt(1)
    }
}




global ExecutionStats := {
    lastDuration: 0,
    avgDuration: 0,
    minDuration: 9999,
    maxDuration: 0,
    totalExecutions: 0,
    totalDuration: 0,
    history: [],
    maxHistorySize: 100
}

global DetectionStats := {
    lastDuration: 0,
    avgDuration: 0,
    minDuration: 9999,
    maxDuration: 0,
    totalDetections: 0,
    totalDuration: 0,
    history: [],
    maxHistorySize: 100
}