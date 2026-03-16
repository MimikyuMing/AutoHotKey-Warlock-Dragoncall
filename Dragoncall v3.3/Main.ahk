#Requires AutoHotkey v2.0

#Include CalCache.ahk
#Include Skill\Condition.ahk
#Include Skill\PosAndColor.ahk
#Include HotKey\HotKeyBind.ahk

global GoldWingstorm := false
; 启动

InitConfig(){
    InitRunningStatus()
    InitHotKeys()
    InitEnableSkill()
    InitSkillCondition()
    InitSkillPointAndColor()
    InitSkillStatus()
    InitCalCache()
    InitObserver()

    global GoldWingstorm

    GoldWingstorm := readConfig("GoldBook", "Wingstorm")

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
