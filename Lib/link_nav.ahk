#Requires AutoHotkey v2.0
;==============================================================================
; link_nav.ahk
; LinkNav : アクティブウィンドウ上のリンクへ、順番にマウスカーソルを移動する
;------------------------------------------------------------------------------
; 【重要メモ】
; 正常動作を一度も確認できていません。一応残しておきます。
; 【仕組み】
;   Windows の UI Automation（UIA）で、アクティブウィンドウ内の
;   「ハイパーリンク」要素の一覧と位置を取得し、読む順（上→下、左→右）に並べる。
;   LinkNav_Next() を呼ぶたびに、次のリンクの中心へカーソルを移動する。
;   移動先のリンク名と「3/25」のような番号をツールチップで表示する。
;
; 【一覧を取り直すタイミング】
;   次のどれかに当てはまると、呼び出し時に自動で取り直す。
;     ・アクティブウィンドウが変わった
;     ・前回の操作から RESCAN_MS 以上たった（スクロールしたときなど）
;     ・カーソルがほかの手段（マウス・トラックポイント等）で動かされた
;   取り直したときは、今のカーソル位置の次のリンクから始める。
;
; 【対応アプリ】
;   UIA に対応したアプリ：Edge、Chrome、Firefox、エクスプローラー、Office など。
;   ・Chrome 系は、初回だけリンクが見つからないことがある（UIA の有効化待ち）。
;     その場合は自動で 1 回だけ取り直す。それでも見つからなければもう一度押す。
;   ・64bit 版の AutoHotkey 専用（Windows on Arm でも x64 版で動作）。
;
; 【呼び出し用の関数】
;   LinkNav_Next()   … 次のリンクへ
;   LinkNav_Prev()   … 前のリンクへ
;   LinkNav_Rescan() … 一覧を取り直して、カーソル位置の次のリンクへ
;==============================================================================

class LinkNav {
    ;--- 設定 -----------------------------------------------------------------
    static INCLUDE_BUTTONS := false  ; true でボタンも対象にする
    static RESCAN_MS       := 3000   ; この時間操作がなければ一覧を取り直す [ms]
    static TIP_MS          := 1500   ; ツールチップの表示時間 [ms]

    ;--- 内部状態 -------------------------------------------------------------
    static _uiaObj := 0   ; ※メソッド _UIA と別名にすること（大文字小文字を区別しないため衝突する）
    static _list := [], _idx := 0, _hwnd := 0, _lastT := 0, _lastX := 0, _lastY := 0

    ;=== 公開メソッド ===========================================================
    static Step(d, forceRescan := false) {
        if (A_PtrSize != 8) {
            this._Tip("64bit 版の AutoHotkey が必要です")
            return
        }
        DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
        hwnd := WinExist("A")
        if !hwnd
            return
        this._CursorPos(&cx, &cy)

        if (forceRescan || hwnd != this._hwnd || !this._list.Length
            || A_TickCount - this._lastT > this.RESCAN_MS
            || cx != this._lastX || cy != this._lastY) {
            try this._list := this._Scan(hwnd)
            catch as e {
                this._Tip("リンクを取得できませんでした：" e.Message)
                return
            }
            if !this._list.Length {                              ; Chrome 系の初回対策
                Sleep(300)
                try this._list := this._Scan(hwnd)
            }
            this._hwnd := hwnd
            if !this._list.Length {
                this._lastT := 0
                this._Tip("リンクが見つかりません")
                return
            }
            this._idx := this._StartIndex(cx, cy, d)
        } else {
            n := this._list.Length
            this._idx := Mod(this._idx - 1 + d + n, n) + 1       ; 端まで行くと反対側へ
        }

        it := this._list[this._idx]
        DllCall("SetCursorPos", "Int", it.x, "Int", it.y)
        this._lastX := it.x, this._lastY := it.y, this._lastT := A_TickCount
        name := StrLen(it.name) > 40 ? SubStr(it.name, 1, 40) "…" : it.name
        this._Tip(this._idx "/" this._list.Length "  " name, it.x + 16, it.y + 16)
    }

    ;=== 内部処理 ===============================================================

    ; UIA オブジェクト（CUIAutomation / IUIAutomation）
    static _UIA() {
        if !this._uiaObj
            this._uiaObj := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}"
                , "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        return this._uiaObj
    }

    ; 「プロパティ = 整数値」の条件を作る
    static _IntCond(uia, propId, val, vt := 3) {
        v := Buffer(24, 0)                                       ; VARIANT
        NumPut("UShort", vt, v, 0)
        NumPut("Int", val, v, 8)
        ComCall(23, uia, "Int", propId, "Ptr", v, "Ptr*", &cond := 0)   ; CreatePropertyCondition
        return cond
    }

    ; リンクの一覧を取得し、読む順に並べて返す
    static _Scan(hwnd) {
        uia := this._UIA()
        root := cond := cr := arr := 0
        list := []
        try {
            ComCall(6, uia, "Ptr", hwnd, "Ptr*", &root)          ; ElementFromHandle

            ; 条件：種類がハイパーリンク（とボタン）かつ、画面外でない
            cond := this._IntCond(uia, 30003, 50005)            ; ControlType = Hyperlink
            if this.INCLUDE_BUTTONS {
                c2 := this._IntCond(uia, 30003, 50000)          ; ControlType = Button
                ComCall(28, uia, "Ptr", cond, "Ptr", c2, "Ptr*", &c3 := 0)   ; CreateOrCondition
                ObjRelease(cond), ObjRelease(c2), cond := c3
            }
            off := this._IntCond(uia, 30022, 0, 11)             ; IsOffscreen = false（VT_BOOL）
            ComCall(25, uia, "Ptr", cond, "Ptr", off, "Ptr*", &c4 := 0)      ; CreateAndCondition
            ObjRelease(cond), ObjRelease(off), cond := c4

            ; 位置と名前をまとめて取得する（1 件ずつ問い合わせるより速い）
            ComCall(20, uia, "Ptr*", &cr)                        ; CreateCacheRequest
            ComCall(3, cr, "Int", 30001)                         ; BoundingRectangle
            ComCall(3, cr, "Int", 30005)                         ; Name
            ComCall(8, root, "Int", 4, "Ptr", cond, "Ptr", cr, "Ptr*", &arr)  ; FindAllBuildCache（子孫すべて）

            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            this._PhysRect(hwnd, &wx, &wy, &ww, &wh)
            seen := Map(), rc := Buffer(16, 0)
            ComCall(3, arr, "Int*", &n := 0)                     ; get_Length
            loop n {
                ComCall(4, arr, "Int", A_Index - 1, "Ptr*", &el := 0)        ; GetElement
                try {
                    ComCall(67, el, "Ptr", rc)                   ; get_CachedBoundingRectangle
                    l := NumGet(rc, 0, "Int"), t := NumGet(rc, 4, "Int")
                    r := NumGet(rc, 8, "Int"), b := NumGet(rc, 12, "Int")
                    x := (l + r) // 2, y := (t + b) // 2
                    if (r - l > 0 && b - t > 0 && x >= wx && x < wx + ww && y >= wy && y < wy + wh
                        && !seen.Has(x "," y)) {
                        seen[x "," y] := true
                        name := ""
                        if (ComCall(47, el, "Ptr*", &bs := 0) >= 0 && bs) {    ; get_CachedName
                            name := StrGet(bs, "UTF-16")
                            DllCall("OleAut32\SysFreeString", "Ptr", bs)
                        }
                        list.Push({x: x, y: y, top: t, left: l, name: Trim(RegExReplace(name, "\s+", " "))})
                    }
                }
                ObjRelease(el)
            }
        } finally {
            for p in [arr, cr, cond, root]
                if p
                    ObjRelease(p)
        }
        return this._SortReading(list)
    }

    ; 上→下、同じ高さなら左→右 に並べる
    static _SortReading(list) {
        if (list.Length < 2)
            return list
        s := ""
        for i, it in list
            s .= Format("{:08}|{:08}|{}`n", it.top + 50000, it.left + 50000, i)
        out := []
        loop parse Sort(RTrim(s, "`n")), "`n"
            out.Push(list[Integer(StrSplit(A_LoopField, "|")[3])])
        return out
    }

    ; カーソル位置から見た最初のリンク（d > 0：次、d < 0：前）
    static _StartIndex(cx, cy, d) {
        n := this._list.Length
        if (d > 0) {
            for i, it in this._list
                if (it.y > cy + 4 || (Abs(it.y - cy) <= 4 && it.x > cx))
                    return i
            return 1
        }
        loop n {
            i := n - A_Index + 1, it := this._list[i]
            if (it.y < cy - 4 || (Abs(it.y - cy) <= 4 && it.x < cx))
                return i
        }
        return n
    }

    static _CursorPos(&x, &y) {
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", pt)
        x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
    }

    ; ウィンドウの矩形を物理ピクセルで取得する（UIA の座標と合わせるため）
    static _PhysRect(hwnd, &x, &y, &w, &h) {
        rc := Buffer(16, 0)
        if DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc) {
            x := NumGet(rc, 0, "Int"), y := NumGet(rc, 4, "Int")
            w := NumGet(rc, 8, "Int") - x, h := NumGet(rc, 12, "Int") - y
        }
    }

    static _Tip(msg, x?, y?) {
        CoordMode("ToolTip", "Screen")
        ToolTip(msg, x?, y?, 19)
        SetTimer(() => ToolTip(, , , 19), -this.TIP_MS)
    }
}

;==============================================================================
; 呼び出し用ラッパー
;==============================================================================
LinkNav_Next()   => LinkNav.Step(1)
LinkNav_Prev()   => LinkNav.Step(-1)
LinkNav_Rescan() => LinkNav.Step(1, true)
