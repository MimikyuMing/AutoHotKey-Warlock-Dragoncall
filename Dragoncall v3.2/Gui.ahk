#Requires AutoHotkey v2.0

#Include RunningStatus.ahk

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

#Requires AutoHotkey v2.0

#Include RunningStatus.ahk

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
        
        if (SkillStatus.Has("IsSoulflare")) {
            soulflareText.Value := "IsSoulflare: " (SkillStatus['IsSoulFlare'] ? "🟢" : "⚪")
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