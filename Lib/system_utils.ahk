#Requires AutoHotkey v2.0
;==============================================================================
; system_utils.ahk
; OS・ウィンドウ操作の補助（アプリ起動・アプリ切り替え・モニター移動・最前面固定・スクリーンセーバー回避）
;   旧 os_operate_assist.ahk / screen_saver.ahk を統合
;   （launch_execute.ahk は os_operate_assist.ahk と重複していたため削除）
;==============================================================================

; 使う部品（単体で開いたときもエディタが変数を見つけられるように。同じファイルは 1 度しか読まれない）
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\key_wait.ahk

;------------------------------------------------------------------------------
; アプリ・フォルダの起動
;------------------------------------------------------------------------------
Launch_copilot_on_msedge(){					;microsoft edge上のcopilotページを開く
	Run("msedge.exe `"https://www.bing.com/search?q=Bing+AI&showconv=1&FORM=hpcodx`"") ; "msedge.exe"はMicrosoft Edgeの実行ファイル名です。Copilot pageを開きます
	return
}
Launch_folder_explorer_at_shortcut_list_web_dir(){
	Run("explorer `"C:\Users\KNK07559\Documents\shortcut_list(web_dir)`"")
}

execute_app(){
	SendInput("!{F4}")
	FocusUnderCursor()
}

;------------------------------------------------------------------------------
; アプリ切り替え
;   Alt を押したままの状態を代わりに作り、Alt+Tab の一覧を出したまま選ばせる。
;   AppSwitcher_Show(reverse, pairKey)
;     reverse … false：次のアプリから、true：前（一覧の最後）のアプリから
;     pairKey … 逆方向に動かすキー（省略可）
;   呼び出しに使ったキーは自動で調べ、そのキーで同じ方向へ続けて動かせる。
;     例：Caps → r で AppSwitcher_Show(false, "q") … r：次、q：前
;         "vk1D & 3" で AppSwitcher_Show(false, "2") … 3：次、2：前
;   j k l ; / a s d f：一覧の中で ← / ↑ / ↓ / → に動かす
;   変換など他のキー：決定　Delete：選択中のウィンドウを閉じる　Esc / Caps / Space：キャンセル
;   APPSWITCH_IDLE_SEC 秒操作がなければ、そのとき選んでいるアプリに決定する。
;   決定後はマウスカーソルをそのウィンドウの中央へ移し、Ctrl を押して位置を表示する
;   （Windows の「Ctrl キーを押すとポインターの位置を表示する」をオンにしておくこと）。
;   ※ ih / isWaitingInput / IH_TipClear は key_wait.ahk、tooltipDuration は config.ahk で定義
;------------------------------------------------------------------------------
APPSWITCH_IDLE_SEC := 3
APPSWITCH_ARROWS := Map(
    "j", "Left", "k", "Up", "l", "Down", ";", "Right",
    "a", "Left", "s", "Up", "d", "Down", "f", "Right")

AppSwitcher_Show(reverse := false, pairKey := "") {
  global ih, isWaitingInput := true
  SetTimer(IH_TipClear, 0)                         ; 呼び出し元の「消去タイマー」で表示が消えないように

  ; 呼び出しに使ったキー：「A & B」形式のホットキーなら B、それ以外は InputHook で受けたキー
  prefix := ""
  if RegExMatch(A_ThisHotkey, "^[~*$]*(\S+) & (\S+)$", &m)
    prefix := m[1], triggerKey := m[2]
  else
    triggerKey := ih.Input
  sameVK := (triggerKey != "") ? GetKeyVK(triggerKey) : 0
  pairVK := (pairKey != "") ? GetKeyVK(pairKey) : 0

  h := InputHook("L0 T" APPSWITCH_IDLE_SEC)
  h.KeyOpt("{All}", "ES")                          ; 文字は入力させず、押されたキーで分岐する
  h.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-ES")
  if (prefix != "")
    h.KeyOpt("{" prefix "}", "-E")                ; 押したままのプレフィックスキーのリピートで決定しないように

  nextName := reverse ? pairKey : triggerKey
  prevName := reverse ? triggerKey : pairKey
  hint := (nextName != "" ? nextName "：次　" : "") (prevName != "" ? prevName "：前　" : "")

  startHwnd := WinExist("A")
  Send("{Alt down}" (reverse ? "+{Tab}" : "{Tab}"))
  steps := reverse ? -1 : 1                        ; 一覧で動かした量（0 なら元のウィンドウに戻る）
  posUnknown := false                              ; 矢印で動かす・Delete で閉じると、steps では判断できなくなる
  result := "決定"
  loop {
    ToolTip("🔀 [アプリ切り替え] " hint "j k l `; / a s d f：←↑↓→`n変換 / Enter など：決定　Delete：閉じる　Esc / Caps / Space：キャンセル"
      . "`n（" APPSWITCH_IDLE_SEC " 秒操作しなければ決定）")
    h.Start()                                       ; 待ち時間は押すたびに数え直す
    h.Wait()
    key := h.EndKey
    vk := (h.EndReason = "EndKey") ? GetKeyVK(key) : 0
    if (vk && vk = sameVK) {
      Send(reverse ? "{Blind}+{Tab}" : "{Blind}{Tab}")
      steps += reverse ? -1 : 1
    }
    else if (vk && vk = pairVK) {
      Send(reverse ? "{Blind}{Tab}" : "{Blind}+{Tab}")
      steps += reverse ? 1 : -1
    }
    else if APPSWITCH_ARROWS.Has(key) {
      Send("{Blind}{" APPSWITCH_ARROWS[key] "}")
      posUnknown := true
    }
    else if (key = "Delete") {                      ; Alt+Tab 標準の「選んでいるウィンドウを閉じる」
      Send("{Blind}{Delete}")
      posUnknown := true
    }
    else {
      if (key = "Escape" || key = "CapsLock" || vk = 0x20) {  ; Esc / Caps / Space
        Send("{Blind}{Esc}")
        result := "キャンセル"
      }
      break
    }
  }
  Send("{Alt up}")
  isWaitingInput := false

  if (result = "決定") {
    ; 切り替わったウィンドウの中央へカーソルを移し、Ctrl で位置を知らせる波紋を出す
    _AppSwitcher_MoveCursorToCenter(_AppSwitcher_WaitTarget(startHwnd, steps != 0 || posUnknown))
    Send("{LCtrl}")
  }

  ToolTip((result = "決定" ? "✅" : "❌") " [アプリ切り替え] " result)
  SetTimer(IH_TipClear, -tooltipDuration)
}

; 切り替え先のウィンドウが前面に来るのを待つ（Alt+Tab の一覧画面自体は除く）
; expectOther = true なら、元と違うウィンドウに替わるまで timeoutMs まで待つ
_AppSwitcher_WaitTarget(startHwnd, expectOther := true, timeoutMs := 1500, sameWinMs := 200) {
  t0 := A_TickCount
  last := 0
  loop {
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if (hwnd && !_AppSwitcher_IsSwitcherUI(hwnd)) {
      last := hwnd
      if (hwnd != startHwnd)
        return hwnd
      if (!expectOther && A_TickCount - t0 >= sameWinMs)
        return hwnd
    }
    if (A_TickCount - t0 >= timeoutMs)
      return last                                   ; 一覧画面そのものは返さない
    Sleep(1)                                        ; タイマー分解能は mouse_cursor.ahk で 1ms にしてある
  }
}

_AppSwitcher_IsSwitcherUI(hwnd) {
  try cls := WinGetClass(hwnd)
  catch
    return true
  return cls = "XamlExplorerHostIslandWindow" || cls = "MultitaskingViewFrame"
      || cls = "TaskSwitcherWnd" || cls = "ForegroundStaging"
}

; ウィンドウの見えている範囲（影を除く）の中央へカーソルを移す
_AppSwitcher_MoveCursorToCenter(hwnd) {
  if (!hwnd || !WinExist(hwnd))
    return
  t0 := A_TickCount
  while (WinGetMinMax(hwnd) = -1) {                 ; 最小化から復元中は位置が確定しないので待つ
    if (A_TickCount - t0 >= 1000)
      return
    Sleep(10)
  }
  rc := Buffer(16, 0)
  if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rc, "UInt", 16)  ; DWMWA_EXTENDED_FRAME_BOUNDS
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
  cx := (NumGet(rc, 0, "Int") + NumGet(rc, 8, "Int")) // 2
  cy := (NumGet(rc, 4, "Int") + NumGet(rc, 12, "Int")) // 2
  DllCall("SetCursorPos", "Int", cx, "Int", cy)
}

;------------------------------------------------------------------------------
; タブ・ページの連続切り替え（Caps → w から呼ぶ）
;   モードの間、TABPAGE_ACTIONS のキーを押すたびにその場で切り替える（連打可）。
;   ほかのキー：決定　Esc / Caps：動かした分を戻す
;   KEYCYCLE_IDLE_SEC 秒操作がなければ決定する。
;------------------------------------------------------------------------------
KEYCYCLE_IDLE_SEC := 3

; キー → [送るキー, 戻すときに送るキー, 表示名]（右手は左＝前・右＝次の向き）
TABPAGE_ACTIONS := Map(
    "f", ["^{Tab}",  "^+{Tab}", "次のタブ"],
    "a", ["^+{Tab}", "^{Tab}",  "前のタブ"],
    "d", ["^{PgDn}", "^{PgUp}", "次のページ"],
    "s", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "e", ["^{PgDn}", "^{PgUp}", "次のページ"],
    "w", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "j", ["^+{Tab}", "^{Tab}",  "前のタブ"],
    ";", ["^{Tab}",  "^+{Tab}", "次のタブ"],
    "k", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "l", ["^{PgDn}", "^{PgUp}", "次のページ"],
    "i", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "o", ["^{PgDn}", "^{PgUp}", "次のページ"])

TabPageSwitcher_Show() => KeyCycler_Show("タブ・ページ切り替え", TABPAGE_ACTIONS)

; actions のキーを押すたびに対応するキーを送り、Esc では送った分を逆順に戻す
KeyCycler_Show(title, actions) {
  global isWaitingInput := true
  SetTimer(IH_TipClear, 0)                         ; 呼び出し元の「消去タイマー」で表示が消えないように

  h := InputHook("L0 T" KEYCYCLE_IDLE_SEC)
  h.KeyOpt("{All}", "ES")                          ; 文字は入力させず、押されたキーで分岐する
  h.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-ES")

  ; 同じ動作のキーはまとめて表示する（例：次のタブ：f j）
  keysOf := Map(), order := []
  for k, a in actions {
    if !keysOf.Has(a[3])
      keysOf[a[3]] := "", order.Push(a[3])
    keysOf[a[3]] .= " " k
  }
  hint := ""
  for label in order
    hint .= label "：" Trim(keysOf[label]) "　"

  undo := []                                        ; Esc で戻すための履歴
  result := "決定"
  loop {
    ToolTip("📑 [" title "] " hint "`nほかのキー：決定　Esc / Caps：元に戻す"
      . "`n（" KEYCYCLE_IDLE_SEC " 秒操作しなければ決定）")
    h.Start()                                       ; 待ち時間は押すたびに数え直す
    h.Wait()
    key := StrLower(h.EndKey)
    if (h.EndReason = "EndKey" && actions.Has(key)) {
      SendInput(actions[key][1])
      undo.Push(actions[key][2])
    }
    else {
      if (key = "escape" || key = "capslock") {
        while undo.Length {
          SendInput(undo.Pop())
          Sleep(30)                                 ; 連続で送ると取りこぼすアプリがある
        }
        result := "元に戻しました"
      }
      break
    }
  }
  isWaitingInput := false

  ToolTip((result = "決定" ? "✅" : "↩️") " [" title "] " result)
  SetTimer(IH_TipClear, -tooltipDuration)
}

;------------------------------------------------------------------------------
; ウィンドウの大きさ変更（Caps → q から呼ぶ）
;   Win+↑ / Win+↓ を送る（連打可）。操作は KeyCycler_Show と同じ。
;------------------------------------------------------------------------------
WINSIZE_ACTIONS := Map(
    "w", ["#{Up}",   "#{Down}", "大きく（Win+↑）"],
    "e", ["#{Down}", "#{Up}",   "小さく（Win+↓）"])

WindowResizer_Show() => KeyCycler_Show("ウィンドウの大きさ", WINSIZE_ACTIONS)

;------------------------------------------------------------------------------
; ウィンドウを別のモニターへ移す（Caps → r / Tab から呼ぶ）
;   Win+Shift+→ / ← でアクティブウィンドウを移し、カーソルも移した先のモニターの中央へ動かす。
;   WindowMonitor_Show(reverse)
;     reverse … false：次のモニターへ、true：前のモニターへ
;   呼び出しに使ったキー（Caps → Tab なら Tab）で次へ、Shift 付きで前へ。
;   ほかのキー：決定　Esc / Caps：元のモニターに戻す
;   WINMONITOR_IDLE_SEC 秒操作がなければ、そのときのモニターで決定する。
;------------------------------------------------------------------------------
WINMONITOR_IDLE_SEC := 3

WindowMonitor_Show(reverse := false) {
  global ih, isWaitingInput := true
  SetTimer(IH_TipClear, 0)                         ; 呼び出し元の「消去タイマー」で表示が消えないように

  count := MonitorGetCount()
  hwnd := WinExist("A")
  if (count < 2 || !hwnd) {
    isWaitingInput := false
    ToolTip("🖥 [モニター移動] " (count < 2 ? "モニターが 1 台です" : "対象のウィンドウがありません"))
    SetTimer(IH_TipClear, -tooltipDuration)
    return
  }

  ; 呼び出しに使ったキー：「A & B」形式のホットキーなら B、それ以外は InputHook で受けたキー
  prefix := ""
  if RegExMatch(A_ThisHotkey, "^[~*$]*(\S+) & (\S+)$", &m)
    prefix := m[1], triggerKey := m[2]
  else
    triggerKey := (ih.EndKey != "") ? ih.EndKey : ih.Input
  sameVK := (triggerKey != "") ? GetKeyVK(triggerKey) : 0

  h := InputHook("L0 T" WINMONITOR_IDLE_SEC)
  h.KeyOpt("{All}", "ES")                          ; 文字は入力させず、押されたキーで分岐する
  h.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-ES")
  if (prefix != "")
    h.KeyOpt("{" prefix "}", "-E")                ; 押したままのプレフィックスキーのリピートで決定しないように

  startPt := Buffer(8, 0)
  DllCall("GetCursorPos", "Ptr", startPt)
  steps := 0                                        ; 次へ +1、前へ -1（元に戻すときに使う）
  mon := _WinMonitor_Step(hwnd, reverse)
  steps += reverse ? -1 : 1
  result := "決定"
  loop {
    ToolTip("🖥 [モニター移動] モニター " mon.idx " / " count
      . "`n" triggerKey "：次　Shift+" triggerKey "：前　ほかのキー：決定　Esc：元に戻す"
      . "`n（" WINMONITOR_IDLE_SEC " 秒操作しなければ決定）")
    h.Start()                                       ; 待ち時間は押すたびに数え直す
    h.Wait()
    key := h.EndKey
    vk := (h.EndReason = "EndKey") ? GetKeyVK(key) : 0
    if (vk && vk = sameVK) {
      back := (reverse != GetKeyState("Shift"))     ; Shift 付きなら逆方向
      mon := _WinMonitor_Step(hwnd, back)
      steps += back ? -1 : 1
    }
    else {
      if (key = "Escape" || key = "CapsLock") {
        n := Mod(Mod(steps, count) + count, count)  ; 元のモニターまで「前へ」を何回押すか
        loop n
          _WinMonitor_Step(hwnd, true)
        DllCall("SetCursorPos", "Int", NumGet(startPt, 0, "Int"), "Int", NumGet(startPt, 4, "Int"))
        result := "元に戻しました"
      }
      break
    }
  }
  isWaitingInput := false

  ToolTip((result = "決定" ? "✅" : "❌") " [モニター移動] " result)
  SetTimer(IH_TipClear, -tooltipDuration)
}

; ウィンドウを隣のモニターへ移し、カーソルをそのモニターの中央へ動かす
_WinMonitor_Step(hwnd, back) {
  before := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
  try WinActivate(hwnd)
  Send(back ? "#+{Left}" : "#+{Right}")
  deadline := A_TickCount + 500
  while (DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr") = before && A_TickCount < deadline)
    Sleep(15)
  mon := _WinMonitor_Info(hwnd)
  DllCall("SetCursorPos", "Int", mon.cx, "Int", mon.cy)
  return mon
}

; ウィンドウがいるモニターの番号と中央の座標
_WinMonitor_Info(hwnd) {
  hMon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
  mi := Buffer(40, 0)
  NumPut("UInt", 40, mi)
  DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
  l := NumGet(mi, 4, "Int"), t := NumGet(mi, 8, "Int"), r := NumGet(mi, 12, "Int"), b := NumGet(mi, 16, "Int")
  idx := "?"
  loop MonitorGetCount() {
    MonitorGet(A_Index, &ml, &mt)
    if (ml = l && mt = t) {
      idx := A_Index
      break
    }
  }
  return {idx: idx, cx: (l + r) // 2, cy: (t + b) // 2}
}

; ==============================================================================
; アクティブウィンドウの最前面表示（Always on Top）制御
;   AlwaysOnTop_Toggle()  : 現在の状態を反転
;   AlwaysOnTop_Set()     : 最前面に固定
;   AlwaysOnTop_Release() : 固定を解除
; ==============================================================================

; --- 内部共通：現在のウィンドウが最前面固定かを判定 ---
_IsAlwaysOnTop(hwnd) {
    return (WinGetExStyle(hwnd) & 0x8) ? true : false   ; WS_EX_TOPMOST = 0x8
}

; --- ① トグル ---
AlwaysOnTop_Toggle() {
    hwnd := WinExist("A")
    if !hwnd
        return
    if _IsAlwaysOnTop(hwnd) {
        WinSetAlwaysOnTop(0, hwnd)
        ToolTip("📌 最前面：解除")
    } else {
        WinSetAlwaysOnTop(1, hwnd)
        ToolTip("📌 最前面：固定")
    }
    SetTimer(() => ToolTip(), -tooltipDuration)
}

; --- ② 固定 ---
AlwaysOnTop_Set() {
    hwnd := WinExist("A")
    if !hwnd
        return
    WinSetAlwaysOnTop(1, hwnd)
    ToolTip("📌 最前面：固定")
    SetTimer(() => ToolTip(), -tooltipDuration)
}

; --- ③ 解除 ---
AlwaysOnTop_Release() {
    hwnd := WinExist("A")
    if !hwnd
        return
    WinSetAlwaysOnTop(0, hwnd)
    ToolTip("📌 最前面：解除")
    SetTimer(() => ToolTip(), -tooltipDuration)
}

;------------------------------------------------------------------------------
; スクリーンセーバー回避：オンの間、マウスを小刻みに動かす
;   Popup_Screen_saver() を呼ぶたびにオン／オフを切り替える（Space + F1）。Esc でも解除。
;   状態はトレイアイコン・トレイのツールチップ・トレイメニューのチェックで表示する。
;------------------------------------------------------------------------------
global MouseVibrate := false
SCREENSAVER_MENU := "スクリーンセーバー回避"
A_TrayMenu.Add(SCREENSAVER_MENU, (*) => Popup_Screen_saver())

Popup_Screen_saver() {
    global MouseVibrate := !MouseVibrate
    if MouseVibrate {
        SetTimer(_ScreenSaver_Jiggle, 1000)
        _ScreenSaver_EscWatcher().Start()
        TraySetIcon("imageres.dll", 102)              ; 目のアイコン
        A_IconTip := A_ScriptName "`n☕ スクリーンセーバー回避：ON"
        A_TrayMenu.Check(SCREENSAVER_MENU)
    } else {
        SetTimer(_ScreenSaver_Jiggle, 0)
        _ScreenSaver_EscWatcher().Stop()
        TraySetIcon("*")
        A_IconTip := ""
        A_TrayMenu.Uncheck(SCREENSAVER_MENU)
    }
    ToolTip("☕ スクリーンセーバー回避：" (MouseVibrate ? "ON" : "OFF"))
    SetTimer(() => ToolTip(), -tooltipDuration)
}

; オンのときだけ解除する（ホットキーから Esc を送るときに併用）
ScreenSaver_Off() {
    if MouseVibrate
        Popup_Screen_saver()
}

; Esc で解除するための監視。ホットキーと違い InputHook はこのスクリプト自身が送った Esc も拾える（V：Esc はそのまま通す）
_ScreenSaver_EscWatcher() {
    static h := 0
    if !h {
        h := InputHook("L0 V")
        h.KeyOpt("{Esc}", "N")
        h.OnKeyDown := (*) => (MouseVibrate ? SetTimer(Popup_Screen_saver, -1) : 0)
    }
    return h
}

; 相対移動で左右に 1 往復させる（絶対座標を使わないのでどのモニター上でも位置がずれない）
_ScreenSaver_Jiggle() {
    static right := false
    right := !right
    DllCall("mouse_event", "UInt", 0x0001, "Int", right ? 2 : -2, "Int", 0, "UInt", 0, "UPtr", 0)  ; MOUSEEVENTF_MOVE
}
