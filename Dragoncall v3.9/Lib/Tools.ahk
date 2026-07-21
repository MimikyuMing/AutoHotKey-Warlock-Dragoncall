#Requires AutoHotkey v2.0

ParseBool(str) {
    if !IsSet(str) || str = ""
        return false
    str := StrLower(Trim(str))
    if str = "true" or str = "yes" or str = "1" or str = "on" or str = "enable"
        return true
    if str = "false" or str = "no" or str = "0" or str = "off" or str = "disable"
        return false
    try
        return Integer(str) != 0
    catch
        return false
}