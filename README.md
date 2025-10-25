# AutoHotKey-Warlock-Dragoncall
基於AHKv2的B&amp;S暴魔靈流派取色宏

！！需要AutoHotKeyv2版本！！

# 已弃用，请不要选择
- **Warlock_Dragoncall No48 copy.ahk**

- **Warlock_Dragoncall .ahk**


# Warlock_Dragoncall No48 251025.ahk
## 按键说明
- ctrl + f11 启动/禁用宏
- XButton2 卡刀触发键（长按）（需Ctrl+f11启动）
- XButton1 一键ss（需Ctrl+f11启动）
- Ctrl + f5 重启宏（需Ctrl+f11启动）

## 使用须知
内力低于6点自动使用真言，低于3点使用破裂
降临情况下，低于4点使用真言，低于1点使用破裂

### 内力条件修改须知
MainLoop（）是主循环函数，如果要修改内力条件，请找到IsLowFocus_2（）并且更改其传入参数

# Warlock_Dragoncall 48.ahk
## 按键说明
- ctrl + f11 启动/禁用宏
- XButton2 卡刀触发键（长按）（需Ctrl+f11启动）
- XButton1 一键ss（需Ctrl+f11启动）
- Ctrl + f5 重启宏（需Ctrl+f11启动）

## 使用须知
内力低于6点自动使用真言
降临情况下，低于4点使用真言
**该宏会在破裂转好即使用！请注意！（为了在非降临期间进一步提升暴魔灵轮转速度）**

### 内力条件修改须知
MainLoop（）是主循环函数，如果要修改内力条件，请找到IsLowFocus_2（）并且更改其传入参数

# 取色指南
可使用本宏的Ctrl+F1进行取色
## 部分技能取色
**部分技能（暴魔灵/死灵突袭/掠夺/破裂/真言）请取色在1点钟方向！**
案例：
Color_4_instant := 0x174980 ; 瞬发暴魔靈 的RGB
pos_4_instant := {x: 935, y: 963} ; 瞬发暴魔靈 的坐标

...略

## 降临取色
**这部分可取该图标（降临）任意点**
Color_tab := 0x001a52 ; 降臨buff 的RGB
pos_tab := {x: 769, y: 630} ; 降臨buff 的坐标

### **？为什么会有tab1/tab2/tab3**
A：因为neo有时候部分buff会 占据该位置，使得降临buff往后

## 内力取色
请取满内力的小白块部分！
