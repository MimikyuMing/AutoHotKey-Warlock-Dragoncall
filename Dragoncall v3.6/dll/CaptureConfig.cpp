#define NOMINMAX
#include <windows.h>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <cstdio>

#pragma comment(lib, "user32.lib")

struct RawPoint { int x, y; COLORREF target; int tol; };
struct FocusPt { int x, y, id; double refLum; };

static std::vector<std::string> g_skillNames;
static std::vector<std::string> g_buffNames;
static std::vector<std::vector<RawPoint>> g_skillGroups;
static std::vector<std::vector<RawPoint>> g_buffGroups;
static std::vector<FocusPt> g_focusPts;
static int g_capX=0, g_capY=0, g_capW=0, g_capH=0;

std::string W2U(const wchar_t* w) {
    if (!w) return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
    if (len <= 0) return "";
    std::string r(len-1, 0);
    WideCharToMultiByte(CP_UTF8, 0, w, -1, &r[0], len, nullptr, nullptr);
    return r;
}

COLORREF HexToRGB(const wchar_t* s) {
    if (s[0] == L'0' && (s[1] == L'x' || s[1] == L'X')) s += 2;
    else if (s[0] == L'#') s += 1;
    unsigned int c = wcstoul(s, nullptr, 16);
    return RGB((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF);
}

double CalcLuminance(COLORREF c) { return GetRValue(c)*0.2126 + GetGValue(c)*0.7152 + GetBValue(c)*0.0722; }

extern "C" {

__declspec(dllexport) BOOL __cdecl LoadConfigFile(const wchar_t* iniPath) {
    g_skillNames.clear(); g_skillGroups.clear();
    g_buffNames.clear(); g_buffGroups.clear();
    g_focusPts.clear();

    int bv  = GetPrivateProfileIntW(L"Settings", L"Buff_Vertical", 1, iniPath);
    int bh  = GetPrivateProfileIntW(L"Settings", L"Buff_Horizontal", 1, iniPath);
    int bvs = GetPrivateProfileIntW(L"Settings", L"Buff_Vertical_space", 0, iniPath);
    int bhs = GetPrivateProfileIntW(L"Settings", L"Buff_Horizontal_space", 0, iniPath);

    wchar_t keys[32767];
    GetPrivateProfileStringW(L"Skill", nullptr, L"", keys, 32767, iniPath);
    wchar_t* p = keys;
    std::map<std::string, std::vector<RawPoint>> tmpSkills;
    while (*p) {
        std::wstring wkey(p);
        std::string key = W2U(wkey.c_str());
        wchar_t val[256];
        GetPrivateProfileStringW(L"Skill", wkey.c_str(), L"", val, 256, iniPath);
        int x, y, tol;
        wchar_t clr[16] = {0};
        if (swscanf_s(val, L"%d,%d,%15[^,],%d", &x, &y, clr, (unsigned)_countof(clr), &tol) != 4) {
            p += wcslen(p) + 1; continue;
        }
        COLORREF c = HexToRGB(clr);
        std::string baseKey = key;
        size_t pos = baseKey.rfind('_');
        if (pos != std::string::npos) {
            std::string suffix = baseKey.substr(pos + 1);
            bool isNumber = !suffix.empty() && std::all_of(suffix.begin(), suffix.end(), ::isdigit);
            if (isNumber) baseKey = baseKey.substr(0, pos);
        }
        tmpSkills[baseKey].push_back({x, y, c, tol});
        p += wcslen(p) + 1;
    }
    for (auto& kv : tmpSkills) g_skillNames.push_back(kv.first);
    std::sort(g_skillNames.begin(), g_skillNames.end());
    for (size_t i = 0; i < g_skillNames.size(); ++i)
        g_skillGroups.push_back(tmpSkills[g_skillNames[i]]);

    wchar_t buffKeys[32767];
    GetPrivateProfileStringW(L"Buff", nullptr, L"", buffKeys, 32767, iniPath);
    p = buffKeys;
    std::map<std::string, RawPoint> baseBuffs;
    while (*p) {
        std::wstring wkey(p);
        std::string key = W2U(wkey.c_str());
        wchar_t val[256];
        GetPrivateProfileStringW(L"Buff", wkey.c_str(), L"", val, 256, iniPath);
        int x, y, tol;
        wchar_t clr[16] = {0};
        if (swscanf_s(val, L"%d,%d,%15[^,],%d", &x, &y, clr, (unsigned)_countof(clr), &tol) != 4) {
            p += wcslen(p) + 1; continue;
        }
        baseBuffs[key] = {x, y, HexToRGB(clr), tol};
        p += wcslen(p) + 1;
    }
    std::vector<std::string> sortedBuffs;
    for (auto& kv : baseBuffs) sortedBuffs.push_back(kv.first);
    std::sort(sortedBuffs.begin(), sortedBuffs.end());
    for (auto& name : sortedBuffs) {
        RawPoint bp = baseBuffs[name];
        int grid = bv * bh;
        std::vector<RawPoint> grp;
        int offsetX = 0;
        for (int i = 0; i < grid; ++i) {
            int r = i / bh, c = i % bh;
            if ((c + 1) == 4 || (c + 1) == 8) offsetX += 1;
            int ox = c * bhs + offsetX;
            grp.push_back({bp.x - ox, bp.y + r * bvs, bp.target, bp.tol});
        }
        g_buffNames.push_back(name);
        g_buffGroups.push_back(grp);
    }

    int fx = GetPrivateProfileIntW(L"Focus", L"FocusBaseX", 0, iniPath);
    int fy = GetPrivateProfileIntW(L"Focus", L"FocusBaseY", 0, iniPath);
    int fs = GetPrivateProfileIntW(L"Focus", L"FocusSpace", 0, iniPath);
    wchar_t fclr[16] = {0};
    GetPrivateProfileStringW(L"Focus", L"FocusBaseRGB", L"000000", fclr, 16, iniPath);
    double refLum = CalcLuminance(HexToRGB(fclr));
    for (int i = 1; i <= 10; ++i)
        g_focusPts.push_back({fx - (10 - i) * fs, fy, i, refLum});

    int minX=INT_MAX, minY=INT_MAX, maxX=INT_MIN, maxY=INT_MIN;
    for (auto& grp : g_skillGroups) for (auto& pt : grp) {
        minX = (std::min)(minX, pt.x); maxX = (std::max)(maxX, pt.x);
        minY = (std::min)(minY, pt.y); maxY = (std::max)(maxY, pt.y);
    }
    for (auto& grp : g_buffGroups) for (auto& pt : grp) {
        minX = (std::min)(minX, pt.x); maxX = (std::max)(maxX, pt.x);
        minY = (std::min)(minY, pt.y); maxY = (std::max)(maxY, pt.y);
    }
    for (auto& pt : g_focusPts) {
        minX = (std::min)(minX, pt.x); maxX = (std::max)(maxX, pt.x);
        minY = (std::min)(minY, pt.y); maxY = (std::max)(maxY, pt.y);
    }
    g_capX = (std::max)(0, minX); g_capY = (std::max)(0, minY);
    g_capW = (std::min)(GetSystemMetrics(SM_CXVIRTUALSCREEN), maxX - minX + 1);
    g_capH = (std::min)(GetSystemMetrics(SM_CYVIRTUALSCREEN), maxY - minY + 1);
    return (g_capW > 0 && g_capH > 0);
}

__declspec(dllexport) int __cdecl GetSkillCount() { return (int)g_skillNames.size(); }
__declspec(dllexport) const char* __cdecl GetSkillName(int idx) {
    if (idx < 0 || idx >= (int)g_skillNames.size()) return nullptr;
    return g_skillNames[idx].c_str();
}
__declspec(dllexport) int __cdecl GetSkillPointCount(int skillIdx) {
    if (skillIdx < 0 || skillIdx >= (int)g_skillGroups.size()) return 0;
    return (int)g_skillGroups[skillIdx].size();
}
__declspec(dllexport) void __cdecl GetSkillPoint(int skillIdx, int ptIdx, int* x, int* y, int* r, int* g, int* b, int* tol) {
    if (skillIdx < 0 || skillIdx >= (int)g_skillGroups.size()) return;
    auto& pts = g_skillGroups[skillIdx];
    if (ptIdx < 0 || ptIdx >= (int)pts.size()) return;
    auto& pt = pts[ptIdx];
    *x = pt.x; *y = pt.y; *tol = pt.tol;
    *r = GetRValue(pt.target); *g = GetGValue(pt.target); *b = GetBValue(pt.target);
}

__declspec(dllexport) int __cdecl GetBuffCount() { return (int)g_buffNames.size(); }
__declspec(dllexport) const char* __cdecl GetBuffName(int idx) {
    if (idx < 0 || idx >= (int)g_buffNames.size()) return nullptr;
    return g_buffNames[idx].c_str();
}
__declspec(dllexport) int __cdecl GetBuffPointCount(int buffIdx) {
    if (buffIdx < 0 || buffIdx >= (int)g_buffGroups.size()) return 0;
    return (int)g_buffGroups[buffIdx].size();
}
__declspec(dllexport) void __cdecl GetBuffPoint(int buffIdx, int ptIdx, int* x, int* y, int* r, int* g, int* b, int* tol) {
    if (buffIdx < 0 || buffIdx >= (int)g_buffGroups.size()) return;
    auto& pts = g_buffGroups[buffIdx];
    if (ptIdx < 0 || ptIdx >= (int)pts.size()) return;
    auto& pt = pts[ptIdx];
    *x = pt.x; *y = pt.y; *tol = pt.tol;
    *r = GetRValue(pt.target); *g = GetGValue(pt.target); *b = GetBValue(pt.target);
}

__declspec(dllexport) int __cdecl GetFocusCount() { return (int)g_focusPts.size(); }
__declspec(dllexport) void __cdecl GetFocusInfo(int idx, int* x, int* y, int* id, double* refLum) {
    if (idx < 0 || idx >= (int)g_focusPts.size()) return;
    auto& f = g_focusPts[idx];
    *x = f.x; *y = f.y; *id = f.id; *refLum = f.refLum;
}

__declspec(dllexport) void __cdecl GetBoundingBox(int* x, int* y, int* w, int* h) {
    *x = g_capX; *y = g_capY; *w = g_capW; *h = g_capH;
}

} // extern "C"

BOOL WINAPI DllMain(HINSTANCE, DWORD, LPVOID) { return TRUE; }