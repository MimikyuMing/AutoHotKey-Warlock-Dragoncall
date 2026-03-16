#Requires AutoHotkey v2.0
#SingleInstance Force

; ==================== 配置文件路径 ====================
configFile := A_ScriptDir "\config.ini"

; 创建主窗口
MyGui := Gui("+Resize +MinSize300x200", "窗口操作面板")
MyGui.OnEvent("Close", GuiClose)
MyGui.OnEvent("Escape", GuiClose)

; 设置窗口任务栏图标行为
TraySetIcon "shell32.dll", 28  ; 设置托盘图标

; 创建功能按钮区域
MyGui.Add("GroupBox", "w280 h100 Section", "功能按钮")

; 添加三个扩展按钮（示例）
MyGui.Add("Button", "xs+10 ys+20 w80", "功能一").OnEvent("Click", (*) => MsgBox("功能一"))
MyGui.Add("Button", "x+10 yp w80", "功能二").OnEvent("Click", (*) => MsgBox("功能二"))
MyGui.Add("Button", "x+10 yp w80", "功能三").OnEvent("Click", (*) => MsgBox("功能三"))

; 读取保存的配置
savedCity := IniRead(configFile, "Settings", "City", "北京")


; 城市下拉框（带记忆功能）
MyGui.Add("Text", "Section", "选择城市:")
cityItems := ["北京", "上海", "广州", "深圳", "杭州", "重庆", "成都"]
cityDDL := MyGui.Add("DropDownList", "w150 vCityDDL", cityItems)

defaultCityIndex := GetIndex(cityItems, savedCity)
if (defaultCityIndex)
    cityDDL.Value := defaultCityIndex
else
    cityDDL.Value := 1  ; 如果找不到，默认第一个

cityDDL.OnEvent("Change", SaveConfig)

; 添加更多按钮占位符（用于扩展）
MyGui.Add("Button", "xs+10 y+10 w80", "按钮4").OnEvent("Click", (*) => MsgBox("按钮4"))
MyGui.Add("Button", "x+10 yp w80", "按钮5").OnEvent("Click", (*) => MsgBox("按钮5"))
MyGui.Add("Button", "x+10 yp w80", "按钮6").OnEvent("Click", (*) => MsgBox("按钮6"))

; 创建启用/禁用选项区域
MyGui.Add("GroupBox", "xs w280 h80 Section", "启用选项")

; 添加单选框
opt1 := MyGui.Add("Radio", "xs+10 ys+20", "启用选项1")
opt2 := MyGui.Add("Radio", "x+20 yp", "启用选项2")
opt3 := MyGui.Add("Radio", "x+20 yp", "启用选项3")
opt4 := MyGui.Add("Radio", "xs+10 y+10", "启用选项4")
opt5 := MyGui.Add("Radio", "x+20 yp", "启用选项5")
opt6 := MyGui.Add("Radio", "x+20 yp", "启用选项6")

; 默认选中第一个选项
opt1.Value := 1

; 添加状态栏显示信息
; MyGui.Add("StatusBar",, "就绪 | 点击关闭按钮会最小化到托盘")

; 显示窗口
MyGui.Show("w300 h250")

; 创建托盘菜单
A_TrayMenu.Delete()  ; 删除默认菜单
A_TrayMenu.Add("显示窗口", (*) => ShowWindow())
A_TrayMenu.Add("退出程序", (*) => ExitApp())
A_TrayMenu.Default := "显示窗口"

; 窗口关闭事件 - 改为最小化到托盘
GuiClose(*) {
    MyGui.Hide()
    TrayTip "窗口已最小化到托盘", "点击托盘图标可重新显示", 1
}

; 显示窗口函数
ShowWindow(*) {
    MyGui.Show()
    MyGui.Restore()
}

; 托盘图标点击事件 - 左键单击显示窗口
OnMessage(0x404, TrayClick)  ; AHK_NOTIFYICON

TrayClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x201) {  ; WM_LBUTTONDOWN
        ShowWindow()
    }
}

; 热键：Alt+Q 真正退出程序
!q::ExitApp

; 获取单选框状态的函数（可在其他功能中调用）
GetRadioStates() {
    return {
        option1: opt1.Value,
        option2: opt2.Value,
        option3: opt3.Value,
        option4: opt4.Value,
        option5: opt5.Value,
        option6: opt6.Value
    }
}

; 示例：如何获取和使用单选框状态
F1:: {
    states := GetRadioStates()
    MsgBox(
        "当前选中状态：`n" .
        "选项1: " states.option1 "`n" .
        "选项2: " states.option2 "`n" .
        "选项3: " states.option3 "`n" .
        "选项4: " states.option4 "`n" .
        "选项5: " states.option5 "`n" .
        "选项6: " states.option6
    )
}

; ==================== 控制按钮 ====================
MyGui.Add("Button", "xs y+20 w80", "保存配置").OnEvent("Click", SaveConfig)
MyGui.Add("Button", "x+10 yp w80", "重置默认").OnEvent("Click", ResetToDefault)
MyGui.Add("Button", "x+10 yp w80", "查看配置").OnEvent("Click", ShowConfig)

; 保存配置函数
SaveConfig(*) {
    ; 获取当前所有下拉框的值
    currentCity := cityDDL.Text
    
    ; 写入配置文件
    IniWrite(currentCity, configFile, "Settings", "City")
    
    TrayTip "配置已保存", "设置已保存到配置文件", 1
}

; 重置为默认值
ResetToDefault(*) {
    ; 重置城市
    cityDDL.Value := 1  ; 北京
    
    ; 保存重置后的配置
    SaveConfig()
    
    MsgBox("已重置为默认值并保存", "提示", "T1")
}

; 显示当前配置
ShowConfig(*) {
    ; 读取配置文件
    savedCity := IniRead(configFile, "Settings", "City", "未设置")
    savedMonth := IniRead(configFile, "Settings", "Month", "未设置")
    savedUser := IniRead(configFile, "Settings", "UserType", "未设置")
    savedCustom := IniRead(configFile, "Settings", "CustomInput", "未设置")
    savedMode := IniRead(configFile, "Settings", "Mode", "未设置")
    
    MsgBox(
        "当前保存的配置：`n`n" .
        "城市: " savedCity "`n" .
        "月份: " savedMonth "`n" .
        "用户类型: " savedUser "`n" .
        "自定义输入: " savedCustom "`n" .
        "运行模式: " savedMode
    )
}

GetIndex(arr, value) {
    For index, item in arr {
        if (item = value) {
            return index
        }
    }
    return 0  ; 没找到
}

