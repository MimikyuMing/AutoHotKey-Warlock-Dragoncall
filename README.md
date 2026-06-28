# 基于AutoHotKey的 剑灵neo 的咒术暴魔灵流派宏

AHK 版本需要v2.0

# 使用须知
# 前提
- 布局默认(双排布局)
- 大小默认
- 亮度50
- 1920*1080
# 按键须知
1. [Ctrl + F11] 启动脚本
2. [Ctrl + F5] 重载脚本
3. [XButton2] 鼠标侧键2 持续触发
4. [Ctrl + F3] 显示/隐藏GUI
5. [XButton1] 鼠标侧键1 闪避(ss)

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
