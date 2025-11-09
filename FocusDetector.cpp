#include <windows.h>
#include <cmath>

struct Point {
    int x;
    int y;
    COLORREF color;
};

extern "C" {
    __declspec(dllexport) int IsLowFocus_Full(int x, int y, COLORREF refColor) {
        HDC hdc = GetDC(NULL);
        COLORREF actColor = GetPixel(hdc, x, y);
        ReleaseDC(NULL, hdc);
        
        double refL = ((refColor >> 16) & 0xFF) * 0.2126 +
                     ((refColor >> 8)  & 0xFF) * 0.7152 +
                     (refColor & 0xFF) * 0.0722;
        
        double actL = ((actColor >> 16) & 0xFF) * 0.2126 +
                     ((actColor >> 8)  & 0xFF) * 0.7152 +
                     (actColor & 0xFF) * 0.0722;
        
        return actL < refL;
    }
    
    __declspec(dllexport) int BatchLowFocus_Full(Point* points, int count) {
        HDC hdc = GetDC(NULL);
        int result = 0;
        
        for (int i = 0; i < count; i++) {
            COLORREF actColor = GetPixel(hdc, points[i].x, points[i].y);
            
            double refL = ((points[i].color >> 16) & 0xFF) * 0.2126 +
                         ((points[i].color >> 8)  & 0xFF) * 0.7152 +
                         (points[i].color & 0xFF) * 0.0722;
            
            double actL = ((actColor >> 16) & 0xFF) * 0.2126 +
                         ((actColor >> 8)  & 0xFF) * 0.7152 +
                         (actColor & 0xFF) * 0.0722;
            
            if (actL < refL) {
                result = i + 1;
                break;
            }
        }
        
        ReleaseDC(NULL, hdc);
        return result;
    }
}