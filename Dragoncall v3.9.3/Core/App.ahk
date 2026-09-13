#Requires AutoHotkey v2.0

#Include ../Lib/Tools.ahk
#Include RuntimeContext.ahk
#Include CoreStatusMonitor.ahk
#Include ../Lib/InputQueue.ahk

class App {
    static debugMode := true
    static Millisecond := 1000
    static configPath := A_AppData "\Dragoncall\Dragoncall-Config.ini"
    static version := ""
    static ctx := ""
    static isUsedInputQueue := false

    static Init() {
        HiResTimer.Init()

        ; 获取模板 INI 路径（优先 %TEMP%，其次脚本目录）
        tmplConfig := this._GetTemplatePath()

        ; 从模板读版本号
        this.version := IniRead(tmplConfig, "version", "version", "unknown")

        ; 版本检查 + 复制
        this.EnsureConfig(tmplConfig)

        ; 创建 ctx
        this.ctx := RuntimeContext()

        ; 加载配置
        this.LoadSettings()
        LogicEngine.ctx := this.ctx

        ; 5. 启动截图引擎
        CaptureEngine.Start()

        ; 6. Mutex 初始化
        CoreMutex.Init()

        ; 7. StateManager
        StateManager.Init(CaptureEngine)

        ; 8. 托盘
        this.CreateTray()

        ; 9. 日志
        Log.Init()

        ; 10. KeyLogger
        KeyLogger.Start()

        ; 11. InputQueue
        InputQueue.Init()

        ; 12. 状态监视器
        monitior := CoreStatusMonitor()
        monitior.Start(LogicEngine, 1000, 100, 942, 495)
        OutputDebug "tmplConfig: " tmplConfig
        OutputDebug "version read: " IniRead(tmplConfig, "version", "version", "NOT_FOUND")

        OnExit App.Cleanup
    }

    ; ============================================================
    ; 版本检查
    ; ============================================================
    static EnsureConfig(tmplConfig) {
        userConfig := this.configPath
        userDir := A_AppData "\Dragoncall"

        if !DirExist(userDir)
            DirCreate userDir

        ; 模板不存在 → 只保证用户配置存在
        if !FileExist(tmplConfig) {
            if !FileExist(userConfig)
                FileAppend "", userConfig
            return
        }

        ; 用户配置不存在 → 直接复制
        if !FileExist(userConfig) {
            FileCopy tmplConfig, userConfig, 1
            return
        }

        ; 两边都存在 → 语义化版本比较
        srcVer := IniRead(tmplConfig, "version", "version", "0.0.0")
        userVer := IniRead(userConfig, "version", "version", "0.0.0")

        if (this._CompareVersion(srcVer, userVer) <= 0)
            return   ; 用户配置不旧，保留

        ; 版本升级 → 合并
        this._MergeConfig(tmplConfig, userConfig, srcVer)
    }

    ; 版本升级时合并：结构性节覆盖，设置节保留用户值
    static _MergeConfig(tmplConfig, userConfig, newVer) {
        ; 结构性节：整节覆盖
        forceSections := ["Skill", "Focus", "Buff", "ColdDown"]
        for section in forceSections {
            try IniDelete(userConfig, section)
            this._CopySection(tmplConfig, userConfig, section)
        }

        ; Settings 节：保留用户值，补充模板新增键
        this._MergeSection(tmplConfig, userConfig, "Settings")

        ; 更新版本号
        IniWrite(newVer, userConfig, "version", "version")
    }

    ; 复制整个 section（模板 → 用户）
    static _CopySection(srcIni, dstIni, section) {
        content := IniRead(srcIni, section, , "")
        if (content == "")
            return
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line == "")
                continue
            pos := InStr(line, "=")
            if (pos == 0)
                continue
            key := Trim(SubStr(line, 1, pos - 1))
            val := Trim(SubStr(line, pos + 1))
            IniWrite(val, dstIni, section, key)
        }
    }

    ; 合并 section：用户已有键保留，模板新增键补充
    static _MergeSection(srcIni, dstIni, section) {
        content := IniRead(srcIni, section, , "")
        if (content == "")
            return
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line == "")
                continue
            pos := InStr(line, "=")
            if (pos == 0)
                continue
            key := Trim(SubStr(line, 1, pos - 1))
            val := Trim(SubStr(line, pos + 1))
            ; 用户配置里没有这个键才写入
            existing := IniRead(dstIni, section, key, "__NOT_FOUND__")
            if (existing == "__NOT_FOUND__")
                IniWrite(val, dstIni, section, key)
        }
    }

    ; 语义化版本比较：a > b 返回 1，a < b 返回 -1，相等返回 0
    static _CompareVersion(a, b) {
        if (a == b)
            return 0
        pa := StrSplit(a, ".")
        pb := StrSplit(b, ".")
        len := Max(pa.Length, pb.Length)
        loop len {
            va := (A_Index <= pa.Length) ? Integer(pa[A_Index]) : 0
            vb := (A_Index <= pb.Length) ? Integer(pb[A_Index]) : 0
            if (va > vb)
                return 1
            if (va < vb)
                return -1
        }
        return 0
    }

    ; ============================================================
    ; 从 INI 加载到 ctx.config
    ; ============================================================
    static LoadSettings() {
        settings := IniManager.ReadToMap("Settings")
        cfg := this.ctx.config

        cfg.goldWingstorm := ParseBool(settings.Get("Gold_Wingstorm", false))
        cfg.goldOpen := ParseBool(settings.Get("Gold_Open", false))
        cfg.goldLeech := ParseBool(settings.Get("Gold_Leech", false))

        cfg.autoSoulFlare := ParseBool(settings.Get("AutoSoulFlare", false))
        cfg.isUseLeechHasLeechBuff := ParseBool(settings.Get("isUseLeechHasLeechBuff", false))
        cfg.limitationOpen := ParseBool(settings.Get("LimitationOpen", false))
        cfg.limitationLeech := ParseBool(settings.Get("LimitationLeech", false))
        cfg.enablePriorityUseDragoncall := ParseBool(settings.Get("EnablePriorityUseDragoncall", false)) ? 1 : 0
        cfg.isUseOpenHasSoulFlareBuff := ParseBool(settings.Get("isUseOpenHasSoulFlareBuff", false))
        cfg.isUsedLeechFromMySelf := ParseBool(settings.Get("isUsedLeechFromMySelf", false))

        ; 派生字段
        cfg.leechBuffDuration := cfg.goldLeech ? 18 : 15

        ; 传输层
        this.isUsedInputQueue := ParseBool(settings.Get("IsUsedInputQueue", false))
        CaptureEngine.RealtimeMode := ParseBool(settings.Get("RealtimeMode", false))
        InputQueue.minIntervalUs := Integer(settings.Get("InputQueueMinIntervalMs", 10)) * this.Millisecond

        ; 性能监控
        PerformanceMonitor.Init(
            ParseBool(settings.Get("PerformanceMonitor", false)),
            ParseBool(settings.Get("MonitorCpu", false)),
            ParseBool(settings.Get("MonitorMemory", false)),
            Integer(settings.Get("ReportInterval", 1))
        )

        ; 日志
        Log.Enabled := ParseBool(settings.Get("WRITELOG", false))
        KeyLogger.Enabled := ParseBool(settings.Get("WRITEKeyLOG", false))

        PerformanceMonitor.slowThresholdUs := Integer(settings.Get("PerformanceSlowThresholdMs", 10)) * 1000
        PerformanceMonitor.slowLogEnabled := ParseBool(settings.Get("PerformanceSlowLogEnabled", "true"))
    }

    ; ============================================================
    ; 保存配置（供 GUI 调用）
    ; ============================================================
    static SaveSettingsToFile() {
        static configPath := A_AppData "\Dragoncall\Dragoncall-Config.ini"

        if !DirExist(A_AppData "\Dragoncall")
            DirCreate(A_AppData "\Dragoncall")

        cfg := this.ctx.config
        IniWrite(cfg.goldWingstorm, configPath, "Settings", "Gold_Wingstorm")
        IniWrite(cfg.goldOpen, configPath, "Settings", "Gold_Open")
        IniWrite(cfg.autoSoulFlare, configPath, "Settings", "AutoSoulFlare")
        IniWrite(cfg.isUseLeechHasLeechBuff, configPath, "Settings", "isUseLeechHasLeechBuff")
        IniWrite(cfg.goldLeech, configPath, "Settings", "Gold_Leech")
        IniWrite(cfg.limitationOpen, configPath, "Settings", "LimitationOpen")
        IniWrite(cfg.limitationLeech, configPath, "Settings", "LimitationLeech")
        IniWrite(StateManager.realtimeMode, configPath, "Settings", "RealtimeMode")
        IniWrite(PerformanceMonitor.enabled, configPath, "Settings", "PerformanceMonitor")
        IniWrite(PerformanceMonitor.monitorCpu, configPath, "Settings", "MonitorCpu")
        IniWrite(PerformanceMonitor.monitorMem, configPath, "Settings", "MonitorMemory")
        IniWrite(cfg.enablePriorityUseDragoncall, configPath, "Settings", "EnablePriorityUseDragoncall")
        IniWrite(cfg.isUseOpenHasSoulFlareBuff, configPath, "Settings", "isUseOpenHasSoulFlareBuff")
        IniWrite(cfg.isUsedLeechFromMySelf, configPath, "Settings", "isUsedLeechFromMySelf")
    }

    static CreateTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("设置", ShowSettingsGUI)
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "设置"
    }

    static Cleanup(*) {
        CaptureEngine.Cleanup()
        Log.Flush()
        PerformanceMonitor.DumpReport()
    }

    ; 模板 INI 路径：优先 %TEMP%，其次脚本目录
    static _GetTemplatePath() {
        tmplTemp := A_Temp "\Dragoncall-Config.ini"
        if FileExist(tmplTemp)
            return tmplTemp
        tmplScript := A_ScriptDir "\Dragoncall-Config.ini"
        if FileExist(tmplScript)
            return tmplScript
        return tmplTemp   ; 都不存在时返回预期路径，用于报错信息
    }
}