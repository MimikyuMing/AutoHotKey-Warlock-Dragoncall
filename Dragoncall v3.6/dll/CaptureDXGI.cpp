#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <wrl/client.h>
#include <cstdint>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "user32.lib")

using Microsoft::WRL::ComPtr;

struct CaptureContext {
    ID3D11Device*           device;
    ID3D11DeviceContext*    context;
    IDXGIOutputDuplication* dupl;
    ID3D11Texture2D*        staging;
    int capX, capY, capW, capH;
    int lastRowPitch;         
    LARGE_INTEGER freq;
};

extern "C" {

__declspec(dllexport) CaptureContext* __cdecl CreateCaptureContext(int x, int y, int w, int h) {
    CaptureContext* ctx = new CaptureContext();
    ZeroMemory(ctx, sizeof(CaptureContext));
    ctx->capX = x; ctx->capY = y; ctx->capW = w; ctx->capH = h;

    D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
        nullptr, 0, D3D11_SDK_VERSION, &ctx->device, &fl, &ctx->context);
    if (FAILED(hr)) { delete ctx; return nullptr; }

    ComPtr<IDXGIDevice> dxgiDevice;
    hr = ctx->device->QueryInterface(IID_PPV_ARGS(&dxgiDevice));
    if (FAILED(hr)) { ctx->device->Release(); delete ctx; return nullptr; }

    ComPtr<IDXGIAdapter> adapter;
    dxgiDevice->GetAdapter(&adapter);
    ComPtr<IDXGIOutput> output;
    hr = adapter->EnumOutputs(0, &output);
    if (FAILED(hr)) { ctx->device->Release(); delete ctx; return nullptr; }

    ComPtr<IDXGIOutput1> output1;
    hr = output->QueryInterface(IID_PPV_ARGS(&output1));
    if (FAILED(hr)) { ctx->device->Release(); delete ctx; return nullptr; }

    hr = output1->DuplicateOutput(ctx->device, &ctx->dupl);
    if (FAILED(hr)) { ctx->device->Release(); delete ctx; return nullptr; }

    D3D11_TEXTURE2D_DESC desc = {};
    desc.Width = w; desc.Height = h;
    desc.MipLevels = 1; desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.Usage = D3D11_USAGE_STAGING;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    hr = ctx->device->CreateTexture2D(&desc, nullptr, &ctx->staging);
    if (FAILED(hr)) {
        ctx->dupl->Release();
        ctx->device->Release();
        delete ctx;
        return nullptr;
    }

    QueryPerformanceFrequency(&ctx->freq);
    return ctx;
}

__declspec(dllexport) BOOL __cdecl CaptureFrame(CaptureContext* ctx, BYTE* outBuffer, int bufferSize) {
    if (!ctx || !outBuffer) return FALSE;
    int reqSize = ctx->capW * ctx->capH * 4;
    if (bufferSize < reqSize) return FALSE;

    ComPtr<IDXGIResource> deskRes;
    DXGI_OUTDUPL_FRAME_INFO frameInfo;
    HRESULT hr = ctx->dupl->AcquireNextFrame(100, &frameInfo, &deskRes);
    if (hr == DXGI_ERROR_WAIT_TIMEOUT || FAILED(hr)) {
        ctx->dupl->ReleaseFrame();
        return FALSE;
    }

    ComPtr<ID3D11Texture2D> desktopTex;
    deskRes->QueryInterface(IID_PPV_ARGS(&desktopTex));
    deskRes = nullptr;

    D3D11_BOX box = { (UINT)ctx->capX, (UINT)ctx->capY, 0,
                      (UINT)(ctx->capX + ctx->capW), (UINT)(ctx->capY + ctx->capH), 1 };
    ctx->context->CopySubresourceRegion(ctx->staging, 0, 0, 0, 0, desktopTex.Get(), 0, &box);

    D3D11_MAPPED_SUBRESOURCE map;
    if (SUCCEEDED(ctx->context->Map(ctx->staging, 0, D3D11_MAP_READ, 0, &map))) {
        ctx->lastRowPitch = map.RowPitch;          
        memcpy(outBuffer, map.pData, reqSize);
        ctx->context->Unmap(ctx->staging, 0);
    }
    ctx->dupl->ReleaseFrame();
    return TRUE;
}

__declspec(dllexport) int __cdecl GetLastRowPitch(CaptureContext* ctx) {
    return ctx ? ctx->lastRowPitch : 0;
}

__declspec(dllexport) void __cdecl DestroyCaptureContext(CaptureContext* ctx) {
    if (!ctx) return;
    if (ctx->staging) ctx->staging->Release();
    if (ctx->dupl)    ctx->dupl->Release();
    if (ctx->context) ctx->context->Release();
    if (ctx->device)  ctx->device->Release();
    delete ctx;
}

} // extern "C"

BOOL WINAPI DllMain(HINSTANCE, DWORD, LPVOID) { return TRUE; }