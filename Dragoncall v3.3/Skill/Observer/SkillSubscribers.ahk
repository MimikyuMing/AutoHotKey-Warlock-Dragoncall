#Requires AutoHotkey v2.0

#Include ../SkillStatus.ahk

class DragoncallSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Dragoncall'] := data
    }
}

class WingstormSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Wingstorm'] := data
    }
}

class SoulFlare1Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['SoulFlare1'] := data
        SkillStatus['IsSoulFlare'] := data
    }
}

class SoulFlare2Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['SoulFlare2'] := data
        SkillStatus['IsSoulFlare'] := data || SkillStatus['SoulFlare1']
    }
}

class SoulFlare3Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['SoulFlare3'] := data
        SkillStatus['IsSoulFlare'] := data || SkillStatus['SoulFlare1'] || SkillStatus['SoulFlare2']
    }
}

class Leech1Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech1'] := data
        SkillStatus['IsLeech'] := data
    }
}

class Leech2Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech2'] := data
        SkillStatus['IsLeech'] := data || SkillStatus['Leech1']
    }
}

class Leech3Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech3'] := data
        SkillStatus['IsLeech'] := data || SkillStatus['Leech1'] || SkillStatus['Leech2']
    }
}

class Leech_Dir1Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech_Dir1'] := data
        SkillStatus['Leech'] := data || SkillStatus['Leech_Dir11']
    }
}

class Leech_Dir11Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Leech_Dir11'] := data
        SkillStatus['Leech'] := data
    }
}

class MantraSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Mantra'] := data
        SkillStatus['Mantra'] := data
    }
}

class Rupture_Dir1Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Rupture_Dir1'] := data
        SkillStatus['Rupture'] := data || SkillStatus['Rupture_Dir11']
    }
}

class Rupture_Dir11Subscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Rupture_Dir11'] := data
        SkillStatus['Rupture'] := data
    }
}

class FocusSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['Focus'] := data
        ; ToolTip('Focus : ' SkillStatus['Focus'], 805, 840)
    }
}



class SoulFlareSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['IsSoulFlare'] := data
    }
}

class LeechSubscribers {
    Update(data) {
        global SkillStatus
        SkillStatus['IsLeech'] := data
    }
}
