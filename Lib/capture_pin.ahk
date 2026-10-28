#Requires AutoHotkey v2.0
;==============================================================================
; capture_pin.ahk
; 付箋スクリーンショット：撮った画像のサムネイルを最前面に固定して残す（一時的な確認用）。screen_capture.ahk の Cap_Pin() から使う
;   Pin_Add(hbm, w, h, px, py)  画像（HBITMAP。複製して使うので、呼び出し側は自分で破棄してよい）を付箋にする。点 (px, py) のあるモニターに出す（省略時はメインのモニター）
;   Pin_CloseAll()      すべての付箋を消す
;
; 操作
;   クリック：拡大 / 元の大きさへ　　ドラッグ：移動　　右クリック：その付箋を消す
;   Esc：すべて消す（入力待ち・撮影の選択中の Esc は、そちらの取り消しに使う）
; 複数枚は、撮った範囲のあるモニターの右上から左へ、重ならないように並べる。
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\key_wait.ahk

PIN_THUMB_W      := 200                    ; サムネイルの枠の幅 [px]。どの画像も同じ大きさの枠に、縦横比を保って収める（小さい画像は拡大しない）
PIN_THUMB_H      := 120                    ; サムネイルの枠の高さ [px]
PIN_THUMB_BG     := 0x202020               ; 枠の中で、画像のない余白の色（COLORREF は BGR）
PIN_BORDER_PX    := 2                      ; 枠の太さ
PIN_BORDER_COLOR := "FFB000"               ; 枠の色
PIN_MARGIN_PX    := 12                     ; 画面の端からの余白（並べるとき・拡大したとき）
PIN_GAP_PX       := 8                      ; 付箋どうしの間隔
PIN_DRAG_PX      := 5                       ; これ以上動かしたらクリックでなくドラッグとみなす

Pin_list := []                             ; 出している付箋 {g, pic, full, thumb, big, w, h, tw, th, expanded, alive}
Pin_hook := ""                             ; Esc を見る InputHook（付箋があるあいだだけ動かす）
Pin_drag := ""                             ; 左ボタンを押している間の状態 {p, sx, sy, wx, wy, dragged}

OnMessage(0x201, _Pin_OnLButtonDown)       ; WM_LBUTTONDOWN
OnMessage(0x203, _Pin_OnLButtonDown)       ; WM_LBUTTONDBLCLK（素早く続けたクリックも 1 回ずつ扱う）
OnMessage(0x200, _Pin_OnMouseMove)         ; WM_MOUSEMOVE
OnMessage(0x202, _Pin_OnLButtonUp)         ; WM_LBUTTONUP
OnMessage(0x204, _Pin_OnRButtonDown)       ; WM_RBUTTONDOWN

Pin_Add(hbm, w, h, px := "", py := "") {
    mon := (px = "") ? MonitorGetPrimary() : UI_MonitorFromPoint(px, py)
    scale := Min(1, PIN_THUMB_W / w, PIN_THUMB_H / h)
    iw := Max(1, Round(w * scale)), ih := Max(1, Round(h * scale))
    tw := PIN_THUMB_W, th := PIN_THUMB_H
    b := PIN_BORDER_PX
    p := {full: _Pin_Scale(hbm, w, h, w, h), thumb: _Pin_Scale(hbm, w, h, iw, ih, tw, th), big: 0
        , w: w, h: h, tw: tw, th: th, expanded: false, alive: true, g: "", pic: ""}
    p.g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")   ; アクティブにならない
    p.g.BackColor := PIN_BORDER_COLOR
    p.pic := p.g.Add("Picture", "x" b " y" b " w" tw " h" th, "HBITMAP:*" p.thumb)   ; * ：画像はこちらで持ち続ける（差し替えで削除させない）
    _Pin_Place(p, &x, &y, mon)
    p.g.Show("NA x" x " y" y " w" tw + 2 * b " h" th + 2 * b)
    Pin_list.Push(p)
    _Pin_HookStart()
}

Pin_CloseAll() {
    while Pin_list.Length
        _Pin_Close(Pin_list[1])
}

; 右上から左へ並べ、画面の左端に届いたら 1 段下げる
_Pin_Place(p, &x, &y, mon) {
    MonitorGetWorkArea(mon, &l, &t, &r, &bt)
    ww := p.tw + 2 * PIN_BORDER_PX, wh := p.th + 2 * PIN_BORDER_PX
    x := r - PIN_MARGIN_PX - ww, y := t + PIN_MARGIN_PX
    loop 200 {
        hit := ""
        for q in Pin_list {
            WinGetPos(&qx, &qy, &qw, &qh, q.g.Hwnd)
            if (x < qx + qw + PIN_GAP_PX && qx < x + ww + PIN_GAP_PX && y < qy + qh + PIN_GAP_PX && qy < y + wh + PIN_GAP_PX) {
                hit := {x: qx, y: qy, h: qh}
                break
            }
        }
        if !hit
            return
        x := hit.x - PIN_GAP_PX - ww
        if (x < l + PIN_MARGIN_PX)
            x := r - PIN_MARGIN_PX - ww, y := hit.y + hit.h + PIN_GAP_PX
    }
}

; src（w×h）を dw×dh の新しい画像にする（縮小は HALFTONE で滑らかに）。bw・bh を渡すと、bw×bh の枠の中央に置き、余白は PIN_THUMB_BG で埋める
_Pin_Scale(src, w, h, dw, dh, bw := 0, bh := 0) {
    bw := bw || dw, bh := bh || dh
    scr := DllCall("GetDC", "Ptr", 0, "Ptr")
    dst := DllCall("CreateCompatibleBitmap", "Ptr", scr, "Int", bw, "Int", bh, "Ptr")
    sdc := DllCall("CreateCompatibleDC", "Ptr", scr, "Ptr")
    ddc := DllCall("CreateCompatibleDC", "Ptr", scr, "Ptr")
    so := DllCall("SelectObject", "Ptr", sdc, "Ptr", src, "Ptr")
    do := DllCall("SelectObject", "Ptr", ddc, "Ptr", dst, "Ptr")
    if (bw != dw || bh != dh) {
        rc := Buffer(16, 0), NumPut("Int", 0, "Int", 0, "Int", bw, "Int", bh, rc)
        br := DllCall("CreateSolidBrush", "UInt", PIN_THUMB_BG, "Ptr")
        DllCall("FillRect", "Ptr", ddc, "Ptr", rc, "Ptr", br)
        DllCall("DeleteObject", "Ptr", br)
    }
    DllCall("SetStretchBltMode", "Ptr", ddc, "Int", 4)           ; HALFTONE
    DllCall("SetBrushOrgEx", "Ptr", ddc, "Int", 0, "Int", 0, "Ptr", 0)
    DllCall("StretchBlt", "Ptr", ddc, "Int", (bw - dw) // 2, "Int", (bh - dh) // 2, "Int", dw, "Int", dh
        , "Ptr", sdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "UInt", 0xCC0020)   ; SRCCOPY
    DllCall("SelectObject", "Ptr", sdc, "Ptr", so)
    DllCall("SelectObject", "Ptr", ddc, "Ptr", do)
    DllCall("DeleteDC", "Ptr", sdc)
    DllCall("DeleteDC", "Ptr", ddc)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", scr)
    return dst
}

_Pin_Find(hwnd) {
    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")   ; GA_ROOT
    for p in Pin_list
        if (p.g.Hwnd = root)
            return p
    return ""
}

_Pin_Close(p) {
    p.alive := false
    p.g.Destroy()
    for i, q in Pin_list
        if (q = p) {
            Pin_list.RemoveAt(i)
            break
        }
    for bmp in [p.full, p.thumb, p.big]
        if bmp
            DllCall("DeleteObject", "Ptr", bmp)
    if !Pin_list.Length
        _Pin_HookStop()
}

;------------------------------------------------------------------------------
; クリックで拡大・ドラッグで移動・右クリックで消す
;------------------------------------------------------------------------------
_Pin_OnLButtonDown(wParam, lParam, msg, hwnd) {
    global Pin_drag
    p := _Pin_Find(hwnd)
    if !p
        return
    MouseGetPos(&sx, &sy)
    WinGetPos(&wx, &wy, , , p.g.Hwnd)
    Pin_drag := {p: p, sx: sx, sy: sy, wx: wx, wy: wy, dragged: false}
    DllCall("SetCapture", "Ptr", p.g.Hwnd)                   ; 付箋の外へ出ても、離すまでこの窓に届ける
    return 0
}

_Pin_OnMouseMove(wParam, lParam, msg, hwnd) {
    if IsObject(Pin_drag) && Pin_drag.p.alive
        _Pin_DragTo(Pin_drag)
}

_Pin_DragTo(d) {
    MouseGetPos(&mx, &my)
    if (!d.dragged && Abs(mx - d.sx) + Abs(my - d.sy) > PIN_DRAG_PX)
        d.dragged := true
    if d.dragged
        WinMove(d.wx + mx - d.sx, d.wy + my - d.sy, , , d.p.g.Hwnd)
}

_Pin_OnLButtonUp(wParam, lParam, msg, hwnd) {
    global Pin_drag
    if !IsObject(Pin_drag)
        return
    d := Pin_drag
    Pin_drag := ""
    DllCall("ReleaseCapture")
    if !d.p.alive
        return 0
    _Pin_DragTo(d)                                              ; 動かしている間の移動は取りこぼすことがあるので、最後の位置を合わせる
    if !d.dragged
        _Pin_Toggle(d.p)
    return 0
}

_Pin_OnRButtonDown(wParam, lParam, msg, hwnd) {
    p := _Pin_Find(hwnd)
    if !p
        return
    _Pin_Close(p)
    return 0
}

; 拡大（画面に収まる大きさまで）⇔ サムネイル。拡大は左上を保ち、はみ出すときだけ画面内に寄せる。
; 縮小は、拡大前のサムネイルの位置に戻す（拡大したまま動かしたときは、その左上のまま小さくする）
_Pin_Toggle(p) {
    p.expanded := !p.expanded
    b := PIN_BORDER_PX
    WinGetPos(&x, &y, , , p.g.Hwnd)
    if p.expanded {
        p.home := {x: x, y: y}
        MonitorGetWorkArea(UI_MonitorFromPoint(x, y), &l, &t, &r, &bt)
        fit := Min(1, (r - l - 2 * (PIN_MARGIN_PX + b)) / p.w, (bt - t - 2 * (PIN_MARGIN_PX + b)) / p.h)
        dw := Max(1, Round(p.w * fit)), dh := Max(1, Round(p.h * fit))
        if (!p.big && fit < 1)
            p.big := _Pin_Scale(p.full, p.w, p.h, dw, dh)
        bmp := (fit < 1) ? p.big : p.full
    } else
        dw := p.tw, dh := p.th, bmp := p.thumb
    p.pic.Move(b, b, dw, dh)
    p.pic.Value := "HBITMAP:*" bmp
    p.g.Show("NA w" dw + 2 * b " h" dh + 2 * b)
    if p.expanded {
        UI_ClampToMonitor(p.g.Hwnd, &x, &y)
        p.g.Move(x, y)
        p.expPos := {x: x, y: y}
    } else if (p.HasProp("expPos") && x = p.expPos.x && y = p.expPos.y)
        p.g.Move(p.home.x, p.home.y)
}

;------------------------------------------------------------------------------
; Esc ですべて消す（付箋があるあいだだけ見る。キーは奪わない）
;------------------------------------------------------------------------------
_Pin_HookStart() {
    global Pin_hook
    if IsObject(Pin_hook)
        return
    h := InputHook("V")
    h.KeyOpt("{Escape}", "N")
    h.OnKeyDown := _Pin_OnKeyDown
    h.OnEnd := (*) => (Pin_list.Length ? h.Start() : 0)           ; 文字数の上限などで終わっても、続けて見る
    h.Start()
    Pin_hook := h
}

_Pin_HookStop() {
    global Pin_hook
    if IsObject(Pin_hook)
        Pin_hook.Stop()
    Pin_hook := ""
}

_Pin_OnKeyDown(ih, vk, sc) {
    if (vk = 0x1B)
        Pin_EscAll()
}

; Esc の働き（入力待ち・撮影の選択中の Esc は、そちらの取り消しに使うので何もしない）。
; Space+Caps は hold_keys.ahk が Esc を送るが、自分で送ったキーは自分の InputHook に届かないので、そこからこれを呼ぶ
Pin_EscAll() {
    if (IH_waiting || (IsSet(Cap_session) && IsObject(Cap_session)))
        return
    Pin_CloseAll()
}
