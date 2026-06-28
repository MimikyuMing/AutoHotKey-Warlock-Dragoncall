#Requires AutoHotkey v2.0

global GoldWingstorm := false, AutoSoulFlare:= false, RandomLimit := 5, BaseLimit := 10, Limit := BaseLimit, isLeechBuffNoUsedLeech := true
; 启动


global DefaultConfigFilePath := A_ScriptDir "\config.ini"

global EnableSkill := Map() ; 技能开关管理
global SkillCondition := Map() ; 技能条件管理


InitSkillCondition(){
    global SkillCondition
    SkillCondition['Mantra'] := Map()
    SkillCondition['Rupture'] := Map()

    SkillCondition['Mantra']['Normal'] := 6
    SkillCondition['Mantra']['IsLeech'] := 6 
    SkillCondition['Mantra']['IsSoulFlare'] := 3

    SkillCondition['Rupture']['Normal'] := 5
    SkillCondition['Rupture']['IsLeech'] := 3
    SkillCondition['Rupture']['IsSoulFlare'] := 1

}

InitHotKeys(){
    global StartOrStopKey, ToggleKey, DoggeKey, ShowOrHideKey, ReloadKey
    StartOrStopKey := '^F11' ; isRunning 切换热键
    ToggleKey := 'XButton2' ; isHolding 热键
    DoggeKey := 'XButton1'
    ShowOrHideKey := '^F3'  ; isShowing 切换热键
    ReloadKey := '^F5'
}

InitHotKeys()
InitRunningStatus()
; 热键绑定

Hotkey StartOrStopKey, Running

Running(*) {
    global RunningStatus    
    RunningStatus['isRunning'] := !RunningStatus['isRunning']
    if (RunningStatus['isRunning']) {
        RunningStatus['isShowing'] := true
        ; 1. 启动状态检测定时器
        StartCheckTimer()
        StartGuiTimer()
        ShowOrHideGui()
        ToolTip("宏已启动", 0, 0)
        SetTimer(() => ToolTip(), 2000)
    } else {
        RunningStatus['isHolding'] := false
        RunningStatus['isShowing'] := false
        StopCheckTimer()
        StopGuiTimer()
        ShowOrHideGui()
        ToolTip("宏已停止", 0, 0)
        SetTimer(() => ToolTip(), 2000)
    }
}

Hotkey ToggleKey, CombatStart
CombatStart(*){
    ; 1. 启动逻辑定时器
    if (RunningStatus['isRunning']) 
        StartExecuteTimer()
}


Hotkey ToggleKey " up", CombatStop
CombatStop(*){
    ; ToolTip "!!!"
    if (RunningStatus['isRunning']) 
        StopExecuteTimer()
}

Hotkey DoggeKey, Dogge
Dogge(*){
    if (RunningStatus['isRunning']){
        SetTimer(DoggeProxy.Bind(),-1, 15)
    }
}

DoggeProxy(){
    Send '^{Numpad9}'
}

Hotkey ReloadKey, ReloadScript, "P10"
ReloadScript(*){
    Reload
}

Hotkey ShowOrHideKey, ShowOrHideGui, "P8"
ShowOrHideGui(*){
    RunningStatus['isShowing'] := !RunningStatus['isShowing']
    UpdateGui()
}

global SkillCnt := 0
global SkillTimestamp := 0
global SkillStatusTimestamp := 0
global LoopDelay_Gui := 1000
global GuiModel := ''
global LastSkillLoopExecution := 0
global LastSkillStatusCheck := 0




; 操作统计相关变量
global operationHistory := []  ; 存储每秒操作数记录
global maxHistorySize := 60    ; 60秒数据
global lastSkillCnt := 0       ; 上一次记录的SkillCnt值
global lastStatsTime := 0      ; 上一次统计时间
global totalOperations := 0    ; 总操作次数

; 性能统计相关变量
global performanceHistory := [] ; 性能历史记录
global lastExecutionTime := 0
global lastDetectionTime := 0
global SkillCnt := 0
global SkillTimestamp := 0
global SkillStatusTimestamp := 0
global LoopDelay_Gui := 100
global GuiModel := ''

; GUI更新定时器ID
global GuiTimerId := 0

; 操作统计相关变量（保持向后兼容）
global operationHistory := []  ; 存储每秒操作数记录
global maxHistorySize := 60    ; 60秒数据
global lastSkillCnt := 0       ; 上一次记录的SkillCnt值
global lastStatsTime := 0      ; 上一次统计时间
global totalOperations := 0    ; 总操作次数

; 性能统计相关变量（保持向后兼容）
global performanceHistory := [] ; 性能历史记录
global lastExecutionTime := 0
global lastDetectionTime := 0

; ================================================
; GUI创建和管理函数
; ================================================

UpdateGui(*){
    global GuiModel, RunningStatus, GuiTimerId
    
    if (RunningStatus['isShowing'] && RunningStatus['isRunning']) {
        if(!GuiModel){
            CreateGUI()
        }
        GuiModel.Show('NoActivate')
        
        ; 启动GUI更新定时器（确保只有一个）
        if (!GuiTimerId) {
            GuiTimerId := SetTimer(UpdateLoop, -200)
        }
    } else{
        if(GuiModel){
            GuiModel.Hide()
        }
        
        ; 停止GUI更新定时器
        if (GuiTimerId) {
            SetTimer(GuiTimerId, 0)
            GuiTimerId := 0
        }
    }
}

CreateGUI() {
    global GuiModel
    if (GuiModel) {
        try {
            GuiModel.Destroy()
        } catch {
            ; 忽略销毁错误
        }
    }
    
    GuiModel := Gui("+AlwaysOnTop +ToolWindow -Caption +Border")
    GuiModel.BackColor := "1A1A1A"
    GuiModel.MarginX := 10
    GuiModel.MarginY := 8
    
    ; 设置窗口透明度
    WinSetTransparent(230, GuiModel)
    
    ; 设置圆角
    SetRoundedCorners(12)
    
    ; 添加拖拽区域
    AddDragOverlay()
    
    ; 添加标题栏
    AddTitleBar()
    
    ; 添加内容区域
    AddContentArea()
    
    ; 显示在屏幕右上角
    GuiModel.Show("x" (A_ScreenWidth-260) " y20"  " w250 h360 NoActivate")
    GuiModel.Hide()
}

SetRoundedCorners(radius := 12) {
    global GuiModel
    hwnd := GuiModel.Hwnd
    region := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", 250, "int", 360, "int", radius, "int", radius, "ptr")
    DllCall("SetWindowRgn", "ptr", hwnd, "ptr", region, "int", true)
}

AddDragOverlay() {
    global GuiModel
    dragOverlay := GuiModel.Add("Text", "x0 y0 w250 h40 BackgroundTrans", " ")
    dragOverlay.OnEvent("Click", DragGUI)
}

DragGUI(*) {
    global GuiModel
    PostMessage(0xA1, 2, 0, GuiModel)
}

AddTitleBar() {
    global GuiModel
    ; 标题栏背景
    titleBar := GuiModel.Add("Text", "x0 y0 w250 h40 Background333333", "")
    
    ; 标题文字
    titleText := GuiModel.Add("Text", "x0 y10 w250 h20 BackgroundTrans cWhite Center", "🎮 技能监控面板")
    titleText.SetFont("s10 Bold cWhite", "Segoe UI")
    
    ; 状态指示器
    global statusIndicator := GuiModel.Add("Text", "x10 y12 w8 h8 BackgroundRed", "")
    statusIndicator.SetFont("s1", "Segoe UI")
    
    ; 分隔线
    GuiModel.Add("Text", "x0 y40 w250 h2 Background555555", "")
}

AddContentArea() {
    global GuiModel
    
    ; 第一区块：运行状态
    AddRunningStatusSection()
    
    ; 分隔线
    GuiModel.Add("Text", "x10 y88 w230 h1 Background555555", "")
    
    ; 第二区块：技能状态
    AddSkillStatusSection()
    
    ; 分隔线
    GuiModel.Add("Text", "x10 y165 w230 h1 Background555555", "")
    
    ; 第三区块：性能统计
    AddPerformanceStatsSection()
    
    ; 分隔线
    GuiModel.Add("Text", "x10 y245 w230 h1 Background555555", "")
    
    ; 第四区块：操作统计
    AddOperationStatsSection()
}

AddRunningStatusSection() {
    global GuiModel
    
    ; 区块标题
    sectionTitle := GuiModel.Add("Text", "x10 y50 w230 h20 BackgroundTrans cLime", "📊 运行状态")
    sectionTitle.SetFont("s9 Bold cLime", "Segoe UI")
    
    GuiModel.SetFont("s8 Norm cWhite", "Segoe UI")
    
    ; 运行状态
    global runningStatusText := GuiModel.Add("Text", "x15 y72 w110 h18 BackgroundTrans", "运行: --")
    
    ; 触发状态
    global holdingStatusText := GuiModel.Add("Text", "x135 y72 w110 h18 BackgroundTrans", "触发: --")
}

AddSkillStatusSection() {
    global GuiModel
    
    ; 区块标题
    sectionTitle := GuiModel.Add("Text", "x10 y90 w230 h20 BackgroundTrans cAqua", "🔮 技能状态")
    sectionTitle.SetFont("s9 Bold cAqua", "Segoe UI")
    
    GuiModel.SetFont("s8 Norm cWhite", "Segoe UI")
    
    ; 第一行
    global dragoncallText := GuiModel.Add("Text", "x15 y112 w110 h18 BackgroundTrans", "暴魔灵: --")
    global wingstormText := GuiModel.Add("Text", "x135 y112 w110 h18 BackgroundTrans", "死灵突: --")
    
    ; 第二行
    global soulflareText := GuiModel.Add("Text", "x15 y130 w110 h18 BackgroundTrans", "降临: --")
    global leechText := GuiModel.Add("Text", "x135 y130 w110 h18 BackgroundTrans", "掠夺: --")
    
    ; 第三行
    global mantraText := GuiModel.Add("Text", "x15 y148 w110 h18 BackgroundTrans", "真言: --")
    global ruptureText := GuiModel.Add("Text", "x135 y148 w110 h18 BackgroundTrans", "破裂: --")
}

AddPerformanceStatsSection() {
    global GuiModel
    
    ; 区块标题
    sectionTitle := GuiModel.Add("Text", "x10 y170 w230 h20 BackgroundTrans cYellow", "⚡ 性能统计")
    sectionTitle.SetFont("s9 Bold cYellow", "Segoe UI")
    
    GuiModel.SetFont("s8 Norm cWhite", "Segoe UI")
    
    ; 执行器耗时
    global executionTimeText := GuiModel.Add("Text", "x15 y192 w230 h18 BackgroundTrans", "执行器: --ms")
    
    ; 检测器耗时
    global detectionTimeText := GuiModel.Add("Text", "x15 y210 w230 h18 BackgroundTrans", "检测器: --ms")
    
    ; 平均耗时
    global avgExecutionTimeText := GuiModel.Add("Text", "x15 y228 w110 h18 BackgroundTrans", "平均: --ms")
    global avgDetectionTimeText := GuiModel.Add("Text", "x135 y228 w110 h18 BackgroundTrans", "平均: --ms")
}

AddOperationStatsSection() {
    global GuiModel
    
    ; 区块标题
    sectionTitle := GuiModel.Add("Text", "x10 y250 w230 h20 BackgroundTrans cFuchsia", "📈 操作统计")
    sectionTitle.SetFont("s9 Bold cFuchsia", "Segoe UI")
    
    GuiModel.SetFont("s8 Norm cWhite", "Segoe UI")
    
    ; 第一行：当前和平均
    global currentOpsText := GuiModel.Add("Text", "x15 y272 w110 h18 BackgroundTrans", "当前: --/s")
    global avgOpsText := GuiModel.Add("Text", "x135 y272 w110 h18 BackgroundTrans", "平均: --/s")
    
    ; 第二行：最大和最小
    global maxOpsText := GuiModel.Add("Text", "x15 y290 w110 h18 BackgroundTrans", "最大: --/s")
    global minOpsText := GuiModel.Add("Text", "x135 y290 w110 h18 BackgroundTrans", "最小: --/s")
    
    ; 第三行：总数和历史
    global totalOpsText := GuiModel.Add("Text", "x15 y308 w110 h18 BackgroundTrans", "总数: --")
    global historyText := GuiModel.Add("Text", "x135 y308 w110 h18 BackgroundTrans", "历史: --s")
    
    ; 最后更新
    global lastUpdateText := GuiModel.Add("Text", "x15 y326 w230 h18 BackgroundTrans cSilver", "更新: --")
}

; ================================================
; 核心更新函数（向后兼容）
; ================================================

UpdateLoop() {
    static lastRenderEnd := 0, lastUpdate := 0
    if (A_TickCount - lastRenderEnd < LoopDelay_Gui) {
        return
    }
    if (!RunningStatus['isRunning']) 
        return
    
    if (A_TickCount - lastUpdate >= LoopDelay_Gui) {
        ; 保持向后兼容的统计更新
        UpdateOperationStats()
        UpdatePerformanceStats()
        RenderHUD()
        lastUpdate := A_TickCount
    }   
    lastRenderEnd := A_TickCount
}

UpdateOperationStats() {
    global SkillCnt, lastStatsTime, totalOperations, operationHistory
    
    local currentTime := A_TickCount
    
    ; 每秒统计一次操作频率
    if (currentTime - lastStatsTime >= 1000) {
        ; 计算当前秒内的操作次数（从SkillCnt增量获取）
        local currentOps := SkillCnt
        
        ; 确保不会出现负数（脚本重载时可能发生）
        if (currentOps < 0) {
            currentOps := 0
        }
        
        ; 更新总操作次数
        totalOperations += currentOps
        
        ; 记录到历史
        operationHistory.Push({
            time: currentTime,
            ops: currentOps  ; 当前秒的操作次数
        })
        
        ; 清理超过历史大小的数据
        if (operationHistory.Length > maxHistorySize) {
            operationHistory.RemoveAt(1)
        }
        
        ; 更新记录值
        lastStatsTime := currentTime
    }
}

UpdatePerformanceStats() {
    global SkillTimestamp, SkillStatusTimestamp, performanceHistory
    global lastExecutionTime, lastDetectionTime
    
    local currentTime := A_TickCount
    
    ; 只记录有效的耗时数据（大于0）
    if (SkillTimestamp > 0 || SkillStatusTimestamp > 0) {
        performanceHistory.Push({
            time: currentTime,
            executionTime: SkillTimestamp,
            detectionTime: SkillStatusTimestamp,
            executionInterval: lastExecutionTime > 0 ? currentTime - lastExecutionTime : 0,
            detectionInterval: lastDetectionTime > 0 ? currentTime - lastDetectionTime : 0
        })
        
        ; 更新时间戳
        if (SkillTimestamp > 0) {
            lastExecutionTime := currentTime
        }
        if (SkillStatusTimestamp > 0) {
            lastDetectionTime := currentTime
        }
        
        ; 清理30秒前的数据
        local cutoffTime := currentTime - 30000
        while (performanceHistory.Length > 0 && performanceHistory[1].time < cutoffTime) {
            performanceHistory.RemoveAt(1)
        }
        
        if (performanceHistory.Length > maxHistorySize) {
            performanceHistory.RemoveAt(1)
        }
    }
}

; ================================================
; 统计获取函数（使用Timer.ahk中的增强数据）
; ================================================

GetOperationStats() {
    ; 首先尝试从Timer.ahk的增强统计数据获取
    global ExecutionStats
    if (ExecutionStats) {
        ; 计算最近1秒的操作数
        local recentTotal := 0
        local lastSecondCutoff := A_TickCount - 1000
        
        for record in ExecutionStats.history {
            if (record.timestamp >= lastSecondCutoff) {
                recentTotal += record.operations
            } 
        }
        
        ; 计算历史统计数据
        global totalOps := 0
        local minOps := 9999
        local maxOps := 0
        local validCount := 0
        
        for record in ExecutionStats.history {
            local ops := record.operations
            if (ops >= 0) {
                totalOps += ops
                validCount++
                
                if (ops < minOps)
                    minOps := ops
                if (ops > maxOps) 
                    maxOps := ops
            }
        }
        ; ToolTip(totalOps "," validCount)
        
        local avgOps := validCount > 0 ? Round(totalOps / validCount, 1) : 0
        
        return {
            current: recentTotal,
            avg: avgOps,
            min: minOps == 9999 ? 0 : minOps,
            max: maxOps,
            total: ExecutionStats.totalExecutions,
            historySize: ExecutionStats.history.Length
        }
    }
    
    ; 如果没有增强数据，使用向后兼容的方法
    global operationHistory, totalOperations
    
    if (operationHistory.Length == 0) {
        return {
            current: 0,
            avg: 0,
            min: 0,
            max: 0,
            total: totalOperations,
            historySize: 0
        }
    }
    
    local minOps := 9999
    local maxOps := 0
    local validCount := 0
    
    for record in operationHistory {
        local ops := record.ops
        if (ops >= 0) {
            totalOps += ops
            validCount++
            
            if (ops < minOps) 
                minOps := ops
            if (ops > maxOps) 
                maxOps := ops
        }
    }
    
    local currentOps := operationHistory.Length > 0 ? 
        operationHistory[operationHistory.Length].ops : 0
    
    local avgOps := validCount > 0 ? Round(totalOps / validCount, 1) : 0
    
    return {
        current: currentOps,
        avg: avgOps,
        min: minOps == 9999 ? 0 : minOps,
        max: maxOps,
        total: totalOperations,
        historySize: operationHistory.Length
    }
}

GetPerformanceStats() {
    ; 首先尝试从Timer.ahk的增强统计数据获取
    if (IsSet(ExecutionStats) && IsSet(DetectionStats)) {
        return {
            execCurrent: ExecutionStats.lastDuration,
            execAvg: ExecutionStats.avgDuration,
            execMin: ExecutionStats.minDuration == 9999 ? 0 : ExecutionStats.minDuration,
            execMax: ExecutionStats.maxDuration,
            detectCurrent: DetectionStats.lastDuration,
            detectAvg: DetectionStats.avgDuration,
            detectMin: DetectionStats.minDuration == 9999 ? 0 : DetectionStats.minDuration,
            detectMax: DetectionStats.maxDuration,
            execInterval: 0,  ; 这些可以从增强数据中计算
            detectInterval: 0
        }
    }
    
    ; 如果没有增强数据，使用向后兼容的方法
    global performanceHistory
    
    if (performanceHistory.Length == 0) {
        return {
            execCurrent: 0,
            execAvg: 0,
            execMin: 9999,
            execMax: 0,
            detectCurrent: 0,
            detectAvg: 0,
            detectMin: 9999,
            detectMax: 0,
            execInterval: 0,
            detectInterval: 0
        }
    }
    
    local execTotal := 0, execCount := 0, execCurrent := 0, execMin := 9999, execMax := 0
    local detectTotal := 0, detectCount := 0, detectCurrent := 0, detectMin := 9999, detectMax := 0
    local execInterval := 0, detectInterval := 0
    
    ; 获取最近的数据用于当前值（5秒内的最新记录）
    local recentTime := A_TickCount - 5000

    local i := performanceHistory.Length

    Loop performanceHistory.Length{
        local record := performanceHistory[i]
        i--
        if (record.time >= recentTime) {
            if (record.executionTime > 0) {
                execCurrent := record.executionTime
            }
            if (record.detectionTime > 0) {
                detectCurrent := record.detectionTime
            }
            execInterval := record.executionInterval
            detectInterval := record.detectionInterval
            break
        }
    }

    
    ; 计算统计值
    for record in performanceHistory {
        if (record.executionTime > 0) {
            execTotal += record.executionTime
            execCount++
            if (record.executionTime < execMin) 
                execMin := record.executionTime
            if (record.executionTime > execMax) 
                execMax := record.executionTime
        }
        if (record.detectionTime > 0) {
            detectTotal += record.detectionTime
            detectCount++
            if (record.detectionTime < detectMin) 
                detectMin := record.detectionTime
            if (record.detectionTime > detectMax) 
                detectMax := record.detectionTime
        }
    }
    
    return {
        execCurrent: execCurrent,
        execAvg: execCount > 0 ? Round(execTotal / execCount) : 0,
        execMin: execMin == 9999 ? 0 : execMin,
        execMax: execMax,
        detectCurrent: detectCurrent,
        detectAvg: detectCount > 0 ? Round(detectTotal / detectCount) : 0,
        detectMin: detectMin == 9999 ? 0 : detectMin,
        detectMax: detectMax,
        execInterval: execInterval,
        detectInterval: detectInterval
    }
}


; ================================================
; 获取统计数据的函数（供GUI使用）
; ================================================

GetEnhancedExecutionStats() {
    global ExecutionStats
    
    ; 计算最近1秒的平均值
    local recentTotal := 0
    local recentCount := 0
    local cutoffTime := A_TickCount - 1000
    
    for record in ExecutionStats.history {
        if (record.timestamp >= cutoffTime) {
            recentTotal += record.duration
            recentCount++
        }
    }
    
    local recentAvg := recentCount > 0 ? Round(recentTotal / recentCount) : 0
    
    ; 计算操作频率
    local recentOperations := 0
    local lastSecondCutoff := A_TickCount - 1000
    for record in ExecutionStats.history {
        if (record.timestamp >= lastSecondCutoff) {
            recentOperations += record.operations
        }
    }
    
    return {
        current: ExecutionStats.lastDuration,
        avg: ExecutionStats.avgDuration,
        recentAvg: recentAvg,
        min: ExecutionStats.minDuration == 9999 ? 0 : ExecutionStats.minDuration,
        max: ExecutionStats.maxDuration,
        totalExecutions: ExecutionStats.totalExecutions,
        recentOperations: recentOperations,
        historySize: ExecutionStats.history.Length
    }
}

GetEnhancedDetectionStats() {
    global DetectionStats
    
    ; 计算最近1秒的平均值
    local recentTotal := 0
    local recentCount := 0
    local cutoffTime := A_TickCount - 1000
    
    for record in DetectionStats.history {
        if (record.timestamp >= cutoffTime) {
            recentTotal += record.duration
            recentCount++
        }
    }
    
    local recentAvg := recentCount > 0 ? Round(recentTotal / recentCount) : 0
    
    return {
        current: DetectionStats.lastDuration,
        avg: DetectionStats.avgDuration,
        recentAvg: recentAvg,
        min: DetectionStats.minDuration == 9999 ? 0 : DetectionStats.minDuration,
        max: DetectionStats.maxDuration,
        totalDetections: DetectionStats.totalDetections,
        historySize: DetectionStats.history.Length
    }
}

; ================================================
; 主渲染函数
; ================================================

RenderHUD() {
    global GuiModel, RunningStatus
    static lastRenderTime := 0

    lastRenderTime := A_TickCount
    
    if (!RunningStatus['isShowing']) {
        UpdateHUDVisibility()
        return
    }
    
    if (!GuiModel) {
        CreateGUI()
        return
    }
    
    try {
        GuiModel.Show("NoActivate")
        
        ; 更新状态指示器
        if (RunningStatus['isRunning']) {
            if (RunningStatus['isHolding']) {
                statusIndicator.Opt("BackgroundLime")
            } else {
                statusIndicator.Opt("BackgroundYellow")
            }
        } else {
            statusIndicator.Opt("BackgroundRed")
        }
        
        ; 更新运行状态
        runningStatusText.Value := "isRuning: " (RunningStatus['isRunning'] ? "🟢" : "🔴")
        holdingStatusText.Value := "isHolding: " (RunningStatus['isHolding'] ? "🟢" : "⚪")
        
        ; 更新技能状态
        UpdateSkillStatusDisplay()
        
        ; 获取统计信息
        local perfStats := GetPerformanceStats()
        local opStats := GetOperationStats()
        
        ; 更新性能统计
        executionTimeText.Value := "ExecuteTime: " perfStats.execCurrent "ms"
        SetTextColor(executionTimeText, perfStats.execCurrent, 10, 20)
        
        detectionTimeText.Value := "CheckTime: " perfStats.detectCurrent "ms"
        SetTextColor(detectionTimeText, perfStats.detectCurrent, 50, 100)
        
        ; 计算并显示最近平均值
        local recentExecAvg := CalculateRecentAverage("execution")
        local recentDetectAvg := CalculateRecentAverage("detection")
        
        avgExecutionTimeText.Value := "ExecAvg: " recentExecAvg "ms"
        SetTextColor(avgExecutionTimeText, recentExecAvg, 10, 20)
        
        avgDetectionTimeText.Value := "CheckAvg: " recentDetectAvg "ms"
        SetTextColor(avgDetectionTimeText, recentDetectAvg, 50, 100)
        
        ; 更新操作统计
        currentOpsText.Value := "current: " opStats.current "/s"
        SetOpsTextColor(currentOpsText, opStats.current)
        
        avgOpsText.Value := "avg: " opStats.avg "/s"
        SetOpsTextColor(avgOpsText, opStats.avg)
        
        maxOpsText.Value := "max: " opStats.max "/s"
        SetOpsTextColor(maxOpsText, opStats.max)
        
        minOpsText.Value := "min: " opStats.min "/s"
        SetOpsTextColor(minOpsText, opStats.min)
        
        totalOpsText.Value := "total: " opStats.total
        historyText.Value := "recentSize: " opStats.historySize ""
        
        ; 更新最后更新时间
        lastUpdateText.Value := "curTime: " FormatTime(, "HH:mm:ss")
        
    } catch as e {
        ; 如果GUI出错，重新创建
        CreateGUI()
        MsgBox('!' e.Message e.What e.Extra e.File e.File)
    }
}

; 辅助函数：计算最近5秒的平均值
CalculateRecentAverage(type) {
    if (type = "execution" && IsSet(ExecutionStats)) {
        ; 使用增强数据
        local recentTotal := 0
        local recentCount := 0
        local cutoffTime := A_TickCount - 5000  ; 最近5秒
        
        for record in ExecutionStats.history {
            if (record.timestamp >= cutoffTime) {
                recentTotal += record.duration
                recentCount++
            }
        }
        
        return recentCount > 0 ? Round(recentTotal / recentCount) : 0
    }
    else if (type = "detection" && IsSet(DetectionStats)) {
        ; 使用增强数据
        local recentTotal := 0
        local recentCount := 0
        local cutoffTime := A_TickCount - 5000  ; 最近5秒
        
        for record in DetectionStats.history {
            if (record.timestamp >= cutoffTime) {
                recentTotal += record.duration
                recentCount++
            }
        }
        
        return recentCount > 0 ? Round(recentTotal / recentCount) : 0
    }
    
    ; 没有增强数据时返回0
    return 0
}

UpdateSkillStatusDisplay() {
    ; 这里需要根据您的技能检测逻辑来更新显示
    try {
        if (SkillStatus.Has("Dragoncall")) {
            dragoncallText.Value := "Dragoncall: " (SkillStatus['Dragoncall'] ? "🟢" : "⚪")
        }
        
        if (SkillStatus.Has("Wingstorm")) {
            wingstormText.Value := "Wingstorm: " (SkillStatus['Wingstorm'] ? "🟢" : "⚪")
        }
        
        if (SkillStatus.Has("IsSoulFlare")) {
            soulflareText.Value := "IsSoulFlare: " (SkillStatus['IsSoulFlare'] ? "🟢" : "⚪")
        }
        
        if (SkillStatus.Has("IsLeech")) {
            leechText.Value := "IsLeech: " (SkillStatus['IsLeech'] ? "🟢" : "⚪")
        }
        
        if (SkillStatus.Has("Mantra")) {
            mantraText.Value := "Mantra: " (SkillStatus['Mantra'] ? "🟢" : "⚪")
        }
        
        if (SkillStatus.Has("Rupture")) {
            ruptureText.Value := "Rupture: " (SkillStatus['Rupture'] ? "🟢" : "⚪")
        }
    } catch {
        ; 技能状态更新出错，可能是SkillStatus未初始化
    }
}

SetTextColor(control, value, goodThreshold, warnThreshold) {
    if (value <= goodThreshold) {
        control.SetFont("cLime s8", "Segoe UI")
    } else if (value <= warnThreshold) {
        control.SetFont("cYellow s8", "Segoe UI")
    } else {
        control.SetFont("cRed s8", "Segoe UI")
    }
}

SetOpsTextColor(control, opsValue) {
    ; 根据操作频率设置颜色
    if (opsValue >= 3) {
        control.SetFont("cLime s8", "Segoe UI")      ; 高频率：绿色
    } else if (opsValue >= 1) {
        control.SetFont("cYellow s8", "Segoe UI")    ; 中等频率：黄色
    } else if (opsValue > 0) {
        control.SetFont("cLime s8", "Segoe UI")    ; 低频率：橙色
    } else {
        control.SetFont("cSilver s8", "Segoe UI")    ; 无操作：灰色
    }
}

UpdateHUDVisibility() {
    global GuiModel, RunningStatus
    if (RunningStatus['isShowing']) {
        if (!GuiModel) {
            CreateGUI()
        }
        try {
            GuiModel.Show("NoActivate")
        } catch {
            CreateGUI()
            MsgBox('!2')
        }
    } else {
        if (GuiModel) {
            try {
                GuiModel.Hide()
            } catch {
                ; 忽略错误
            }
        }
    }
}

global GuiTimerId := 0
global ExecuteTimerId := 0
global CheckTimerId := 0
; 持久化的绑定函数对象和取消 guard（用于稳健地开启/取消 SetTimer）
global SkillMainTimerFunc := ""
global SkillStatusTimerFunc := ""
global GuiTimerFunc := ""
; 调试开关：开启后将在代理入口用短时 ToolTip 显示代理被跳过或执行（默认 false）
global DebugTimers := false

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
    global ExecuteTimerId, SkillMainTimerFunc, SkillLoopDelay

    if (!RunningStatus['isRunning'])
        return

    ; 清除取消标志并设置 holding
    RunningStatus['cancelExecuteQueued'] := false
    RunningStatus['isHolding'] := true

    ; 使用持久化绑定对象以便以后能够准确取消
    if (!SkillMainTimerFunc)
        SkillMainTimerFunc := SkillMainProxy.Bind()

    ExecuteTimerId := SetTimer(SkillMainTimerFunc, -SkillLoopDelay)

}



StopExecuteTimer(){
    global ExecuteTimerId, SkillMainTimerFunc

    ; 先关闭 holding 状态
    RunningStatus['isHolding'] := false

    ; 标记：取消已排队的执行（guard），保证即便计时器已进入执行路径也不会执行主体
    RunningStatus['cancelExecuteQueued'] := true

    ; 尝试使用返回的 timer id 取消
    if (ExecuteTimerId){
        SetTimer(ExecuteTimerId, 0)
        ExecuteTimerId := 0
    }

    ; 双保险：使用持久化的函数对象取消任何使用该函数的计时器
    if (SkillMainTimerFunc){
        SetTimer(SkillMainTimerFunc, 0)
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
    global SkillTimestamp, ExecuteTimerId, ExecutionStats, SkillLoopDelay, SkillMainTimerFunc

    ; Guard：如果执行已被取消或不再 holding，则直接返回
    if (!RunningStatus['isHolding'] || RunningStatus['cancelExecuteQueued'] || !RunningStatus['isRunning']) {
        if (DebugTimers) {
            ToolTip("SkillMainProxy: skipped (holding=" . RunningStatus['isHolding'] . " cancel=" . RunningStatus['cancelExecuteQueued'] . " isRunning=" . RunningStatus['isRunning'] . ")", 0, 0)
            SetTimer(() => ToolTip(), -300)
        }
        ; 清理取消标志（只影响当前一次）
        RunningStatus['cancelExecuteQueued'] := false
        return
    }

    local startTimestamp := A_TickCount

    if (DebugTimers) {
        ToolTip("SkillMainProxy: running", 0, 0)
        SetTimer(() => ToolTip(), -300)
    }
    SkillLoop()

    local endTimestamp := A_TickCount
    local duration := endTimestamp - startTimestamp
    UpdateExecutionStats(duration, SkillCnt)

    ; 循环尾部：如果还在运行则重设一次性定时器（使用持久化的绑定函数）
    if (RunningStatus['isHolding'] && RunningStatus['isRunning']) {
        if (!SkillMainTimerFunc)
            SkillMainTimerFunc := SkillMainProxy.Bind()
        ExecuteTimerId := SetTimer(SkillMainTimerFunc, -SkillLoopDelay)
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
global RunningStatus := Map() ; 运行状态管理

global FocusSkill_Limit := 200
global LastExecuteTime := 0

class SkillPublisher {
    static Subjects := Map() ; 存储所有主题
    
    /**
     * 注册观察者
     * @param subjectName 主题名称
     * @param observer 观察者对象（必须实现 Update 方法）
     */
    static Subscribe(subjectName, observer) {
        if (!this.Subjects.Has(subjectName)) {
            this.Subjects[subjectName] := []
        }
        
        ; 避免重复注册
        for existingObserver in this.Subjects[subjectName] {
            if (existingObserver == observer) {
                return false
            }
        }
        
        this.Subjects[subjectName].Push(observer)
        return true
    }
    
    /**
     * 取消注册
     * @param subjectName 主题名称
     * @param observer 观察者对象
     */
    static Unsubscribe(subjectName, observer) {
        if (!this.Subjects.Has(subjectName)) {
            return false
        }
        
        observers := this.Subjects[subjectName]
        for index, existingObserver in observers {
            if (existingObserver == observer) {
                observers.RemoveAt(index)
                return true
            }
        }
        
        return false
    }
    
    /**
     * 通知所有观察者
     * @param subjectName 主题名称
     * @param data 传递的数据
     */
    static Notify(subjectName, data := "") {
        if (!this.Subjects.Has(subjectName)) {
            return 0
        }
        
        notifiedCount := 0
        for observer in this.Subjects[subjectName] {
            try {
                observer.Update(data) ; 调用观察者的 Update 方法
                notifiedCount++
            } catch Error as e {
                ; 可添加错误处理逻辑
                OutputDebug("观察者通知失败: " e.Message)
            }
        }
        
        return notifiedCount
    }
    
    /**
     * 获取主题的所有观察者
     */
    static GetObservers(subjectName) {
        return this.Subjects.Has(subjectName) ? this.Subjects[subjectName].Clone() : []
    }
    
    /**
     * 清除主题的所有观察者
     */
    static ClearSubject(subjectName) {
        if (this.Subjects.Has(subjectName)) {
            this.Subjects.Delete(subjectName)
            return true
        }
        return false
    }
}

class DragoncallSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Dragoncall'] := data
    }
}

class WingstormSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Wingstorm'] := data
    }
}

; class SoulFlare1Subscribers {
;     Update(data) {
;         global SkillStatus
;         SkillStatus['SoulFlare1'] := data
;         SkillStatus['IsSoulFlare'] := data
;     }
; }

; class SoulFlare2Subscribers {
;     Update(data) {
;         global SkillStatus
;         SkillStatus['SoulFlare2'] := data
;         SkillStatus['IsSoulFlare'] := data || SkillStatus['SoulFlare1']
;     }
; }

; class SoulFlare3Subscribers {
;     Update(data) {
;         global SkillStatus
;         SkillStatus['SoulFlare3'] := data
;         SkillStatus['IsSoulFlare'] := data || SkillStatus['SoulFlare1'] || SkillStatus['SoulFlare2']
;     }
; }

; class Leech1Subscribers {
;     Update(data) {
;         global SkillStatus
;         SkillStatus['Leech1'] := data
;         SkillStatus['IsLeech'] := data
;     }
; }

; class Leech2Subscribers {
;     Update(data) {
;         global SkillStatus
;         SkillStatus['Leech2'] := data
;         SkillStatus['IsLeech'] := data || SkillStatus['Leech1']
;     }
; }

; class Leech3Subscribers {
;     Update(data) {
;         global SkillStatus
;         SkillStatus['Leech3'] := data
;         SkillStatus['IsLeech'] := data || SkillStatus['Leech1'] || SkillStatus['Leech2']
;     }
; }

class Leech_Dir1Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech_Dir1'] := data
        SkillStatus['Leech'] := data || SkillStatus['Leech_Dir11']
    }
}

class Leech_Dir11Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech_Dir11'] := data
        SkillStatus['Leech'] := data
    }
}

class MantraSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Mantra'] := data
        SkillStatus['Mantra'] := data
    }
}

class Rupture_Dir1Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Rupture_Dir1'] := data
        SkillStatus['Rupture'] := data || SkillStatus['Rupture_Dir11']
    }
}

class Rupture_Dir11Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Rupture_Dir11'] := data
        SkillStatus['Rupture'] := data
    }
}

class FocusSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Focus'] := data
        ; ToolTip('Focus : ' SkillStatus['Focus'], 805, 840)
    }
}



class SoulFlareSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['IsSoulFlare'] := data
    }
}

class LeechSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['IsLeech'] := data
    }
}


class SoulFlareReadySubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['SoulFlareReady'] := data
    }
}


SkillLoop(){
    global SkillCnt, SkillCntLastTime:=0 ; 操作数最终结果
    global LastExecuteTime ; 上一次执行时间戳
    global SkillStatus
    global BaseLimit, RandomLimit, Limit, isUsedLeechNoLeechBuff

    if(A_TickCount - SkillCntLastTime >= 1000){
        SkillCnt := 0
    }

    local cnt := 0

    ; 瞬发逻辑
    local gcd_group1 := false
    static slow_focus_time := A_TickCount

    global GoldWingstorm, AutoSoulFlare

    if(AutoSoulFlare && SkillStatus['SoulFlareReady']){
        Send '{Tab}'
        cnt++
    }
    
    instantSkill()

    local LeechConditon := true
    ; 如果配置为 true，则始终允许使用 Leech（即使已有 Leech buff）
    if (isUsedLeechNoLeechBuff)
        LeechConditon := true
    else
        LeechConditon := !SkillStatus['IsLeech']
    ; 3. 掠夺
    if(!gcd_group1 && LeechConditon && SkillStatus['Leech']){
        instantSkill()
        Send 'f'
        cnt++
        gcd_group1 := true
    }

    ; 4. 真言
    if(!gcd_group1 && EnableSkill.get('Mantra') && !(LeechConditon && SkillStatus['Leech'])){
        local MantraRequired := SkillStatus['IsSoulFlare'] ? 
            SkillCondition.get('Mantra').get('IsSoulFlare') :
                (SkillStatus['IsLeech'] ? SkillCondition.get('Mantra').get('IsLeech') : SkillCondition.get('Mantra').get('Normal')
            )
        ; if(SkillStatus['Mantra'] && isLowFocus(MantraRequired)){
        ;     Send 'r'
        ;     cnt++
        ;     gcd_group2 := true
        ;     slow_focus_flag := A_TickCount
        ; }
        if(SkillStatus['Mantra'] && MantraRequired >= SkillStatus['Focus']){
            Send 'r'
            cnt++
            gcd_group1 := true
            slow_focus_flag := A_TickCount
        }

    }

    ; 5. 破裂
    if(!gcd_group1 && EnableSkill.get('Rupture') && !(LeechConditon && SkillStatus['Leech'])){
        local RuptureRequired := SkillStatus['IsSoulFlare'] ? 
            SkillCondition.get('Rupture').get('IsSoulFlare') :
                (SkillStatus['IsLeech'] ? SkillCondition.get('Rupture').get('IsLeech') : SkillCondition.get('Rupture').get('Normal')
            )
            if(SkillStatus['Rupture'] && MantraRequired >= SkillStatus['Focus']){
                Send 'f'
                cnt++
                gcd_group1 := true
                slow_focus_flag := A_TickCount
            }
        ; if(SkillStatus['Rupture'] && isLowFocus(RuptureRequired)){
        ;     Send 'f'
        ;     cnt++
        ;     gcd_group2 := true
        ;     slow_focus_flag := A_TickCount
        ; }
    }
    Limit := BaseLimit + Random(0, RandomLimit/2)
    LimitResult := (A_TickCount - LastExecuteTime >= Limit)

    ; 當處於 (命中掠奪使用條件) / (命中降臨使用條件) 的時候 不使用次元彈(防止卡GCD)
    
    local flag := (LeechConditon && SkillStatus['Leech'])

    ; 6. 次元弹: 当执行时间小于Config.Limit的时候,限制执行,以减轻高频带来的卡顿
    if(!((flag || (flag && AutoSoulFlare ? SkillStatus['SoulFlareReady'] : false)) && LimitResult)){
        Send 't'
        cnt++
        LastExecuteTime := A_TickCount
        gcd_group1 := true
    }


    
    SkillCnt := cnt
    SkillCntLastTime := A_TickCount
}

global SkillStatus := Map() ; 技能状态管理，事件驱动



InitSkillStatus(){
    global SkillStatus
    SkillStatus['Dragoncall'] := false
    SkillStatus['Wingstorm'] := false
    SkillStatus['IsSoulFlare'] := false
    SkillStatus['IsLeech'] := false
    SkillStatus['Leech'] := false
    SkillStatus['Rupture'] := false
    SkillStatus['Mantra'] := false
    SkillStatus['Focus'] := 0
}

InitObserver(){
    SkillPublisher.Subscribe('Dragoncall', DragoncallSubscribers())
    SkillPublisher.Subscribe('Wingstorm', WingstormSubscribers())
    SkillPublisher.Subscribe('Leech_Dir1', Leech_Dir1Subscribers())
    SkillPublisher.Subscribe('Leech_Dir11', Leech_Dir11Subscribers())
    SkillPublisher.Subscribe('Mantra', MantraSubscribers())
    SkillPublisher.Subscribe('Rupture_Dir1', Rupture_Dir1Subscribers())
    SkillPublisher.Subscribe('Rupture_Dir11', Rupture_Dir11Subscribers())
    SkillPublisher.Subscribe('Focus', FocusSubscribers())

    SkillPublisher.Subscribe('Leech', LeechSubscribers())
    SkillPublisher.Subscribe('SoulFlare', SoulFlareSubscribers())
    SkillPublisher.Subscribe('SoulFlareReady', SoulFlareReadySubscribers())
}

; 

SkillStatusCheck(){
    global SkillPos, SkillCache, BuffsCache, FocusPos, FocusCache, BuffsMap

    ; 合并所有需要采样的坐标为一个 map，使用唯一键以便从单次 GetRegionColors 结果中取回
    local combinedPositions := Map()

    ; 技能坐标 (保留原 skill 名称作为后缀)
    for skill, pos in SkillPos {
        combinedPositions["Skill_" . skill] := pos
    }

    ; 内力坐标 (Focus)
    for fid, pos in FocusPos {
        combinedPositions["Focus_" . fid] := pos
    }

    ; Buffs 坐标，BuffsMap 的每个值是一个数组
    for buffsName, posArr in BuffsMap {
        for idx, pos in posArr {
            combinedPositions["Buffs_" . buffsName . "_" . idx] := pos
        }
    }

    ; 只调用一次屏幕采样
    local allColors := GetRegionColors(combinedPositions)

    ; 从 allColors 中拆分回三组数据：技能、内力、Buffs


    local curSkill_RGBMap := Map()
    for skill, pos in SkillPos {
        curSkill_RGBMap[skill] := allColors.Has("Skill_" . skill) ? allColors["Skill_" . skill] : {red:0,green:0,blue:0}
    }

    

    local curFocus_Map := Map()
    for fid, pos in FocusPos {
        curFocus_Map[fid] := allColors.Has("Focus_" . fid) ? allColors["Focus_" . fid] : {red:0,green:0,blue:0}
    }



    local curBuffs_MapCollection := Map()
    for buffsName, posArr in BuffsMap {
        local arr := []
        for idx, pos in posArr {
            key := "Buffs_" . buffsName . "_" . idx
            arr.Push(allColors.Has(key) ? allColors[key] : {red:0,green:0,blue:0})
        }
        curBuffs_MapCollection[buffsName] := arr
    }

    



    ; 处理技能状态通知（保持原逻辑）
    for skill, cur IN curSkill_RGBMap{
        cache := SkillCache[skill]
        result := IsColorCache(cache, cur)
        SkillPublisher.Notify(skill, result)
    }

    ; 处理内力 (Focus)
    local f_result := 0
    for focus_id, act IN curFocus_Map{
        refL := FocusCache[focus_id]
        actL := act.red * 0.2126
            + act.green * 0.7152
            + act.blue * 0.0722
        isLow := (actL < refL) ; isLowFocus
        if(!isLow && focus_id > f_result){
            f_result := focus_id
        }
    }
    SkillPublisher.Notify('Focus', f_result)

    

    ; 处理 Buffs（每个 buffsName 对应的坐标数组按原逻辑遍历）
    ; 改进：读取一次 cache、对 posArr 做快照、收集通知后统一发布以避免重入修改集合
    local last_result := Map()
    local last_number := Map()
    global BuffsNameList
    for buffsName in BuffsNameList{
        last_result[buffsName] := false
        last_number[buffsName] := 0
    }

    for skill, posArr IN curBuffs_MapCollection{
        local result := false
        ; 从预处理的 BuffsCache 读取到局部变量，减少重复访问
        local cache_1 := BuffsCache.Has(skill . "_1") ? BuffsCache[skill . "_1"] : ""
        local cache_2 := BuffsCache.Has(skill . "_2") ? BuffsCache[skill . "_2"] : ""

        ; 快照 posArr，防止在遍历期间被回调修改
        local snapshot := []
        for idx, v in posArr
            snapshot.Push(v)

        for idx, cur in snapshot{
            result := false
            if (idx == 3 || idx == 7){
                result := IsColorCache(cache_2, cur)
            }else{
                result := IsColorCache(cache_1, cur)
            }
            last_result[skill] := last_result[skill] || result
            if (last_result[skill]) {
                break
            }
        }
        SkillPublisher.Notify(skill, last_result[skill])

        
    }


    
    
}



instantSkill(){
    global SkillStatus, GoldWingstorm
    ; 1. 暴魔灵
    if(SkillStatus['Dragoncall']){
        Send '4'
    }

    ; 2. 死灵突袭
    if(GoldWingstorm || SkillStatus['Wingstorm']){
        Send 'v'
    }
}

InitRunningStatus(){
    global RunningStatus
    RunningStatus['isRunning'] := false
    RunningStatus['isHolding'] := false
    RunningStatus['isShowing'] := false
    ; Cancel guards（显式初始化）
    RunningStatus['cancelExecuteQueued'] := false
    RunningStatus['cancelCheckQueued'] := false
    RunningStatus['cancelGuiQueued'] := false
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

InitEnableSkill(){
    global EnableSkill
    EnableSkill['Mantra'] := true
    EnableSkill['Rupture'] := true
}

isLowFocus(number := 10) {
    global FocusCache, FocusPos
    if (number < 1 || number > 10)
        return false

    local actC := PixelGetColor(FocusPos.Get(number).x, FocusPos.Get(number).y, "RGB")

    local refL := FocusCache[number]
    local actL := ((actC >> 16) & 0xFF) * 0.2126
        + ((actC >> 8) & 0xFF) * 0.7152
        + ( actC & 0xFF) * 0.0722
    ; MsgBox(refL ' , ' actL)
    return actL < refL
}

IsColorCache(target, result, tolerance := 10) {
    r1 := target.red
    g1 := target.green
    b1 := target.blue
    
    r2 := result.red
    g2 := result.green
    b2 := result.blue
    
    ; 计算欧几里得距离
    distance := Sqrt((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2)
    return distance <= tolerance
}

GetRegionColors(positions) {
    ; 找出坐标范围
    minX := 9999, maxX := 0, minY := 9999, maxY := 0
    for skillName, pos in positions {
        if (pos.x < minX) 
            minX := pos.x
        if (pos.x > maxX) 
            maxX := pos.x
        if (pos.y < minY) 
            minY := pos.y
        if (pos.y > maxY) 
            maxY := pos.y
    }
    ; MsgBox('MIN:' minX "," minY " MAX:" maxX "," maxY)
    
    width := maxX - minX + 1
    height := maxY - minY + 1
    
     ; 创建设备上下文
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap)
    
    ; 复制屏幕区域
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", width, "Int", height,
                    "Ptr", hdcScreen, "Int", minX, "Int", minY, "UInt", 0x00CC0020)
    
    ; 使用32位格式（更可靠）
    bitmapData := Buffer(4 * width * height)
    
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", width, bi, 4)
    NumPut("Int", -height, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)    ; 32位
    NumPut("UInt", 0, bi, 16)       ; BI_RGB
    
    DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hBitmap, "UInt", 0, "UInt", height,
                    "Ptr", bitmapData, "Ptr", bi, "UInt", 0)
    
    ; 获取每个坐标的颜色
    colors := Map()
    for skillName, pos in positions {
        relX := pos.x - minX
        relY := pos.y - minY
        offset := (relY * width + relX) * 4
        
        ; 32位格式：GetDIBits 返回的是 BGRA（当 biCompression=BI_RGB）
        ; 字节顺序：Blue, Green, Red, Alpha
        
        blue  := NumGet(bitmapData, offset, "UChar")      ; 字节0: Blue
        green := NumGet(bitmapData, offset + 1, "UChar")  ; 字节1: Green
        red   := NumGet(bitmapData, offset + 2, "UChar")  ; 字节2: Red

        colors[skillName] := {red:red, blue:blue, green:green} 
    }
    
    ; 清理资源
    DllCall("DeleteObject", "Ptr", hBitmap)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    
    return colors
}

readConfig(Section, Key, Path:=DefaultConfigFilePath){
    result := IniRead(DefaultConfigFilePath, Section, Key)
    return result
}

readPosConfig(Section, Key, Path:=DefaultConfigFilePath){
    posStr := IniRead(DefaultConfigFilePath, Section, Key)
    if (posStr = "")
        return {x: 0, y: 0} ; 默认值
    coords := StrSplit(posStr, ",")
    if (coords.Length != 2)
        return {x: 0, y: 0} ; 格式错误，返回默认值
    return {x: coords[1], y: coords[2]}
}

readColorConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

readBarSpaceConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

readBuffsNumberConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

global BuffsMap := Map()
global BuffsNameList := ["Leech", "SoulFlare"]
global SkillPos := Map()
global SkillColor := Map()
global FocusPos := Map()
Global SkillNameList := ["Dragoncall", "Wingstorm", "Leech_Dir1", "Leech_Dir11", "Mantra", "Rupture_Dir1", "Rupture_Dir11", "SoulFlareReady"]


InitSkillPointAndColor(){
    global SkillPos, SkillColor, FocusPos, BuffsBarColumn, BuffsBarRow, Horizontal, Vertical, BuffsBase, BuffsMap, SkillNameList
    ; 技能坐标和颜色配置
    for skillName In SkillNameList {
        SkillPos[skillName] := readPosConfig("SkillPos", skillName)
        SkillColor[skillName] := readColorConfig("SkillColor", skillName)
    }

    ; 内力坐标和颜色配置
    Loop 10 {
        FocusPos[A_Index] := readPosConfig("SkillPos", "Focus_" . A_Index)
    }
    FocusColor := readColorConfig("SkillColor", "Focus")

    ; Buffs坐标和颜色配置
    BuffsBarColumn := readBarSpaceConfig("BarSpace", "BuffsBarColumn")
    BuffsBarRow := readBarSpaceConfig("BarSpace", "BuffsBarRow")

    Horizontal := readBarSpaceConfig("BuffsNumber", "Horizontal")
    Vertical := readBarSpaceConfig("BuffsNumber", "Vertical")

    BuffsBase := Map()
    for buffsName in BuffsNameList{
        Pos := readPosConfig("BuffsBasePos", buffsName)
        Color := readColorConfig("BuffsBaseColor", buffsName . "1")
        PosAndColor := {x: Pos.x, y: Pos.y, c: Color}
        BuffsBase.Set(buffsName, PosAndColor)
    }

    ; 797-773= 24,612-621= -9 
    ; 797, 612
    loop BuffsNameList.Length{
        buffsArr := Array()
        j := 0, i := 0
        cur := A_Index
        txt := ""
        loop Horizontal{
            j := j + 1
            i := 0
            local offsetX := 0
            loop Vertical{
                i := i + 1
                if(i == 3+1 || i == 7+1){
                    offsetX := offsetX + 1
                }
                PosMap := {x: BuffsBase[BuffsNameList[cur]].x - (i-1)*BuffsBarRow - offsetX, y: BuffsBase[BuffsNameList[cur]].y + (j-1)*BuffsBarColumn , c: BuffsBase[BuffsNameList[cur]].c}
                buffsArr.Push(PosMap)
                ; txt := txt . BuffsNameList[cur] ": " . PosMap.x . "," . PosMap.y . "`n"
            }
        }
        BuffsMap.Set(BuffsNameList[cur], buffsArr)
        ; MsgBox txt
    }
    
}

global FocusCache := Map()
global SkillCache := Map()
global BuffsCache := Map()

InitCalCache(){
    global SkillCache, SkillColor, FocusCache, FocusPos, BuffsCache
    
    for id, value IN SkillColor{
        color := Integer(SkillColor[id])
        r1 := (color >> 16) & 0xFF
        g1 := (color >> 8) & 0xFF
        b1 := color & 0xFF
        SkillCache[id] := {red:r1, blue:b1, green:g1}
    }

    for id, value IN FocusPos{
        color := 0xFEFFFF
        local refL := ((color >> 16) & 0xFF) * 0.2126 + ((color >> 8) & 0xFF) * 0.7152 + (color & 0xFF) * 0.0722
        FocusCache[id] := refL
    }

    global Leech_Color_1, SoulFlare_Color_1, Leech_Color_2, SoulFlare_Color_2
    Leech_Color_1 := Integer(readColorConfig("BuffsBaseColor", "Leech1"))
    SoulFlare_Color_1 := Integer(readColorConfig("BuffsBaseColor", "SoulFlare1"))

    Leech_Color_2 := Integer(readColorConfig("BuffsBaseColor", "Leech2"))
    SoulFlare_Color_2 := Integer(readColorConfig("BuffsBaseColor", "SoulFlare2"))

    color := Leech_Color_1
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF
    BuffsCache['Leech_1'] := {red:r1, blue:b1, green:g1}
    color := SoulFlare_Color_1
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF
    BuffsCache['SoulFlare_1'] := {red:r1, blue:b1, green:g1}

    color := Leech_Color_2
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF
    BuffsCache['Leech_2'] := {red:r1, blue:b1, green:g1}
    color := SoulFlare_Color_2
    r1 := (color >> 16) & 0xFF
    g1 := (color >> 8) & 0xFF
    b1 := color & 0xFF
    BuffsCache['SoulFlare_2'] := {red:r1, blue:b1, green:g1}
}


InitConfig(){
    InitRunningStatus()
    InitHotKeys()
    InitEnableSkill()
    InitSkillCondition()
    InitSkillPointAndColor()
    InitSkillStatus()
    InitCalCache()
    InitObserver()

    global GoldWingstorm, AutoSoulFlare, RandomLimit, BaseLimit,isUsedLeechNoLeechBuff

    ; GoldWingstorm := readConfig("GoldBook", "Wingstorm")
    ; AutoSoulFlare := readConfig("Config", "AutoSoulFlare")
    ; RandomLimit := readConfig("Config", "RandomLimit")
    ; BaseLimit := readConfig("Config", "BaseLimit")
    ; isUsedLeechNoLeechBuff := readConfig("Config", "isUsedLeechNoLeechBuff")
    ; 在 AutoHotkey 中非空字符串（包括 "false"）都被认为是真值
    
    GoldWingstorm := StrLower(readConfig("GoldBook", "Wingstorm")) = "true"
    AutoSoulFlare := StrLower(readConfig("Config", "AutoSoulFlare")) = "true"
    RandomLimit := readConfig("Config", "RandomLimit")
    BaseLimit := readConfig("Config", "BaseLimit")
    isUsedLeechNoLeechBuff := StrLower(readConfig("Config", "isUsedLeechNoLeechBuff")) = "true"

    text := ''
    text .= '初始化完成! `n '
    text .= '1. [Ctrl + F11] 启动脚本 `n '
    text .= '2. [Ctrl + F5] 重载脚本 `n '
    text .= '3. [XButton2] 鼠标侧键2 持续触发 `n '
    text .= '4. [Ctrl + F3] 显示/隐藏GUI `n '
    text .= '5. [XButton1] 鼠标侧键1 闪避 `n '
    CreateGUI()
    MsgBox(text, '⭐~取色宏(作者:Slowpoke)~⭐')
}

InitConfig()
