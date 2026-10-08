#Requires AutoHotkey v2.0
;==============================================================================
; mouse_cursor.ahk
; MouseNav : ホームポジションのままマウスカーソルを操作する（AutoHotkey v2）
;------------------------------------------------------------------------------
; 【MoveCursorTo*2 系からの設計変更】
; (1) キーリピート駆動 → タイマー駆動
;     従来は「リピート 1 回 = 1 回移動」のため、初回リピート待ち（約 250ms）と
;     リピート間隔（約 30ms）が、そのまま出だしの遅れと動きのカクつきになっていた。
;     本版は押下で移動を開始し、以降はタイマーで物理キーの状態を監視しながら
;     連続的に移動する。キーを離した瞬間に停止する。
; (2) 速度は「押下からの経過時間」の関数
;     V_START から V_MAX まで CURVE に沿って加速する。
;     フレーム間隔（dt）を QueryPerformanceCounter で実測して移動量を決めるため、
;     タイマーの揺らぎや Arm エミュレーション下の遅延があっても速度が一定になる。
;     1px 未満の端数は次フレームに持ち越すため、低速でも滑らかに動く。
; (3) 2 方向の同時押しで斜め移動（斜めでも速度が速くならないよう正規化）
; (4) 移動中に Slow／Fast キーを押している間だけ、精密モード／高速モードに切替
; (5) Bisect（2 分割ジャンプ）
;     押すたびに対象領域を半分に絞り込み、その中央へ移動する。
;     5～6 回で画面上の任意の位置に到達できる（最初はカーソルのあるモニター全体）。
; (6) Warp：アクティブウィンドウの中央／モニターの中央／モニターの四隅／
;     次のモニター（同じ相対位置 or 中央）へ瞬間移動
;     アクティブウィンドウが対象外（デスクトップ、タスクバー、最小化中など）の場合は
;     カーソルのあるモニターの中央へ移動する。
;     モニターの巡回順は「左から右、同じ左端なら上から下」で、座標から自動判定する。
; (7) 従来版の高速化策は継承
;     API アドレスの事前解決、GetCursorPos/SetCursorPos による生ピクセル座標の統一、
;     per-monitor v2 DPI、Buffer の使い回し
; (8) スムーズスクロール（2026/09/29 追加・改良）
;     タイマー駆動で、押している間だけ加速しながらスクロールする。
;     押した瞬間に「タップ量」（S_TAP、既定 1 ノッチ）を S_TAP_MS の間に
;     減速カーブで一気に送り出すため、短押しでもキビキビ反応する。
;     押し続けると、並行して連続スクロールが S_START から S_MAX まで加速する。
;     離した後は S_GLIDE_MS の短い慣性で止まる。
;     送信単位は S_STEP（既定 1）で、高解像度ホイール対応アプリでは連続的に動く。
;     上下と左右の同時押しで斜めスクロール。
; (9) 押下キーの自動判定（2026/09/29 追加）
;     「離したら止まる」の判定に使う物理キーを、呼び出し元のホットキー名
;     （A_ThisHotkey）から自動で取得する。
;     例：「vk20 & i」から呼ぶと、i と vk20 のどちらかを離した時点で止まる。
;     これにより、同じ関数を複数のレイヤー（vk1D、vk20 など）から呼べる。
;     ホットキー名から取得できない場合（InputHook 経由など）は Keys の設定を使う。
; (10) スクロール中の誤入力防止（2026/09/30 作り直し）
;     スクロールに使ったキーに「条件なし」の握りつぶし用ホットキー
;     （例 "*i"、何もしない）を一時的に有効化する。
;     解除は「スクロールが完全に停止」かつ「そのキーを離した」時点。
; (11) プレーン版の追加（2026/09/30 追加）
;     気分で使い分けられるよう、以前のシンプルな動作を MousePlain_* として復活させた。
;     ・MousePlain_Scroll*     … 1 回押すごとにホイール 1 ノッチ（旧 SendInput("{WheelUp 1}") 相当）
;     ・MousePlain_Left 等     … 1 回押すごとに固定量ジャンプ、キーリピート中は加速（旧 MoveCursorTo*2 相当）
;     ・MousePlain_*Minimal    … 1 回押すごとに小さい固定量、加速なし（旧 MoveCursorTo*Minimal2 相当）
;     どちらもキーリピート駆動（押しっぱなしで OS のリピートにより連続動作）。
;     設定値は class MousePlain の冒頭で変更できる。
; (12) MousePlain の移動量を解像度に連動（2026/09/30 追加）
;     高精細なディスプレイ（Surface 等）では、同じ px 数でも体感の移動量が小さくなる。
;     そこで、カーソルのあるモニターの画素数（対角線の長さ）に比例して移動量を拡大する。
;       倍率 = √(幅² + 高さ²) ÷ √(BASE_W² + BASE_H²)
;     基準は 1920×1080 で、このとき MOVE_PX（200px）そのまま。
;     縦横に同じ倍率を掛けるため、上下と左右の移動量は常に等しい。
;     SCALE_BY_MONITOR := false で固定値に戻せる。
;
; 【前提】
; ・方向キーの「押下時」に MouseNav_Left() 等を呼ぶ。キーリピートで何度呼ばれても問題ない。
;   停止は物理キーを離したことを検知して自動で行うので、キーを離したときの処理は不要。
; ・通常のホットキー（例「vk1D & f::」）から呼ぶ場合、Keys の設定は不要。
;
; 【調整ポイント：カーソル移動】
; V_START   … 押し始めの速度。短く押したときの移動量に効く。
; V_MAX     … 押し続けたときの最高速度。
; RAMP_MS   … 最高速度に達するまでの時間。短いほどすぐ速くなる。
; CURVE     … 加速の立ち上がり方。大きいほど出だしが穏やかで、後半に一気に加速する。
; V_SLOW    … 精密モードの速度（加速なし）。
;
; 【調整ポイント：スクロール】（1 ノッチ = ホイール 1 段 = 120）
; S_TAP     … 押した瞬間に送り出す量。短押し 1 回の移動量の大部分を決める（0 で無効）。
; S_TAP_MS  … S_TAP を送り切るまでの時間。短いほどキビキビ（0 で瞬時）。
; S_START   … 連続スクロールの押し始めの速度 [ノッチ/s]。
; S_MAX     … 押し続けたときの最高速度 [ノッチ/s]。
; S_RAMP_MS … 最高速度に達するまでの時間。
; S_CURVE   … 加速の立ち上がり方（CURVE と同じ考え方）。
; S_EASE_MS … 連続スクロールの追従時間。大きいほどふわっと動き出す（0 で即時）。
; S_GLIDE_MS… 離した後の慣性の長さ（0 で即停止）。
; S_STEP    … 1 回に送る最小単位。小さいほど滑らか。
; ※実際の移動量は Windows の設定「一度にスクロールする行数」にも比例する。
;
; 【スクロールのプリセット】
;   キビキビ（既定）   : S_TAP 120 / S_TAP_MS 45 / S_EASE_MS 20 / S_GLIDE_MS 45  / S_STEP 1
;   なめらか（旧既定） : S_TAP 0   / S_TAP_MS 0  / S_EASE_MS 60 / S_GLIDE_MS 100 / S_STEP 1
;   ホイール再現       : S_TAP 120 / S_TAP_MS 0  / S_EASE_MS 0  / S_GLIDE_MS 0   / S_STEP 120
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\text_input.ahk


class MouseNav {
    ;--- 設定 -----------------------------------------------------------------
    ; 押下キーの予備設定。
    ; 通常のホットキーから呼ぶ場合は自動判定されるため使われない。
    ; InputHook 経由など、ホットキー名からキーを判定できない場合にだけ使う。
    static Keys := Map(
        "Left",        "a",
        "Down",        "d",
        "Up",          "s",
        "Right",       "f",
        "ScrollUp",    "w",
        "ScrollDown",  "e",
        "ScrollLeft",  "q",
        "ScrollRight", "r")

    static TICK_MS        := 8     ; 更新周期 [ms]

    ; カーソル移動
    static V_START        := 3000  ; 押し始めの速度 [px/s]
    static V_MAX          := 8000  ; 最高速度 [px/s]
    static RAMP_MS        := 150   ; V_MAX に達するまでの時間 [ms]
    static CURVE          := 1.0   ; 加速カーブ（1 = 直線）
    static V_SLOW         := 120   ; 精密モードの速度 [px/s]
    static FAST_MULT      := 2.5   ; 高速モードの倍率
    static NUDGE_PX       := 1     ; Nudge の移動量 [px]
    static BISECT_TIMEOUT := 1500  ; Bisect を連続操作とみなす間隔 [ms]

    ; スクロール
    static S_TAP          := 120   ; 押した瞬間に送り出す量（120 = 1 ノッチ、0 で無効）
    static S_TAP_MS       := 45    ; S_TAP を送り切るまでの時間 [ms]（0 で瞬時）
    static S_START        := 12    ; 連続スクロールの押し始めの速度 [ノッチ/s]
    static S_MAX          := 40    ; 最高速度 [ノッチ/s]
    static S_RAMP_MS      := 500   ; S_MAX に達するまでの時間 [ms]
    static S_CURVE        := 1.5   ; 加速カーブ（1 = 直線）
    static S_EASE_MS      := 20    ; 連続スクロールの追従時間 [ms]（0 で即時）
    static S_GLIDE_MS     := 45    ; 離した後の慣性時間 [ms]（0 で即停止）
    static S_STEP         := 1     ; 1 回に送る最小単位（120 = ホイール 1 ノッチ）
    static S_BLOCK_KEYS   := true  ; スクロール中の誤入力防止（false で無効）

    ;--- 内部状態 -------------------------------------------------------------
    ; 各 Map の値は「押し続けているべき物理キーの配列」（例 ["i", "vk20"]）
    static _held  := Map()  ; 押下中の移動方向
    static _mods  := Map()  ; 押下中のモード（Slow/Fast）
    static _sHeld := Map()  ; 押下中のスクロール方向
    static _startT := 0, _lastT := 0, _fx := 0.0, _fy := 0.0
    static _sRun := false, _sTimerOn := false, _sStartT := 0, _sLastT := 0
    static _sVX := 0.0, _sVY := 0.0, _sAccX := 0.0, _sAccY := 0.0
    static _sImpX := 0.0, _sImpY := 0.0     ; タップ量の未送信分
    static _blocked := Map() ; 入力を握りつぶし中のキー（※メソッド _Block と別名にすること）

    ; AutoHotkey 自身が Send したイベントに付ける識別値（KEY_IGNORE）。
    ; これを付けて送ると、自分のスクロールで「vk1D & WheelUp」等のホットキーが誤発動しない。
    static _AHK_IGNORE := 0xFFC3D44F

    ;--- 初期化（初回アクセス時に自動実行）-------------------------------------
    static __New() {
        DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
        DllCall("winmm\timeBeginPeriod", "UInt", 1)             ; タイマー分解能を 1ms に
        OnExit((*) => (DllCall("winmm\timeEndPeriod", "UInt", 1), 0))

        hU := DllCall("GetModuleHandle", "Str", "user32", "Ptr")
        hK := DllCall("GetModuleHandle", "Str", "kernel32", "Ptr")
        this._pGet  := DllCall("GetProcAddress", "Ptr", hU, "AStr", "GetCursorPos", "Ptr")
        this._pSet  := DllCall("GetProcAddress", "Ptr", hU, "AStr", "SetCursorPos", "Ptr")
        this._pSend := DllCall("GetProcAddress", "Ptr", hU, "AStr", "SendInput", "Ptr")
        this._pQpc  := DllCall("GetProcAddress", "Ptr", hK, "AStr", "QueryPerformanceCounter", "Ptr")
        DllCall("QueryPerformanceFrequency", "Int64*", &f := 0)
        this._msPerCount := 1000 / f

        this._pt  := Buffer(8, 0)
        this._qpc := Buffer(8, 0)

        ; SendInput 用の INPUT 構造体（マウス）を 1 つ確保して使い回す
        x64 := (A_PtrSize = 8)
        this._inSize   := x64 ? 40 : 28
        this._offData  := x64 ? 16 : 12                         ; MOUSEINPUT.mouseData
        this._offFlags := x64 ? 20 : 16                         ; MOUSEINPUT.dwFlags
        this._in := Buffer(this._inSize, 0)                     ; type = 0（INPUT_MOUSE）
        NumPut("UPtr", this._AHK_IGNORE, this._in, x64 ? 32 : 24) ; dwExtraInfo

        ; ※タイマー用の変数名はメソッド名と別にすること（大文字小文字を区別しないため衝突する）
        this._timerFn  := ObjBindMethod(this, "_Tick")
        this._scrollFn := ObjBindMethod(this, "_ScrollTick")
        this._noop     := (*) => 0                              ; 誤入力防止ホットキーの処理（何もしない）
        InstallKeybdHook()                                      ; 物理キー状態の取得に必要
    }

    ;=== 公開メソッド ===========================================================

    ; 連続移動（dir: "Left"/"Right"/"Up"/"Down"）、モード（dir: "Slow"/"Fast"）
    ; key を省略すると、呼び出し元のホットキーから自動判定する
    static Hold(dir, key := "") {
        if !(keys := this._ResolveKeys(dir, key))
            return
        if (dir = "Slow" || dir = "Fast") {
            this._mods[dir] := keys
            return
        }
        if !this._held.Count {                                  ; 停止状態から開始
            this._startT := this._lastT := this._Now()
            this._fx := 0.0, this._fy := 0.0
            SetTimer(this._timerFn, this.TICK_MS)
        }
        this._held[dir] := keys
    }

    ; スムーズスクロール（dir: "ScrollUp"/"ScrollDown"/"ScrollLeft"/"ScrollRight"）
    ; key を省略すると、呼び出し元のホットキーから自動判定する
    static Scroll(dir, key := "") {
        if this._sHeld.Has(dir)                                 ; キーリピートによる再呼び出し
            return
        if !(keys := this._ResolveKeys(dir, key))
            return

        ; 最初にキー入力を止める（以降のキーリピートが文字として入力されないように）
        if this.S_BLOCK_KEYS
            this._Block(keys[1])

        now := this._Now()
        if !this._sHeld.Count                                   ; 押し始め（慣性中の再押下を含む）
            this._sStartT := now
        if !this._sRun {                                        ; 停止状態から開始
            this._sRun := true
            this._sLastT := now
            this._sVX := 0.0, this._sVY := 0.0
            this._sAccX := 0.0, this._sAccY := 0.0
            this._sImpX := 0.0, this._sImpY := 0.0
        }
        this._sHeld[dir] := keys

        ; タップ量を追加（押した瞬間から送り出す）
        switch dir {
            case "ScrollUp":    this._sImpY += this.S_TAP
            case "ScrollDown":  this._sImpY -= this.S_TAP
            case "ScrollRight": this._sImpX += this.S_TAP
            case "ScrollLeft":  this._sImpX -= this.S_TAP
        }

        if !this._sTimerOn {
            this._sTimerOn := true
            SetTimer(this._scrollFn, this.TICK_MS)
        }
        this._ScrollTick()                                      ; 次の周期を待たずに即反映
    }

    ; 強制停止（移動・スクロールとも）
    static Stop() {
        SetTimer(this._timerFn, 0)
        SetTimer(this._scrollFn, 0)
        this._held.Clear()
        this._sHeld.Clear()
        for k in this._blocked.Clone()
            this._Unblock(k)
        this._sRun := false, this._sTimerOn := false
        this._sVX := 0.0, this._sVY := 0.0
        this._sImpX := 0.0, this._sImpY := 0.0
    }

    ; 固定量の微小移動（ピクセル単位の位置合わせ用）
    static Nudge(dir, px := 0) {
        px := px || this.NUDGE_PX
        v := this._Vec(dir)
        this._MoveBy(v[1] * px, v[2] * px)
    }

    ; 2 分割ジャンプ
    static Bisect(dir) {
        static r := 0, last := 0
        this._GetPos(&x, &y)
        ; 時間が空いた／カーソルが他の手段で動かされた場合は、モニター全体から再開
        if (!r || A_TickCount - last > this.BISECT_TIMEOUT || x != r.cx || y != r.cy)
            r := this._MonitorRect(x, y)
        switch dir {
            case "Left":  r.R := (r.L + r.R) // 2
            case "Right": r.L := (r.L + r.R) // 2
            case "Up":    r.B := (r.T + r.B) // 2
            case "Down":  r.T := (r.T + r.B) // 2
        }
        r.cx := (r.L + r.R) // 2, r.cy := (r.T + r.B) // 2
        DllCall(this._pSet, "Int", r.cx, "Int", r.cy, "Int")
        last := A_TickCount
    }

    ; アクティブウィンドウの中央へ移動
    ; 対象となるウィンドウがない場合（デスクトップ、タスクバー、最小化中など）は、
    ; カーソルのあるモニターの中央へ移動する
    static WarpToActiveWindow() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if this._IsWarpTarget(hwnd) {
            rc := Buffer(16, 0)
            ; 見えない枠（影）を除いた実際の見た目の範囲を使う（DWMWA_EXTENDED_FRAME_BOUNDS）
            if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rc, "UInt", 16)
                DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
            cx := (NumGet(rc, 0, "Int") + NumGet(rc, 8, "Int")) // 2
            cy := (NumGet(rc, 4, "Int") + NumGet(rc, 12, "Int")) // 2
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

    ; カーソルのあるモニターの四隅へ移動（corner: "TL"=左上 / "TR"=右上 / "BL"=左下 / "BR"=右下）
    static WarpToCorner(corner) {
        this._GetPos(&x, &y)
        r := this._MonitorRect(x, y)
        nx := SubStr(corner, 2, 1) = "R" ? r.R - 1 : r.L
        ny := SubStr(corner, 1, 1) = "B" ? r.B - 1 : r.T
        DllCall(this._pSet, "Int", nx, "Int", ny, "Int")
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
    static WarpToExternalCenter() {
        mons := this._ExternalMonitors()
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

    ; 押し続けているべき物理キーの配列を決める
    ; 優先順：引数 key → 呼び出し元ホットキー名 → Keys の予備設定
    static _ResolveKeys(dir, key) {
        if (key != "")
            return [key]
        if (keys := this._KeysFromHotkey())
            return keys
        if this.Keys.Has(dir)
            return [this.Keys[dir]]
        return ""
    }

    ; A_ThisHotkey（例 "vk20 & i"、"~*F13"）から物理キー名を取り出す
    ; 取り出したキーが実際に押されていない場合（InputHook 経由など）は "" を返す
    static _KeysFromHotkey() {
        hk := RegExReplace(A_ThisHotkey, "i)\s+up$")
        if RegExMatch(hk, "^(.+?)\s+&\s+(.+)$", &m)
            keys := [m[2], m[1]]
        else
            keys := [hk]
        for i, k in keys
            keys[i] := RegExReplace(k, "^[~*$!^+#<>]+(?=.)")    ; 修飾記号を除去（"+" 単体は残す）
        try {
            for k in keys
                if !GetKeyState(k, "P")
                    return ""
        } catch
            return ""
        return keys
    }

    ; 配列内のキーがすべて押されているか
    static _AllDown(keys) {
        for k in keys
            if !GetKeyState(k, "P")
                return false
        return true
    }

    ;--- 誤入力防止 -------------------------------------------------------------
    ; key の入力を止める：条件なし（HotIf なし）の "*key" ホットキーを有効化する。
    static _Block(key) {
        if this._blocked.Has(key)
            return
        try {
            HotIf()                                             ; 条件なしで登録
            Hotkey("*" key, this._noop, "On")
            this._blocked[key] := true
        }
    }

    ; key の入力停止を解除する
    static _Unblock(key) {
        try {
            HotIf()
            Hotkey("*" key, "Off")
        }
        this._blocked.Delete(key)
    }

    ; カーソル移動のタイマー処理
    static _Tick() {
        Critical                                                ; 途中で割り込まれないようにする

        ; 離されたキーを除外
        for dir, keys in this._held.Clone()
            if !this._AllDown(keys)
                this._held.Delete(dir)
        if !this._held.Count {
            SetTimer(this._timerFn, 0)
            return
        }

        now := this._Now()
        dt  := Min(now - this._lastT, 50) / 1000                ; [s]（処理落ち時の飛びを抑制）
        this._lastT := now

        ; 方向ベクトル（逆方向の同時押しは相殺）
        ux := this._held.Has("Right") - this._held.Has("Left")
        uy := this._held.Has("Down")  - this._held.Has("Up")
        if !(ux || uy)
            return
        if (ux && uy)
            ux *= 0.7071, uy *= 0.7071

        ; 速度
        if this._ModDown("Slow") {
            v := this.V_SLOW
            this._startT := now                                 ; 精密モード解除後は低速から再加速
        } else {
            p := Min((now - this._startT) / this.RAMP_MS, 1.0)
            v := this.V_START + (this.V_MAX - this.V_START) * p ** this.CURVE
            if this._ModDown("Fast")
                v *= this.FAST_MULT
        }

        ; 端数を持ち越しつつ移動
        this._fx += ux * v * dt
        this._fy += uy * v * dt
        ix := Integer(this._fx), iy := Integer(this._fy)
        if (ix || iy) {
            this._fx -= ix, this._fy -= iy
            this._MoveBy(ix, iy)
        }
    }

    ; スクロールのタイマー処理
    ; ・タップ量（_sImpX/_sImpY）を S_TAP_MS で送り出す（減速カーブ）
    ; ・連続スクロールの速度（_sVX/_sVY）を目標速度へ追従させ、その積分量を送る
    ; ・停止後も、入力を止めているキーが離されるまでタイマーを維持する
    static _ScrollTick() {
        Critical

        if this._sRun {
            for dir, keys in this._sHeld.Clone()
                if !this._AllDown(keys)
                    this._sHeld.Delete(dir)

            now := this._Now()
            dt  := Min(now - this._sLastT, 50) / 1000
            this._sLastT := now

            ; 目標速度 [delta/s]（上・右が正。逆方向の同時押しは相殺）
            sy := this._sHeld.Has("ScrollUp")    - this._sHeld.Has("ScrollDown")
            sx := this._sHeld.Has("ScrollRight") - this._sHeld.Has("ScrollLeft")
            vt := 0.0
            if (sx || sy) {
                p  := Min((now - this._sStartT) / this.S_RAMP_MS, 1.0)
                vt := (this.S_START + (this.S_MAX - this.S_START) * p ** this.S_CURVE) * 120
            }

            ; 連続スクロール分
            oy := this._sVY, ox := this._sVX
            this._sVY := this._Follow(oy, sy * vt, dt)
            this._sVX := this._Follow(ox, sx * vt, dt)
            this._sAccY += (oy + this._sVY) / 2 * dt
            this._sAccX += (ox + this._sVX) / 2 * dt

            ; タップ分（残量の一定割合を送る → 最初に多く、だんだん少なく）
            k := (this.S_TAP_MS <= 0) ? 1.0 : 1 - Exp(-dt * 1000 * 3 / this.S_TAP_MS)
            for axis in ["Y", "X"] {
                rem := this._sImp%axis%
                out := (Abs(rem) < 2) ? rem : rem * k
                this._sImp%axis% := rem - out
                this._sAcc%axis% += out
            }

            ; S_STEP 単位で送る（端数は持ち越し）
            step := Max(this.S_STEP, 1)
            if (n := Integer(this._sAccY / step)) {
                this._sAccY -= n * step
                this._SendWheel(n * step, false)
            }
            if (n := Integer(this._sAccX / step)) {
                this._sAccX -= n * step
                this._SendWheel(n * step, true)
            }

            ; まだ動いているなら継続
            if (this._sHeld.Count || Abs(this._sVX) >= 20 || Abs(this._sVY) >= 20
                || this._sImpX != 0 || this._sImpY != 0)
                return

            ; 完全停止
            this._sRun := false
            this._sVX := 0.0, this._sVY := 0.0
        }

        ; 停止後：離されたキーから入力停止を解除し、全て解除されたらタイマー終了
        for k in this._blocked.Clone()
            if !GetKeyState(k, "P")
                this._Unblock(k)
        if !this._blocked.Count {
            SetTimer(this._scrollFn, 0)
            this._sTimerOn := false
        }
    }

    ; 現在速度 v を目標 target へ 1 周期ぶん近づける
    static _Follow(v, target, dt) {
        ; 目標の絶対値が現在より大きい（加速）なら EASE、小さい（減速・反転）なら GLIDE
        tau := (Abs(target) > Abs(v) && (target * v >= 0)) ? this.S_EASE_MS : this.S_GLIDE_MS
        if (tau <= 0)
            return target
        return v + (target - v) * (1 - Exp(-dt * 1000 / tau))
    }

    ; ホイールイベントを送る（delta：正 = 上／右、horizontal：true で横スクロール）
    static _SendWheel(delta, horizontal) {
        NumPut("Int",  delta,                            this._in, this._offData)
        NumPut("UInt", horizontal ? 0x1000 : 0x0800,     this._in, this._offFlags) ; HWHEEL / WHEEL
        DllCall(this._pSend, "UInt", 1, "Ptr", this._in, "Int", this._inSize, "UInt")
    }

    static _ModDown(name) {
        if !this._mods.Has(name)
            return false
        if this._AllDown(this._mods[name])
            return true
        this._mods.Delete(name)
        return false
    }

    static _Now() {
        DllCall(this._pQpc, "Ptr", this._qpc, "Int")
        return NumGet(this._qpc, 0, "Int64") * this._msPerCount
    }

    static _GetPos(&x, &y) {
        DllCall(this._pGet, "Ptr", this._pt, "Int")
        x := NumGet(this._pt, 0, "Int"), y := NumGet(this._pt, 4, "Int")
    }

    static _MoveBy(dx, dy) {
        this._GetPos(&x, &y)
        DllCall(this._pSet, "Int", x + dx, "Int", y + dy, "Int")
    }

    ; ワープ先として有効な通常ウィンドウかを判定する
    static _IsWarpTarget(hwnd) {
        if (!hwnd
            || !DllCall("IsWindowVisible", "Ptr", hwnd)
            || DllCall("IsIconic", "Ptr", hwnd))                ; 最小化中
            return false
        cls := Buffer(512, 0)
        DllCall("GetClassName", "Ptr", hwnd, "Ptr", cls, "Int", 256)
        switch StrGet(cls) {
            case "Progman", "WorkerW":                          ; デスクトップ
                return false
            case "Shell_TrayWnd", "Shell_SecondaryTrayWnd":     ; タスクバー
                return false
        }
        return true
    }

    static _Vec(dir) => dir = "Left" ? [-1, 0] : dir = "Right" ? [1, 0] : dir = "Up" ? [0, -1] : [0, 1]

    ; カーソルのあるモニターの矩形（タスクバー含む全体）
    static _MonitorRect(x, y) {
        hMon := DllCall("MonitorFromPoint", "Int64", (y << 32) | (x & 0xFFFFFFFF), "UInt", 2, "Ptr")
        mi := Buffer(40, 0), NumPut("UInt", 40, mi)
        DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
        return {L: NumGet(mi, 4, "Int"), T: NumGet(mi, 8, "Int")
              , R: NumGet(mi, 12, "Int"), B: NumGet(mi, 16, "Int")}
    }

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
; ・Minimal     ：1 回押すごとに MOVE_MIN_PX、加速なし。（旧 MoveCursorTo*Minimal2）
; ・スクロール  ：1 回押すごとにホイール SCROLL_NOTCH ノッチ。（旧 SendInput("{WheelUp 1}")）
; ・移動量はカーソルのあるモニターの画素数に比例して拡大する（SCALE_BY_MONITOR）。
;   MOVE_PX / MOVE_MIN_PX は「BASE_W×BASE_H のモニターでの移動量」として指定する。
; ※ MouseNav と違い、キーを離したことの検知やタイマーは使わない。
;==============================================================================
class MousePlain {
    ;--- 設定 -----------------------------------------------------------------
    static MOVE_PX          := 200   ; 1 回の移動量 [px]（BASE_W×BASE_H での値）
    static MOVE_MIN_PX      := 30    ; Minimal の移動量 [px]（BASE_W×BASE_H での値）
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
;--- MouseNav（タイマー駆動・なめらか）-----------------------------------------
; 連続移動（押している間だけ動く）
MouseNav_Left()              => MouseNav.Hold("Left")
MouseNav_Right()             => MouseNav.Hold("Right")
MouseNav_Up()                => MouseNav.Hold("Up")
MouseNav_Down()              => MouseNav.Hold("Down")
; モード（移動中に押している間だけ有効）
MouseNav_Slow()              => MouseNav.Hold("Slow")
MouseNav_Fast()              => MouseNav.Hold("Fast")
; スムーズスクロール（押している間だけ加速しながらスクロール）
MouseNav_ScrollUp()          => MouseNav.Scroll("ScrollUp")
MouseNav_ScrollDown()        => MouseNav.Scroll("ScrollDown")
MouseNav_ScrollLeft()        => MouseNav.Scroll("ScrollLeft")
MouseNav_ScrollRight()       => MouseNav.Scroll("ScrollRight")
; 微小移動（1 回押すごとに NUDGE_PX 移動）
MouseNav_NudgeLeft()         => MouseNav.Nudge("Left")
MouseNav_NudgeRight()        => MouseNav.Nudge("Right")
MouseNav_NudgeUp()           => MouseNav.Nudge("Up")
MouseNav_NudgeDown()         => MouseNav.Nudge("Down")
; 2 分割ジャンプ
MouseNav_JumpLeft()          => MouseNav.Bisect("Left")
MouseNav_JumpRight()         => MouseNav.Bisect("Right")
MouseNav_JumpUp()            => MouseNav.Bisect("Up")
MouseNav_JumpDown()          => MouseNav.Bisect("Down")
; ワープ
MouseNav_WarpWindow()        => MouseNav.WarpToActiveWindow()
MouseNav_WarpCenter()        => MouseNav.WarpToMonitorCenter()
MouseNav_WarpMonitor()       => MouseNav.WarpToNextMonitor()
MouseNav_WarpMonitorCenter() => MouseNav.WarpToNextMonitor(true)
MouseNav_WarpExternalCenter() {
    MouseNav.WarpToExternalCenter()
    Mouse_FocusUnderCursor()
}
; 四隅（カーソルのあるモニター）
MouseNav_CornerTopLeft()     => MouseNav.WarpToCorner("TL")
MouseNav_CornerTopRight()    => MouseNav.WarpToCorner("TR")
MouseNav_CornerBottomLeft()  => MouseNav.WarpToCorner("BL")
MouseNav_CornerBottomRight() => MouseNav.WarpToCorner("BR")
; 強制停止
MouseNav_Stop()              => MouseNav.Stop()

;--- MousePlain（キーリピート駆動・シンプル）-----------------------------------
; カーソル移動（1 回押すごとに固定量、押しっぱなしで加速）
MousePlain_Left()            => MousePlain.Move(-MousePlain.MOVE_PX, 0)
MousePlain_Right()           => MousePlain.Move( MousePlain.MOVE_PX, 0)
MousePlain_Up()              => MousePlain.Move(0, -MousePlain.MOVE_PX)
MousePlain_Down()            => MousePlain.Move(0,  MousePlain.MOVE_PX)
; カーソル移動・小（1 回押すごとに小さい固定量、加速なし）
MousePlain_LeftMinimal()     => MousePlain.Move(-MousePlain.MOVE_MIN_PX, 0, false)
MousePlain_RightMinimal()    => MousePlain.Move( MousePlain.MOVE_MIN_PX, 0, false)
MousePlain_UpMinimal()       => MousePlain.Move(0, -MousePlain.MOVE_MIN_PX, false)
MousePlain_DownMinimal()     => MousePlain.Move(0,  MousePlain.MOVE_MIN_PX, false)
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

; 左ボタンの押しっぱなし／解除を切り替える（ドラッグ用）。ドラッグ中は Esc でキャンセル
Mouse_dragging := false

Mouse_ToggleDrag() {
    global Mouse_dragging
    if Mouse_dragging {
        Click("Up")
        Mouse_dragging := false
        ToolTip("Released")
    } else {
        Click("Down")
        Mouse_dragging := true
        ToolTip("Holding")
    }
    SetTimer(() => ToolTip(), -3000)
}

Mouse_IsDragging() => Mouse_dragging

Mouse_CancelDrag() {
    global Mouse_dragging
    Click("Up")
    Mouse_dragging := false
    ToolTip("Canceled")
    SetTimer(() => ToolTip(), -2000)
}

#HotIf Mouse_IsDragging() && !isWaitingInput
Esc:: Mouse_CancelDrag()
#HotIf
