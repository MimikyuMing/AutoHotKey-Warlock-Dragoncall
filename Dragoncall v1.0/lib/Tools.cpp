// Tools.cpp
#include <windows.h>

extern "C" {
    // 完全匹配AHK的ColorDist函数
    __declspec(dllexport) int ColorDist(UINT c1, UINT c2) {
        int dr = ((c1 >> 16) & 0xFF) - ((c2 >> 16) & 0xFF);
        int dg = ((c1 >> 8) & 0xFF) - ((c2 >> 8) & 0xFF);
        int db = (c1 & 0xFF) - (c2 & 0xFF);
        return dr * dr + dg * dg + db * db;
    }

    // 主函数 - 完全匹配IsColorMatchAt逻辑
    __declspec(dllexport) int IsColorMatchAt_Opt(int x, int y, UINT color, int tol, UINT mask) {
        HDC hdc = GetDC(NULL);
        COLORREF winColor = GetPixel(hdc, x, y);
        ReleaseDC(NULL, hdc);
        
        // 将0x00BBGGRR转换为0x00RRGGBB
        UINT c = ((winColor & 0x0000FF) << 16) | 
                (winColor & 0x00FF00) | 
                ((winColor & 0xFF0000) >> 16);
        
        // 完全匹配AHK逻辑
        if (tol > 0) {
            return ColorDist(c, color) <= tol;
        }
        return (c & mask) == (color & mask);
    }
}