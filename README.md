# 基于 `AutoHotKey v2.0` + `C++` 的 剑灵neo 的咒术暴魔灵流派 取色宏

**AHK 版本需要v2.0**

# 使用须知
# 前提
- 布局默认(双排布局)
- 大小默认
- 亮度50
- 1920*1080 分辨率
# 按键须知
1. [Ctrl + F11] 启动脚本
2. [Ctrl + F5] 重载脚本
3. [XButton2] 鼠标侧键2 持续触发
4. [Ctrl + F3] 显示/隐藏GUI
5. [XButton1] 鼠标侧键1 闪避(ss)

version3.6之后:

1. [XButton2] 鼠标侧键2 持续触发
2. [XButton1] 鼠标侧键1 闪避(ss)
3. [F11] 重载脚本

---

## [v3.9] - 2026-07-21 — 实时数据层、输入队列与可观测性增强

### 🧩 架构重构：实时数据层与输入解耦

#### 新增 RealtimeMap 实时数据层
- **新增 `Lib/RealtimeMap.ahk`**：继承 `Map` 基类，重写 `Get()` 方法，根据 `StateManager.realtimeMode` 动态切换数据来源
  - **实时模式**：通过 `CaptureClient.GetCachedFrame()` 直接从共享内存读取当前帧的技能/增益状态，实现零拷贝查询
  - **缓存模式**：回退到父类 `Map` 的缓存数据（由定时器同步），兼容原有逻辑
- **帧缓存机制**：`CaptureClient` 新增 `cachedFrameId` / `cachedFrameData` 静态缓存，同一帧内多次查询共享内存仅执行一次 `ReadFrame()`，大幅降低开销
- **StateManager 初始化重构**：新增 `Init()` 方法，将 `_skillState` 和 `_buffState` 初始化为 `RealtimeMap` 实例，并注入 `type`（skill/buff）和 `idxMap`（名称→索引映射）

#### 新增 InputQueue 异步输入队列
- **新增 `Lib/InputQueue.ahk`**：解耦"业务决策"与"按键发送"
  - 维护 FIFO 队列，业务逻辑仅需 `Push(key)` 即可入队
  - 独立的 `Process()` 定时器以 `-1ms` 间隔消费队列，执行 `SendInput`
  - 支持通过 `engine` 参数注入发送许可提供者（如 `LogicEngine.g_LogicEnabled`）
  - 逻辑引擎关闭时自动清空队列并停止发送
- **LogicRunner 新增 `SendKey()` 方法**：根据 `isUsedInputQueue` 开关决定直接发送还是入队，为后续输入调度预留扩展空间


### 📊 可观测性与性能监控（全新模块）

#### PerformanceMonitor 性能监控系统
- **新增 `Lib/PerformanceMonitor.ahk`**：提供两维度可观测能力
  - **阶段耗时统计（微秒级）**：`Start(stage)` / `End(stage)` 埋点 API，自动记录每个阶段的执行次数、平均/最小/最大耗时
  - **系统资源监控（可选）**：基于 `GetProcessTimes` 采样 CPU 使用率，基于 `GetProcessMemoryInfo` 采样内存工作集
  - **定期快照报告**：支持 `reportInterval` 控制生成间隔，退出时自动调用 `DumpReport()` 写入 `log/Performance/YYYY-MM-DD.txt`
- **关键路径埋点**：已在 `MainLogic`、`BeginFrame`、`BuffQuery`、`IsInSleep`、`OpenCondition`、`Action1~4`、各 `Send` 操作、`RealtimeGet`、`UpdateState`、`HandleSleep` 等核心路径嵌入埋点


### 🕹️ 核心逻辑引擎优化

#### 暴魔灵优先逻辑
- 新增 `g_enablePriorityUseDragoncall` 参数（从 INI 读取 `EnablePriorityUseDragoncall`）
- 当开启且 `Critical_Dragoncall` 技能就绪时，**优先使用暴魔灵而非开门（Open）**，优化输出优先级
- `Wingstorm` 条件增强：当暴魔灵暴击就绪时，禁止使用 `Wingstorm`，确保优先级正确

#### 技能条件精炼
- **Open 条件拆解**：将原复合条件拆解为 `deltaBombardment`、`deltaLeech`、`bombardmentWindow`、`leechWindowMin/Max` 等多步变量，提升代码可读性与可调试性
- **Action4 阈值调整**：`MantraReady` 的 Focus 阈值从 `(hasLeechBuff ? 4 : 5)` 调整为 `(hasLeechBuff ? 3 : 4)`，优化低 Focus 下的技能释放时机
- **DelaySendTab 增强**：在发送 `Tab` 前额外发送一次 `E` 键，适配游戏内的超神释放前置操作

#### 性能埋点集成
- 在 `_MainLogic` 及各子阶段嵌入 `PerformanceMonitor.Start/End`，为后续性能调优提供数据支撑


### 📝 日志系统增强

#### 按日期分文件存储
- **KeyLogger.ahk**：新增 `GetLogPath()` 方法，日志按日存储到 `log/KeyLog/YYYY-MM-DD.txt`
- **Log.ahk**：保留按日分割逻辑（`log_YYYYMMDD.txt`），与 KeyLogger 保持一致的目录规范

#### 全局日志开关（WRITELOG）
- **Globals.ahk** 新增 `WRITELOG` 全局变量
- **Log.ahk / KeyLogger.ahk** 新增 `Enabled` 静态属性，受 `WRITELOG` 统一控制
- 关闭时 `Write()` / `AppendLog()` 直接返回，零开销，适用于生产环境关闭调试日志


### 🛠 配置与集成层

#### Dragoncall-Config.ini 新增配置项
```ini
[Settings]
Gold_Leech=0                    # 金掠夺开关
LimitationOpen=1                # 开门限制释放
LimitationLeech=0               # 掠夺限制释放
RealtimeMode=1                  # 实时模式开关（直接读共享内存）
PerformanceMonitor=1            # 性能监控总开关
MonitorCpu=1                    # CPU 使用率监控
MonitorMemory=1                 # 内存占用监控
EnablePriorityUseDragoncall=0   # 优先暴魔灵（暴击时优先使用暴魔灵）
IsUsedInputQueue=0              # 是否启用 InputQueue 异步队列
ReportInterval=0                # 性能报告间隔（分钟，0=关闭）
WRITELOG=0                      # 全局日志写入开关
```

---

## [v3.8] - 2026-07-11 — 模块化工业架构与通用库拆分
### 🧩 架构重构：多模块工程化
- 单体拆分为多文件工程：将 ~800 行单体脚本拆分为 Main.ahk + Lib/* 模块，通过 #Include 按依赖顺序组合，支持 Ahk2Exe 打包后完整运行。

- 通用库与特化分离：

    - ActionMutex → DragoncallMutex：基类提供睡眠队列基础设施（SetSleep、ReleaseSleep、IsInSleep），声明 CanExecute/OnExecuted/BeginFrame 抽象接口；子类专精 Dragoncall 互斥规则与技能后摇时长。

    - CaptureClient → CaptureEngine：基类负责 DLL 加载、共享内存读写、技能/Buff 名称索引构建与原始状态同步；子类仅注入 S_first 闲置重置逻辑。

    - LogicRunner → LogicEngine：基类管理定时器调度、重入保护、硬间隔防抖、帧幂等；子类只实现 _MainLogic() 和 _HandleSleepState() 两个核心决策方法。

### ⚙️ 动作互斥引擎完善
- 抽象接口契约：ActionMutex 基类声明 CanExecute/OnExecuted/BeginFrame 抽象方法，未实现时调用直接抛错，强制子类遵守契约。

- 睡眠队列通用化：队列操作（插入、过期清理、优先级查询）完全收敛于基类，业务子类仅通过 switch sType 定义各睡眠类型的阻塞规则。

- X 键保护时长调整：xSleepTime 由 1000ms 调整为 800ms。

### 🕹️ 调度与运行时优化
- 热键移除 #HotIf 条件：XButton2、XButton1 绑定不再依赖 g_SysState == SYS_ACTIVE，改为无条件触发，内部通过 g_LogicEnabled 自行判断，消除因状态切换导致的松键事件丢失。

- 错误处理规范化：CaptureClient.Start() 使用 throw Error 替代 MsgBox + ExitApp，统一异常出口。

- 代码注释清理：移除冗余注释与调试 ToolTip，保留关键路径的 OutputDebug 和 KeyLogger 日志。

### 📊 可观测性与工具
- HiResTimer.Now() 格式化时钟：输出 MM/DD HH:mm:ss:ms 时间戳，基于 QPC 与 FILETIME 同步，用于日志时间标记。

- KeyLogger 空闲冲刷策略：批量队列 + 无输入后 1 秒自动落盘，带 5 次重试机制，避免文件锁定导致写入失败。

- 跨文件静态分析支持：可通过 ;@include 注释为 VSCode AHK++ 插件提供索引，消除模块化后的“未赋值”误报。

### 🛠 配置与部署
- DETECT_INTERVAL 调整：由 FRAME_MS * 0.60（≈10ms）改为 FRAME_MS * 0.30（≈5ms），提高状态采样频率以降低输入延迟。

- Globals.ahk 独立：全局常量和 KeyLogger 配置提取到独立文件，便于跨模块引用。

- GUI 保持不变：7 个 Checkbox 配置项（金技能 ×4、限制释放 ×2、自动超神）完整保留，配置持久化到 %APPDATA%\Dragoncall\config.ini。


---

## [v3.7] - 2026-07-11 — 状态机深化与安全执行模型
### ⚙️ 动作互斥引擎升级
- 睡眠队列化：ActionMutex 由单一睡眠状态升级为按过期时间排序的优先级队列，支持 OpenSleep / SoulflareSleep / LeechSleep / XSleep 等多重后摇保护共存，彻底消除旧版覆盖问题。

- 精确释放：ReleaseSleep(type) 可针对指定睡眠类型单独解除，避免全局误释放；开门释放失败时仅清除 OpenSleep，不影响其他保护。

- X 键独立保护：新增 X Sleep (type 5)，热键 ~$X:: 触发后全阻塞 MainLogic 1000ms，行为与 Open Sleep 一致，无需侵入主循环。

### 🧠 逻辑调度强化
- 硬间隔防抖：LogicExecuter 引入 g_LastExecutionTick，强制两次 MainLogic 执行间隔 ≥ LOGIC_INTERVAL * 0.9，杜绝定时器堆积造成的连续触键。

- 帧幂等增强：复用共享内存 frameId 实现严格一帧一决策，配合调度器实现稳定单次执行。

- 休眠阻塞语义：HandleSleepState 返回布尔标志，MainLogic 根据返回值提前 return，堵住睡眠期间技能泄漏的漏洞。

### 🕹️ 技能释放窗口控制
- 预输入与冷却窗口：引入 BombardmentPreInput、LeechDisableWindow、OpenTiming 等时间窗约束，精细控制开门、掠夺、死灵突袭的释放时机，防止后摇冲突。

- 掠夺状态机扩展：支持 Leech_Dark_L 暗色检测，并新增 g_limitationLeech 独立配置选项。

- Wingstorm 安全释放：增加掠夺后 0.8+0.35s、开门后 0.6s 的禁用期，确保首次必出暴魔灵。

### 📊 可观测性扩展
- KeyLogger 低级键盘钩子：独立类 KeyLogger，全局捕获所有按键（可选仅模拟输入），采用批量队列 + 空闲冲刷策略，对主逻辑零干扰。

- HiResTimer 高精度时钟：新增 Now() 方法，输出 MM/DD HH:mm:ss:ms 格式时间戳，基于 QPC 与 FILETIME 同步，微秒级精度。

- 关键路径日志增强：HandleSleepState 中添加详细的开门状态日志（OpenReady/Black/异常），辅助调试预输入与后摇保护。

### 🛠 配置与杂项
- 新增 GUI 选项：支持“掠夺限制释放”、“开门限制释放”、“金掠夺”独立开关，配置持久化到 config.ini。

- 代码结构化：所有状态收敛至 ActionMutex、LogicEngine、CaptureEngine 等类，消除全局变量污染，为模块化拆分铺路。

- 性能微调：DETECT_INTERVAL 由 2ms 调整为 5ms（FRAME_MS * 0.30），平衡状态更新频率与 CPU 占用。

---

## [v3.6] - 2026-06-28 — 异构计算架构（C++/AHK 混合）

### 🚀 架构革命
- **C++ DLL 取色引擎**：引入 DXGI 硬件加速捕获（CaptureDXGI.dll），取色延迟从 ~2ms 降至 <0.5ms，彻底释放 AHK 主线程。
- **共享内存零拷贝通信**：通过 Windows FileMapping 实现 C++ → AHK 状态传递，无序列化开销，微秒级响应。

### 🧠 逻辑调度升级
- **MinHeap 优先队列冷却器**：统一管理 Dragoncall/Wingstorm 等多技能冷却，支持批量事件调度与同名防重入。
- **ActionMutex 帧内互斥状态机**：支持 OpenSleep/SoulflareSleep/LeechSleep 三级休眠，精确控制技能释放窗口。

### 📊 可观测性增强
- **异步批量日志系统**：非阻塞日志队列 + 100ms 批量落盘，对主逻辑零性能影响，支持按日期分片归档。

### 🛠 部署与配置
- **FileInstall 嵌入部署**：所有 DLL 与配置编译进 EXE，运行时释放到 `%TEMP%`，零依赖启动。
- **AppData 用户配置隔离**：配置写入 `%APPDATA%\Dragoncall\config.ini`，程序升级不丢失用户设置。

---

## [v3.5] - 2026-05-10 — 架构级重构（FSM 化）

### 🚀 性能革命（硬实时）
- **零拷贝内存捕获**：引入 `FastMemoryCapture`（DIBSection 常驻），检测帧零 GDI 句柄申请，CPU 抖动归零。
- **微秒级高精度定时**：摒弃 `A_TickCount`，全量切换 `QueryPerformanceCounter` 实现 `HiResTimer`，支持精确毫秒级延迟窗口。

### 🧠 逻辑重构（抢占式调度）
- **双线程解耦**：分离 `DetectExecuter`（20ms 状态刷新）与 `LogicExecuter`（2ms 按键执行），实现生产者-消费者模型。
- **GCD 互斥锁**：引入 `blockDEF/EF/F` 三级锁机制，杜绝低优先级技能抢占 GCD，完美适配游戏公共冷却。
- **智能时间窗控制**：精准实现“超神后 280ms 硬直锁定”及“超神期 3s~12s 掠夺禁用”，复刻高玩肌肉记忆。

### 🛠 数据驱动（零硬编码）
- **声明式配置重构**：所有 Skill/Buff/Focus 点位转为 `config.ini` 驱动，支持 `ReadSplitToMap` 动态解析。
- **Buff 矩阵自动生成**：支持配置横向/纵向间距与数量，自动计算子检测点，彻底告别魔数偏移。

### 🛡 鲁棒性提升（工业级防御）
- **物理去抖（Debounce）**：Buff 状态需连续 2 帧一致才翻转，消除像素闪烁导致的误触发。
- **超时熔断机制**：Soulflare 若 500ms 未检测到即强制复位，防止状态卡死导致逻辑紊乱。
- **线程重入锁**：检测与逻辑执行器内置 `_running` 锁，杜绝高频定时器回调堆积导致的栈溢出。
