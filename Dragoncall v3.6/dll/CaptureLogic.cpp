#define NOMINMAX
#include <windows.h>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdio>

#pragma comment(lib, "user32.lib")

struct RawPoint { int x, y; COLORREF target; int tol; };
struct FocusPt  { int x, y, id; double refLum; };
struct BuffDebounce { bool state = false; int count = 0; };

static std::vector<std::string> g_skillNames;
static std::vector<std::string> g_buffNames;
static std::vector<std::vector<RawPoint>> g_skillGroups;
static std::vector<std::vector<RawPoint>> g_buffGroups;
static std::vector<FocusPt>  g_focusPts;
static std::vector<BuffDebounce> g_buffDebounce;
static int g_capX=0, g_capY=0, g_capW=0, g_capH=0;

typedef void* (*CreateCtxFn)(int,int,int,int);
typedef BOOL  (*CaptureFrameFn)(void*, BYTE*, int);
typedef void  (*DestroyCtxFn)(void*);
typedef int   (*GetRowPitchFn)(void*);
static HMODULE g_hDXGI = nullptr;
static CreateCtxFn   pCreateCtx   = nullptr;
static CaptureFrameFn pCapFrame   = nullptr;
static DestroyCtxFn  pDestroyCtx = nullptr;
static GetRowPitchFn pGetRowPitch = nullptr;
static void* g_captureCtx = nullptr;

static std::atomic<bool> g_running = false;
static HANDLE g_hThread = nullptr, g_hMap = nullptr;
static BYTE* g_pView = nullptr;
static LARGE_INTEGER g_freq;

double CalcLuminance(COLORREF c) { return GetRValue(c)*0.2126 + GetGValue(c)*0.7152 + GetBValue(c)*0.0722; }
bool IsPixelMatch(const BYTE* pixels, int rowPitch, int x, int y, COLORREF target, int tol) {
    if (x<0 || y<0 || x>=g_capW || y>=g_capH) return false;
    const BYTE* p = pixels + y*rowPitch + x*4;
    BYTE b=p[0], g=p[1], r=p[2];
    return (abs(r-GetRValue(target))<=tol && abs(g-GetGValue(target))<=tol && abs(b-GetBValue(target))<=tol);
}

std::wstring GetDllDir() {
    wchar_t path[MAX_PATH];
    HMODULE hm = nullptr;
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                           GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCWSTR)&GetDllDir, &hm)) {
        GetModuleFileNameW(hm, path, MAX_PATH);
        std::wstring full(path);
        size_t pos = full.find_last_of(L"\\/");
        if (pos != std::wstring::npos) full = full.substr(0, pos + 1);
        return full;
    }
    return L"";
}

bool LoadDXGI() {
    if (g_hDXGI) return true;
    std::wstring dllPath = GetDllDir() + L"CaptureDXGI.dll";
    g_hDXGI = LoadLibraryW(dllPath.c_str());
    if (!g_hDXGI) {
        OutputDebugStringW(L"StartCapture: LoadLibrary CaptureDXGI.dll failed");
        return false;
    }
    pCreateCtx   = (CreateCtxFn)GetProcAddress(g_hDXGI, "CreateCaptureContext");
    pCapFrame    = (CaptureFrameFn)GetProcAddress(g_hDXGI, "CaptureFrame");
    pDestroyCtx  = (DestroyCtxFn)GetProcAddress(g_hDXGI, "DestroyCaptureContext");
    pGetRowPitch = (GetRowPitchFn)GetProcAddress(g_hDXGI, "GetLastRowPitch");
    if (!pCreateCtx || !pCapFrame || !pDestroyCtx || !pGetRowPitch) {
        OutputDebugStringW(L"StartCapture: GetProcAddress failed (missing exports)");
        return false;
    }
    return true;
}

bool LoadConfig(const wchar_t* iniPath) {
    std::wstring cfgPath = GetDllDir() + L"CaptureConfig.dll";
    HMODULE hConfig = LoadLibraryW(cfgPath.c_str());
    if (!hConfig) {
        OutputDebugStringW(L"StartCapture: LoadLibrary CaptureConfig.dll failed");
        return false;
    }

    typedef BOOL (*LoadCfgFn)(const wchar_t*);
    typedef int  (*GetCountFn)();
    typedef const char* (*GetNameFn)(int);
    typedef int  (*GetPtsCountFn)(int);
    typedef void (*GetPointFn)(int,int,int*,int*,int*,int*,int*,int*);
    typedef void (*GetFocusFn)(int,int*,int*,int*,double*);
    typedef void (*GetBoxFn)(int*,int*,int*,int*);

    auto pLoadConfigFile = (LoadCfgFn)GetProcAddress(hConfig, "LoadConfigFile");
    auto pGetSkillCount   = (GetCountFn)GetProcAddress(hConfig, "GetSkillCount");
    auto pGetSkillName    = (GetNameFn)GetProcAddress(hConfig, "GetSkillName");
    auto pGetSkillPtCount = (GetPtsCountFn)GetProcAddress(hConfig, "GetSkillPointCount");
    auto pGetSkillPoint   = (GetPointFn)GetProcAddress(hConfig, "GetSkillPoint");
    auto pGetBuffCount    = (GetCountFn)GetProcAddress(hConfig, "GetBuffCount");
    auto pGetBuffName     = (GetNameFn)GetProcAddress(hConfig, "GetBuffName");
    auto pGetBuffPtCount  = (GetPtsCountFn)GetProcAddress(hConfig, "GetBuffPointCount");
    auto pGetBuffPoint    = (GetPointFn)GetProcAddress(hConfig, "GetBuffPoint");
    auto pGetFocusCount   = (GetCountFn)GetProcAddress(hConfig, "GetFocusCount");
    auto pGetFocusInfo    = (GetFocusFn)GetProcAddress(hConfig, "GetFocusInfo");
    auto pGetBoundingBox  = (GetBoxFn)GetProcAddress(hConfig, "GetBoundingBox");

    if (!pLoadConfigFile || !pGetSkillCount || !pGetSkillName || !pGetSkillPtCount || !pGetSkillPoint ||
        !pGetBuffCount || !pGetBuffName || !pGetBuffPtCount || !pGetBuffPoint ||
        !pGetFocusCount || !pGetFocusInfo || !pGetBoundingBox) {
        OutputDebugStringW(L"StartCapture: GetProcAddress Config functions failed");
        FreeLibrary(hConfig);
        return false;
    }

    if (!pLoadConfigFile(iniPath)) {
        OutputDebugStringW(L"StartCapture: LoadConfigFile failed");
        FreeLibrary(hConfig);
        return false;
    }

    g_skillNames.clear(); g_skillGroups.clear();
    g_buffNames.clear(); g_buffGroups.clear(); g_buffDebounce.clear();
    g_focusPts.clear();

    int sc = pGetSkillCount();
    for (int i = 0; i < sc; ++i) {
        const char* name = pGetSkillName(i);
        g_skillNames.push_back(name);
        int pc = pGetSkillPtCount(i);
        std::vector<RawPoint> pts;
        for (int j = 0; j < pc; ++j) {
            int x, y, r, g, b, tol;
            pGetSkillPoint(i, j, &x, &y, &r, &g, &b, &tol);
            pts.push_back({x, y, RGB(r, g, b), tol});
        }
        g_skillGroups.push_back(pts);
    }

    int bc = pGetBuffCount();
    for (int i = 0; i < bc; ++i) {
        const char* name = pGetBuffName(i);
        g_buffNames.push_back(name);
        int pc = pGetBuffPtCount(i);
        std::vector<RawPoint> pts;
        for (int j = 0; j < pc; ++j) {
            int x, y, r, g, b, tol;
            pGetBuffPoint(i, j, &x, &y, &r, &g, &b, &tol);
            pts.push_back({x, y, RGB(r, g, b), tol});
        }
        g_buffGroups.push_back(pts);
        g_buffDebounce.push_back({false, 0});
    }

    int fc = pGetFocusCount();
    for (int i = 0; i < fc; ++i) {
        int x, y, id; double refLum;
        pGetFocusInfo(i, &x, &y, &id, &refLum);
        g_focusPts.push_back({x, y, id, refLum});
    }

    pGetBoundingBox(&g_capX, &g_capY, &g_capW, &g_capH);
    FreeLibrary(hConfig);
    return true;
}

DWORD WINAPI CaptureThread(LPVOID) {
    QueryPerformanceFrequency(&g_freq);
    std::vector<BYTE> buf(g_capW * g_capH * 4);
    int realRowPitch = g_capW * 4;

    while (g_running) {
        if (!pCapFrame(g_captureCtx, buf.data(), (int)buf.size())) {
            Sleep(1);
            continue;
        }
        realRowPitch = pGetRowPitch(g_captureCtx);

        LARGE_INTEGER t1, t2;
        QueryPerformanceCounter(&t1);

        uint8_t skillRes[64] = {};
        for (size_t i = 0; i < g_skillGroups.size(); ++i) {
            bool state = false;
            for (size_t j = 0; j < g_skillGroups[i].size(); ++j) {
                const RawPoint& pt = g_skillGroups[i][j];
                if (IsPixelMatch(buf.data(), realRowPitch, pt.x - g_capX, pt.y - g_capY, pt.target, pt.tol)) {
                    state = true; break;
                }
            }
            skillRes[i] = state ? 1 : 0;
        }

        int curFocus = -1;
        for (size_t i = 0; i < g_focusPts.size(); ++i) {
            const FocusPt& f = g_focusPts[i];
            int lx = f.x - g_capX, ly = f.y - g_capY;
            if (lx >= 0 && lx < g_capW && ly >= 0 && ly < g_capH) {
                const BYTE* px = buf.data() + ly * realRowPitch + lx * 4;
                double lum = CalcLuminance(RGB(px[2], px[1], px[0]));
                if (lum >= f.refLum && f.id > curFocus)
                    curFocus = f.id;
            }
        }

        uint8_t buffRes[64] = {};
        for (size_t i = 0; i < g_buffGroups.size(); ++i) {
            bool exists = false;
            for (size_t j = 0; j < g_buffGroups[i].size(); ++j) {
                const RawPoint& pt = g_buffGroups[i][j];
                if (IsPixelMatch(buf.data(), realRowPitch, pt.x - g_capX, pt.y - g_capY, pt.target, pt.tol)) {
                    exists = true; break;
                }
            }
            BuffDebounce& deb = g_buffDebounce[i];
            if (exists == deb.state) deb.count = 0;
            else { deb.count++; if (deb.count >= 2) { deb.state = exists; deb.count = 0; } }
            buffRes[i] = deb.state ? 1 : 0;
        }

        QueryPerformanceCounter(&t2);

        if (g_pView) {
            uint32_t fid = *(uint32_t*)g_pView + 1;
            memcpy(g_pView, &fid, 4);
            uint64_t ts = GetTickCount64(); memcpy(g_pView + 4, &ts, 8);
            memcpy(g_pView + 12, &curFocus, 4);
            uint32_t sc = (uint32_t)g_skillNames.size(), bc = (uint32_t)g_buffNames.size();
            memcpy(g_pView + 16, &sc, 4); memcpy(g_pView + 20, &bc, 4);
            if (sc) memcpy(g_pView + 24, skillRes, sc);
            if (bc) memcpy(g_pView + 24 + sc, buffRes, bc);
            uint32_t* pPerf = (uint32_t*)(g_pView + 24 + sc + bc);
            pPerf[0] = (uint32_t)((t2.QuadPart - t1.QuadPart) * 1000000 / g_freq.QuadPart);
        }
    }
    return 0;
}

extern "C" {
__declspec(dllexport) BOOL __cdecl StartCapture(const wchar_t* iniPath) {
    if (g_running) return FALSE;

    if (!LoadDXGI()) {
        return FALSE;
    }
    if (!LoadConfig(iniPath)) {
        return FALSE;
    }

    wchar_t boxMsg[128];
    swprintf_s(boxMsg, L"StartCapture: bounding box (%d,%d) %dx%d", g_capX, g_capY, g_capW, g_capH);
    OutputDebugStringW(boxMsg);

    if (g_capW <= 0 || g_capH <= 0) {
        OutputDebugStringW(L"StartCapture: invalid bounding box");
        return FALSE;
    }

    g_captureCtx = pCreateCtx(g_capX, g_capY, g_capW, g_capH);
    if (!g_captureCtx) {
        OutputDebugStringW(L"StartCapture: CreateCaptureContext failed");
        return FALSE;
    }

    g_hMap = CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0, 4096, L"Local\\DragoncallState");
    if (!g_hMap) {
        wchar_t buf[64];
        swprintf_s(buf, L"StartCapture: CreateFileMapping failed, error=%u", GetLastError());
        OutputDebugStringW(buf);
        pDestroyCtx(g_captureCtx);
        g_captureCtx = nullptr;
        return FALSE;
    }

    g_pView = (BYTE*)MapViewOfFile(g_hMap, FILE_MAP_WRITE, 0, 0, 4096);
    if (!g_pView) {
        wchar_t buf[64];
        swprintf_s(buf, L"StartCapture: MapViewOfFile failed, error=%u", GetLastError());
        OutputDebugStringW(buf);
        CloseHandle(g_hMap);
        g_hMap = nullptr;
        pDestroyCtx(g_captureCtx);
        g_captureCtx = nullptr;
        return FALSE;
    }

    ZeroMemory(g_pView, 4096);
    g_running = true;
    g_hThread = CreateThread(nullptr, 0, CaptureThread, nullptr, 0, nullptr);
    if (!g_hThread) {
        wchar_t buf[64];
        swprintf_s(buf, L"StartCapture: CreateThread failed, error=%u", GetLastError());
        OutputDebugStringW(buf);
        g_running = false;
        UnmapViewOfFile(g_pView);
        g_pView = nullptr;
        CloseHandle(g_hMap);
        g_hMap = nullptr;
        pDestroyCtx(g_captureCtx);
        g_captureCtx = nullptr;
        return FALSE;
    }

    return TRUE;
}

__declspec(dllexport) void __cdecl StopCapture() {
    g_running = false;
    if (g_hThread) { WaitForSingleObject(g_hThread, 3000); CloseHandle(g_hThread); g_hThread = nullptr; }
    if (g_captureCtx) { pDestroyCtx(g_captureCtx); g_captureCtx = nullptr; }
    if (g_pView) { UnmapViewOfFile(g_pView); g_pView = nullptr; }
    if (g_hMap)  { CloseHandle(g_hMap); g_hMap = nullptr; }
}

__declspec(dllexport) int __cdecl GetSkillCount() { return (int)g_skillNames.size(); }
__declspec(dllexport) const char* __cdecl GetSkillName(int idx) {
    if (idx < 0 || idx >= (int)g_skillNames.size()) return nullptr;
    return g_skillNames[idx].c_str();
}
__declspec(dllexport) int __cdecl GetBuffCount() { return (int)g_buffNames.size(); }
__declspec(dllexport) const char* __cdecl GetBuffName(int idx) {
    if (idx < 0 || idx >= (int)g_buffNames.size()) return nullptr;
    return g_buffNames[idx].c_str();
}
}

BOOL WINAPI DllMain(HINSTANCE, DWORD, LPVOID) { return TRUE; }