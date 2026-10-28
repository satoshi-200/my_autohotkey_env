#Requires AutoHotkey v2.0
; 付箋（Lib\capture_pin.ahk）の出る位置：指定した点のあるモニターの右上、2 枚目はその左。マウスは使わない
#Include ..\harness.ahk
#Include ..\..\Lib\capture_pin.ahk
T_Start("msg")

hbm := DllCall("CreateBitmap", "Int", 400, "Int", 200, "UInt", 1, "UInt", 32, "Ptr", 0, "Ptr")

Geo(i) {
    WinGetPos(&x, &y, &w, &h, Pin_list[i].g.Hwnd)
    return {x: x, y: y, w: w, h: h}
}

loop MonitorGetCount() {
    mon := A_Index
    MonitorGet(mon, &l, &t, &r, &b)
    MonitorGetWorkArea(mon, &wl, &wt, &wr, &wb)
    Pin_Add(hbm, 400, 200, (l + r) // 2, (t + b) // 2)
    Pin_Add(hbm, 400, 200, (l + r) // 2, (t + b) // 2)
    a := Geo(1), c := Geo(2)
    T_Expect("モニター " mon "：1 枚目は右上", (wr - a.x - a.w) "," (a.y - wt), PIN_MARGIN_PX "," PIN_MARGIN_PX)
    T_Expect("モニター " mon "：2 枚目は 1 枚目の左", (a.x - c.x - c.w) "," (c.y - a.y), PIN_GAP_PX ",0")
    Pin_CloseAll()
}

Pin_Add(hbm, 400, 200)
a := Geo(1)
MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
T_Expect("点を渡さなければメインのモニター", (wr - a.x - a.w) "," (a.y - wt), PIN_MARGIN_PX "," PIN_MARGIN_PX)
Pin_CloseAll()
hbm2 := DllCall("CreateBitmap", "Int", 100, "Int", 300, "UInt", 1, "UInt", 32, "Ptr", 0, "Ptr")
Pin_Add(hbm, 400, 200)
Pin_Add(hbm2, 100, 300)
a := Geo(1), c := Geo(2)
T_Expect("縦横比が違っても、サムネイルは同じ大きさ", a.w "x" a.h, c.w "x" c.h)
T_Expect("サムネイルの大きさ（枠込み）", a.w "x" a.h, (PIN_THUMB_W + 2 * PIN_BORDER_PX) "x" (PIN_THUMB_H + 2 * PIN_BORDER_PX))
Pin_CloseAll()
DllCall("DeleteObject", "Ptr", hbm2)
DllCall("DeleteObject", "Ptr", hbm)

T_End()
