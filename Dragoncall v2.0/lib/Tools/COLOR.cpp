// C++ DLL 导出函数

extern "C" __declspec(dllexport) BOOL IsLowFocus(int x, int y, COLORREF refColor) {
    HDC hdc = GetDC(0);
    COLORREF actualColor = GetPixel(hdc, x, y);
    ReleaseDC(0, hdc);
    
    // 计算参考颜色亮度 (ITU-R BT.709)
    double refL = ((refColor >> 16) & 0xFF) * 0.2126
                + ((refColor >> 8)  & 0xFF) * 0.7152
                + ( refColor        & 0xFF) * 0.0722;
    
    // 计算实际颜色亮度
    double actL = ((actualColor >> 16) & 0xFF) * 0.2126
                + ((actualColor >> 8)  & 0xFF) * 0.7152
                + ( actualColor        & 0xFF) * 0.0722;
    
    return actL < refL;
}