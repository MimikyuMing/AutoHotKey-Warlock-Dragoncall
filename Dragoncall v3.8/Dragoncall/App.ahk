#Requires AutoHotkey v2.0

#Include ..\Lib\HiResTimer.ahk
#Include CaptureEngine.ahk
#Include ..\Lib\KeyLogger.ahk
#Include ..\Lib\IniManager.ahk
#Include ..\Lib\Tools.ahk
#Include GUI.ahk

class App {
    static Init() {
        HiResTimer.Init()
        Log.Init()
        this.LoadSettings()
        CaptureEngine.Start()
        this.CreateTray()
        KeyLogger.Start()
        OnExit App.Cleanup
    }

    static LoadSettings() {
        settings := IniManager.ReadToMap("Settings")
        LogicEngine.g_Gold_Wingstorm := ParseBool(settings.Has("Gold_Wingstorm") ? settings["Gold_Wingstorm"] : false)
        LogicEngine.g_Gold_Open := ParseBool(settings.Has("Gold_Open") ? settings["Gold_Open"] : false)
        LogicEngine.g_AutoSoulFlare := ParseBool(settings.Has("AutoSoulFlare") ? settings["AutoSoulFlare"] : false)
        LogicEngine.g_isUseLeechHasLeechBuff := ParseBool(settings.Has("isUseLeechHasLeechBuff") ? settings["isUseLeechHasLeechBuff"] : false)
        LogicEngine.g_Gold_Leech := ParseBool(settings.Has("Gold_Leech") ? settings["Gold_Leech"] : false)
        LogicEngine.g_limitationOpen := ParseBool(settings.Has("LimitationOpen") ? settings["LimitationOpen"] : false)
        LogicEngine.g_limitationLeech := ParseBool(settings.Has("LimitationLeech") ? settings["LimitationLeech"] : false)
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
        ToolTip "Cleanup completed", 0, 0
    }
}
