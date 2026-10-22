#Requires AutoHotkey v2.0
;==============================================================================
; mouse_cursor.ahk
; キーボードでのマウス操作
;   MousePlain … カーソル移動（1 回押すごとに固定量、押しっぱなしで加速。移動量はモニターの画素数に連動）と
;                スクロール（1 回押すごとに 1 ノッチ）。キーリピート駆動
;   MouseNav   … ワープ（アクティブウィンドウ・モニターの中央、縦に並んだモニター、外付けモニターの中央）
;   Mouse_*    … 右クリックメニュー、カーソル下をアクティブに、ドラッグ開始／解除
; 使っていなかったタイマー駆動のなめらかな移動・スクロール、2 分割ジャンプ、四隅へのワープ、微小移動は
; Lib\archive\mouse_nav_timer.ahk に移した（設計の経緯の説明もそこにある）。
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\text_input.ahk


class MouseNav {
    ;--- 初期化（初回アクセス時に自動実行）-------------------------------------
    static __New() {
        DllCall("winmm\timeBeginPeriod", "UInt", 1)             ; タイマー分解能を 1ms に（window_switch.ahk の Sleep(1) もこれを前提にしている）
        OnExit((*) => (DllCall("winmm\timeEndPeriod", "UInt", 1), 0))
        hU := DllCall("GetModuleHandle", "Str", "user32", "Ptr")
        this._pGet := DllCall("GetProcAddress", "Ptr", hU, "AStr", "GetCursorPos", "Ptr")
        this._pSet := DllCall("GetProcAddress", "Ptr", hU, "AStr", "SetCursorPos", "Ptr")
        this._pt := Buffer(8, 0)
        InstallKeybdHook()                                      ; 物理キー状態の取得に必要
    }

    ;=== ワープ =================================================================

    ; アクティブウィンドウの中央へ移動
    ; 対象となるウィンドウがない場合（デスクトップ、タスクバー、最小化中など）は、
    ; カーソルのあるモニターの中央へ移動する
    static WarpToActiveWindow() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if this._IsWarpTarget(hwnd) {
            rc := UI_VisibleRect(hwnd)
            cx := (rc.l + rc.r) // 2
            cy := (rc.t + rc.b) // 2
            ; ウィンドウの中央がどのモニター上にもない場合は採用しない
            if DllCall("MonitorFromPoint", "Int64", (cy << 32) | (cx & 0xFFFFFFFF), "UInt", 0, "Ptr") {
                DllCall(this._pSet, "Int", cx, "Int", cy, "Int")
                return
            }
        }
        this.WarpToMonitorCenter()
    }

    ; カーソルのあるモニターの中央へ移動
    static WarpToMonitorCenter() {
        this._GetPos(&x, &y)
        r := this._MonitorRect(x, y)
        DllCall(this._pSet, "Int", (r.L + r.R) // 2, "Int", (r.T + r.B) // 2, "Int")
    }

    ; 次のモニターへ移動
    ; center = false : 現在と同じ相対位置へ
    ; center = true  : モニターの中央へ
    static WarpToNextMonitor(center := false) {
        mons := this._Monitors()
        if (mons.Length < 2)
            return
        this._GetPos(&x, &y)
        cur := 1
        for i, m in mons {
            if (x >= m.L && x < m.R && y >= m.T && y < m.B) {
                cur := i
                break
            }
        }
        a := mons[cur], b := mons[Mod(cur, mons.Length) + 1]
        if center {
            nx := (b.L + b.R) // 2
            ny := (b.T + b.B) // 2
        } else {
            nx := b.L + Round((x - a.L) / (a.R - a.L) * (b.R - b.L))
            ny := b.T + Round((y - a.T) / (a.B - a.T) * (b.B - b.T))
        }
        DllCall(this._pSet, "Int", nx, "Int", ny, "Int")
    }

    ; 外付けモニターの中央へ移動（外付けの間を左から右へ巡回。外付け以外からは最も左の外付けへ）
    ; 外付けが 1 台以下（内蔵＋外付けの 2 画面など）のときは、全モニターの中央を巡回する
    static WarpToExternalCenter() {
        mons := this._ExternalMonitors()
        if (mons.Length < 2)
            mons := this._Monitors()
        if !mons.Length
            return
        this._GetPos(&x, &y)
        next := 1
        for i, m in mons {
            if (x >= m.L && x < m.R && y >= m.T && y < m.B) {
                next := Mod(i, mons.Length) + 1
                break
            }
        }
        b := mons[next]
        DllCall(this._pSet, "Int", (b.L + b.R) // 2, "Int", (b.T + b.B) // 2, "Int")
    }

    ;=== 内部処理 ===============================================================

    ; 縦に並んだモニターへ移動：下にモニターがあれば下へ、なければ上へ（上下 2 段の配置で、上下を行き来する）。
    ; 上が複数あるとき（メインの上にサブ 2 台など）、下へ行く前にいたモニターに戻る。初めてなら、横方向の重なりが最も大きいもの
    ; center = true：モニターの中央へ、false：同じ相対位置へ
    static WarpVertical(center := true) {
        mons := this._Monitors()
        if (mons.Length < 2)
            return
        this._GetPos(&x, &y)
        a := ""
        for m in mons {
            if (x >= m.L && x < m.R && y >= m.T && y < m.B) {
                a := m
                break
            }
        }
        if !IsObject(a)
            return
        b := this._VerticalNeighbor(mons, a, 1)
        if IsObject(b)
            this._cameFrom := a
        else
            b := this._VerticalNeighbor(mons, a, -1)
        if !IsObject(b)
            return
        if center {
            nx := (b.L + b.R) // 2
            ny := (b.T + b.B) // 2
        } else {
            nx := b.L + Round((x - a.L) / (a.R - a.L) * (b.R - b.L))
            ny := b.T + Round((y - a.T) / (a.B - a.T) * (b.B - b.T))
        }
        DllCall(this._pSet, "Int", nx, "Int", ny, "Int")
    }

    ; a の下（dir = 1）または上（dir = -1）にあるモニターのうち、横方向の重なりが最も大きいもの（同じなら縦の距離、横の距離が近い順）。なければ ""
    static _VerticalNeighbor(mons, a, dir) {
        ay := (a.T + a.B) / 2, ax := (a.L + a.R) / 2
        best := "", bo := -1, bv := 0, bh := 0
        for m in mons {
            my := (m.T + m.B) / 2
            if ((my - ay) * dir <= 0)
                continue
            if (dir < 0 && IsObject(this._cameFrom) && m.L = this._cameFrom.L && m.T = this._cameFrom.T)
                return m
            ov := Max(0, Min(a.R, m.R) - Max(a.L, m.L))
            vd := Abs(my - ay), hd := Abs((m.L + m.R) / 2 - ax)
            if (ov > bo || (ov = bo && (vd < bv || (vd = bv && hd < bh))))
                best := m, bo := ov, bv := vd, bh := hd
        }
        return best
    }
    static _cameFrom := ""
    static _GetPos(&x, &y) {
        DllCall(this._pGet, "Ptr", this._pt, "Int")
        x := NumGet(this._pt, 0, "Int"), y := NumGet(this._pt, 4, "Int")
    }

    static _MoveBy(dx, dy) {
        this._GetPos(&x, &y)
        DllCall(this._pSet, "Int", x + dx, "Int", y + dy, "Int")
    }

    ; ワープ先として有効な通常ウィンドウかを判定する（デスクトップ・タスクバー・非表示・最小化中は除く）
    static _IsWarpTarget(hwnd) {
        return hwnd
            && DllCall("IsWindowVisible", "Ptr", hwnd)
            && !DllCall("IsIconic", "Ptr", hwnd)
            && !UI_IsShellWindow(hwnd)
    }

    ; カーソルのあるモニターの矩形（タスクバー含む全体）
    static _MonitorRect(x, y) => UI_MonitorRectFromPoint(x, y)

    ; 全モニターの矩形を「左端の小さい順、同じなら上端の小さい順」で返す。excluded にあるデバイス名（小文字）は除く
    static _Monitors(excluded := 0) {
        mons := []
        loop MonitorGetCount() {
            if (excluded && excluded.Has(StrLower(MonitorGetName(A_Index))))
                continue
            MonitorGet(A_Index, &l, &t, &r, &b)
            i := mons.Length + 1
            while (i > 1 && (mons[i - 1].L > l || (mons[i - 1].L = l && mons[i - 1].T > t)))
                i--
            mons.InsertAt(i, {L: l, T: t, R: r, B: b})
        }
        return mons
    }

    ; 内蔵ディスプレイ（ノート PC 本体）を除いたモニター。内蔵が判別できなければ全モニター
    static _ExternalMonitors() {
        mons := this._Monitors(this._InternalDeviceNames())
        return mons.Length ? mons : this._Monitors()
    }

    ; 内蔵接続（eDP 等）のモニターの GDI デバイス名（\\.\DISPLAYn、小文字）の集合
    static _InternalDeviceNames() {
        names := Map()
        if DllCall("GetDisplayConfigBufferSizes", "UInt", 2, "UInt*", &nP := 0, "UInt*", &nM := 0)   ; QDC_ONLY_ACTIVE_PATHS
            return names
        paths := Buffer(72 * nP, 0), modes := Buffer(64 * nM, 0)
        if DllCall("QueryDisplayConfig", "UInt", 2, "UInt*", &nP, "Ptr", paths, "UInt*", &nM, "Ptr", modes, "Ptr", 0)
            return names
        req := Buffer(84, 0)                                    ; DISPLAYCONFIG_SOURCE_DEVICE_NAME
        loop nP {
            p := paths.Ptr + 72 * (A_Index - 1)
            tech := NumGet(p, 36, "UInt")                       ; targetInfo.outputTechnology
            if (tech != 0x80000000 && tech != 11 && tech != 13) ; INTERNAL / DISPLAYPORT_EMBEDDED / UDI_EMBEDDED
                continue
            NumPut("UInt", 1, req, 0), NumPut("UInt", 84, req, 4)
            DllCall("RtlMoveMemory", "Ptr", req.Ptr + 8, "Ptr", p, "UPtr", 8)   ; sourceInfo.adapterId
            NumPut("UInt", NumGet(p, 8, "UInt"), req, 16)                       ; sourceInfo.id
            if !DllCall("DisplayConfigGetDeviceInfo", "Ptr", req)
                names[StrLower(StrGet(req.Ptr + 20, 32, "UTF-16"))] := true
        }
        return names
    }
}


;==============================================================================
; MousePlain : 以前のシンプルな動作（キーリピート駆動）
;------------------------------------------------------------------------------
; ・カーソル移動：1 回押すごとに MOVE_PX ジャンプ。押しっぱなし（キーリピート中）は
;   同方向の連続呼び出しに加速倍率（最大 MAX_ACCEL 倍）を掛ける。（旧 MoveCursorTo*2）
; ・スクロール  ：1 回押すごとにホイール SCROLL_NOTCH ノッチ。（旧 SendInput("{WheelUp 1}")）
; ・移動量はカーソルのあるモニターの画素数に比例して拡大する（SCALE_BY_MONITOR）。
; ※ MouseNav と違い、キーを離したことの検知やタイマーは使わない。
;==============================================================================
class MousePlain {
    ;--- 設定 -----------------------------------------------------------------
    static MOVE_PX          := 200   ; 1 回の移動量 [px]（BASE_W×BASE_H での値）
    static REPEAT_WINDOW    := 100   ; この ms 以内の再呼び出しを「押しっぱなし」とみなす
    static MAX_ACCEL        := 4.0   ; 加速の上限倍率
    static ACCEL_STEP       := 0.35  ; 1 回あたりの加速量
    static SCROLL_NOTCH     := 1     ; 1 回のスクロール量 [ノッチ]

    static SCALE_BY_MONITOR := true  ; 移動量をモニターの画素数に連動させる（false で固定値）
    static BASE_W           := 1920  ; 基準モニターの幅 [px]
    static BASE_H           := 1080  ; 基準モニターの高さ [px]

    ;--- 内部状態 -------------------------------------------------------------
    static _lastTick := 0, _lastDX := 0, _lastDY := 0, _accel := 1.0

    ; 1 回分の移動（dx, dy は基準モニターでの px。accelerate = false で加速なし）
    static Move(dx, dy, accelerate := true) {
        if accelerate {
            now := A_TickCount
            if (now - this._lastTick <= this.REPEAT_WINDOW && dx = this._lastDX && dy = this._lastDY)
                this._accel := Min(this._accel + this.ACCEL_STEP, this.MAX_ACCEL)
            else
                this._accel := 1.0
            this._lastTick := now, this._lastDX := dx, this._lastDY := dy
        } else {
            this._accel := 1.0, this._lastTick := 0
        }
        k := this._accel * this._MonitorScale()
        ; API アドレス・座標系は MouseNav と共通のものを使う
        MouseNav._MoveBy(Round(dx * k), Round(dy * k))
    }

    ; 1 回分のスクロール（dir: "Up"/"Down"/"Left"/"Right"）
    static Scroll(dir) => SendInput("{Wheel" dir " " this.SCROLL_NOTCH "}")

    ; カーソルのあるモニターの拡大倍率（対角線の画素数 ÷ 基準モニターの対角線）
    static _MonitorScale() {
        if !this.SCALE_BY_MONITOR
            return 1.0
        MouseNav._GetPos(&x, &y)
        r := MouseNav._MonitorRect(x, y)
        w := r.R - r.L, h := r.B - r.T
        if (w <= 0 || h <= 0)
            return 1.0
        return Sqrt(w * w + h * h) / Sqrt(this.BASE_W ** 2 + this.BASE_H ** 2)
    }
}

;==============================================================================
; 呼び出し用ラッパー（引数なしで呼べる）
;==============================================================================
;--- MouseNav（ワープ）--------------------------------------------------------
MouseNav_WarpWindow()        => MouseNav.WarpToActiveWindow()
MouseNav_WarpCenter()        => MouseNav.WarpToMonitorCenter()
MOUSENAV_VERTICAL_CENTER := true                        ; true：縦のモニターの中央へ、false：同じ相対位置へ
MouseNav_WarpVertical() {
    MouseNav.WarpVertical(MOUSENAV_VERTICAL_CENTER)
    Mouse_FocusUnderCursor()
}
MouseNav_WarpExternalCenter() {
    MouseNav.WarpToExternalCenter()
    Mouse_FocusUnderCursor()
}

;--- MousePlain（キーリピート駆動・シンプル）-----------------------------------
; カーソル移動（1 回押すごとに固定量、押しっぱなしで加速）
MousePlain_Left()            => MousePlain.Move(-MousePlain.MOVE_PX, 0)
MousePlain_Right()           => MousePlain.Move( MousePlain.MOVE_PX, 0)
MousePlain_Up()              => MousePlain.Move(0, -MousePlain.MOVE_PX)
MousePlain_Down()            => MousePlain.Move(0,  MousePlain.MOVE_PX)
; スクロール（1 回押すごとにホイール SCROLL_NOTCH ノッチ）
MousePlain_ScrollUp()        => MousePlain.Scroll("Up")
MousePlain_ScrollDown()      => MousePlain.Scroll("Down")
MousePlain_ScrollLeft()      => MousePlain.Scroll("Left")
MousePlain_ScrollRight()     => MousePlain.Scroll("Right")


;==============================================================================
; そのほかのマウス操作
;==============================================================================

; 右クリックメニュー（アプリケーションキー）を開く
Mouse_ContextMenu() {
    Ime_Alnum()
    SendInput("{vk5Dsc15D}")
}

; マウスカーソル下のウィンドウをアクティブにする
Mouse_FocusUnderCursor() {
    MouseGetPos(, , &winID)
    if (!winID || WinActive("ahk_id " winID))
        return
    ; 前面化は「最後に入力を受けたプロセス」にしか許されないので、空のマウス入力を送って権利を得る
    mi := Buffer(A_PtrSize = 8 ? 40 : 28, 0)                    ; INPUT_MOUSE、移動量 0
    DllCall("SendInput", "UInt", 1, "Ptr", mi, "Int", mi.Size)
    DllCall("SetForegroundWindow", "Ptr", winID)
    if !WinActive("ahk_id " winID)
        try WinActivate("ahk_id " winID)
}

; 左ボタンの押しっぱなし／解除を切り替える（ドラッグ用）。ドラッグ中は Esc / Space+Caps でキャンセル
Mouse_dragging := false

Mouse_ToggleDrag() {
    global Mouse_dragging
    if Mouse_dragging {
        Click("Up")
        Mouse_dragging := false
        UI_TipFlash("Released", 3000)
    } else {
        Click("Down")
        Mouse_dragging := true
        UI_TipFlash("Holding", 3000)
    }
}

Mouse_IsDragging() => Mouse_dragging

Mouse_CancelDrag() {
    global Mouse_dragging
    Click("Up")
    Mouse_dragging := false
    UI_TipFlash("Canceled", 2000)
}

#HotIf Mouse_IsDragging() && !IH_waiting
Esc:: Mouse_CancelDrag()
vk20 & sc03A:: Mouse_CancelDrag()                   ; Space+Caps
#HotIf
