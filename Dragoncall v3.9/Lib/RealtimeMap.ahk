#Requires AutoHotkey v2.0

#Include StateManager.ahk

; RealtimeMap.ahk
class RealtimeMap extends Map {
    type   := ""          ; "skill" 或 "buff"
    idxMap := Map()       ; 名称 → 共享内存索引


    ; 帧缓存（静态，所有 RealtimeMap 实例共享）
    static lastFrameId   := -1
    static lastFrameData := false

    ; 覆盖 Get 方法
    Get(key, default?) {
        if (StateManager.realtimeMode && this.type) {
            ; 获取缓存帧（极快，同一帧内只读一次共享内存）
            frameData := CaptureClient.GetCachedFrame()
            if IsObject(frameData) {
                PerformanceMonitor.Start("RealtimeGet")
                idx := this.idxMap.Get(key, -1)
                result := false
                if idx >= 0 {
                    bytes := (this.type == "skill") ? frameData.skillBytes : frameData.buffBytes
                    if idx < bytes.Size
                        result := NumGet(bytes, idx, "UChar") != 0
                }
                PerformanceMonitor.End("RealtimeGet")
                return result
            }
            return false
        }
        ; 缓存模式
        return IsSet(default) ? super.Get(key, default) : super.Get(key)
    }

    __Item[key] {
        get => this.Get(key, false)
        set => super[key] := value      ; 写入基类 Map
    }
}