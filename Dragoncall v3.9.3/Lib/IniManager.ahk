#Requires AutoHotkey v2.0

class IniManager {
    static iniPath := ""
    static ReadToMap(section) {
        m := Map()
        if !FileExist(this.iniPath)
            return m
        keysStr := IniRead(this.iniPath, section, , "")
        if keysStr = ""
            return m
        for line in StrSplit(keysStr, "`n", "`r") {
            line := Trim(line)
            if line = ""
                continue
            parts := StrSplit(line, "=", , 2)
            if parts.Length < 2
                continue
            m[Trim(parts[1])] := Trim(parts[2])
        }
        return m
    }
    static ReadSplitToMap(section, delimiter := ",") {
        m := Map()
        if !FileExist(this.iniPath)
            return m
        keysStr := IniRead(this.iniPath, section, , "")
        if keysStr = ""
            return m
        for line in StrSplit(keysStr, "`n", "`r") {
            line := Trim(line)
            if line = ""
                continue
            parts := StrSplit(line, "=", , 2)
            if parts.Length < 2
                continue
            k := Trim(parts[1]), v := Trim(parts[2])
            arr := StrSplit(v, delimiter)
            cleaned := []
            for item in arr {
                item := Trim(item)
                if item != ""
                    cleaned.Push(item)
            }
            m[k] := cleaned
        }
        return m
    }
    static Write(section, key, value) {
        IniWrite(value, this.iniPath, section, key)
    }
    static WriteMap(section, map) {
        for k, v in map
            this.Write(section, k, v)
    }
}