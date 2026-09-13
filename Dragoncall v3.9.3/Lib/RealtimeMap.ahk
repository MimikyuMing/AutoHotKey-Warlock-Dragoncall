#Requires AutoHotkey v2.0

#Include StateManager.ahk
#Include PerformanceMonitor.ahk
#Include CaptureClient.ahk

; RealtimeMap.ahk
class RealtimeMap extends Map {
    type   := ""          ; "skill" 或 "buff"
    idxMap := Map()       ; 名称 → 共享内存索引
    realtimeMode := false

    ; 帧缓存（静态，所有 RealtimeMap 实例共享）
    static lastFrameId   := -1
    static lastFrameData := false

    __New(params){
        this.realtimeMode := params
    }

    ; 覆盖 Get 方法
    Get(key, default?) {
        if (this.realtimeMode && this.type) {
            frameData := CaptureClient.GetCachedFrame()
            if IsObject(frameData) {
                PerformanceMonitor.Start("RealtimeMap-RealtimeGet")
                idx := this.idxMap.Get(key, -1)
                result := false
                if idx >= 0 {
                    bytes := 0
                    switch this.type {
                        case "skill":
                            bytes := frameData.skillBytes
                        case "buff":
                            bytes := frameData.buffBytes
                        case "coldDown":
                            bytes := frameData.coldDownBytes
                        default:
                            bytes := 0
                    }
                    if bytes != 0 && idx < bytes.Size
                        result := NumGet(bytes, idx, "UChar") != 0
                }
                PerformanceMonitor.End("RealtimeMap-RealtimeGet")
                return result
            }
            return false
        }
        return IsSet(default) ? super.Get(key, default) : super.Get(key)
    }

    __Item[key] {
        get => this.Get(key, false)
        set => super[key] := value      ; 写入基类 Map
    }
}