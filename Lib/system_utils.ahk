#Requires AutoHotkey v2.0
;==============================================================================
; system_utils.ahk
; OS・ウィンドウ操作の補助（アプリ起動・アプリ切り替え・モニター移動・最前面固定・スクリーンセーバー回避）
;   旧 os_operate_assist.ahk / screen_saver.ahk を統合
;   （launch_execute.ahk は os_operate_assist.ahk と重複していたため削除）
;==============================================================================

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
;   Space など他のキー：決定　Esc / Caps：キャンセル
;   APPSWITCH_IDLE_SEC 秒操作がなければ、そのとき選んでいるアプリに決定する。
;   決定後はマウスカーソルをそのウィンドウの中央へ移し、Ctrl を押して位置を表示する
;   （Windows の「Ctrl キーを押すとポインターの位置を表示する」をオンにしておくこと）。
;   ※ ih / isWaitingInput / IH_TipClear / tooltipDuration は InputHook.ahk で定義
;------------------------------------------------------------------------------
APPSWITCH_IDLE_SEC := 3

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
  result := "決定"
  loop {
    ToolTip("🔀 [アプリ切り替え] " hint "Space：決定　Esc：キャンセル"
      . "`n（" APPSWITCH_IDLE_SEC " 秒操作しなければ決定）")
    h.Start()                                       ; 待ち時間は押すたびに数え直す
    h.Wait()
    key := h.EndKey
    vk := (h.EndReason = "EndKey") ? GetKeyVK(key) : 0
    if (vk && vk = sameVK)
      Send(reverse ? "{Blind}+{Tab}" : "{Blind}{Tab}")
    else if (vk && vk = pairVK)
      Send(reverse ? "{Blind}{Tab}" : "{Blind}+{Tab}")
    else {
      if (key = "Escape" || key = "CapsLock") {
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
    _AppSwitcher_MoveCursorToCenter(_AppSwitcher_WaitTarget(startHwnd))
    Send("{LCtrl}")
  }

  ToolTip((result = "決定" ? "✅" : "❌") " [アプリ切り替え] " result)
  SetTimer(IH_TipClear, -tooltipDuration)
}

; 切り替え先のウィンドウが前面に来るのを待つ（Alt+Tab の一覧画面自体は除く）
_AppSwitcher_WaitTarget(startHwnd, timeoutMs := 1000, sameWinMs := 200) {
  t0 := A_TickCount
  loop {
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if (hwnd && !_AppSwitcher_IsSwitcherUI(hwnd)) {
      if (hwnd != startHwnd)
        return hwnd
      if (A_TickCount - t0 >= sameWinMs)            ; 元と同じウィンドウを選んだときは長く待たない
        return hwnd
    }
    if (A_TickCount - t0 >= timeoutMs)
      return hwnd
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
  if (!hwnd || !WinExist(hwnd) || WinGetMinMax(hwnd) = -1)
    return
  rc := Buffer(16, 0)
  if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rc, "UInt", 16)  ; DWMWA_EXTENDED_FRAME_BOUNDS
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
  cx := (NumGet(rc, 0, "Int") + NumGet(rc, 8, "Int")) // 2
  cy := (NumGet(rc, 4, "Int") + NumGet(rc, 12, "Int")) // 2
  DllCall("SetCursorPos", "Int", cx, "Int", cy)
}

;------------------------------------------------------------------------------
; ウィンドウを別のモニターへ移す（Caps → Tab から呼ぶ）
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
; スクリーンセーバー回避：ポップアップ表示中はマウスを小刻みに動かす
;------------------------------------------------------------------------------
; init
SetTimer(CheckPopup,1000)

; gloval variables
global MouseVibrate := false
global MoveRight := false

; method
Popup_Screen_saver(){
    global myGui := Gui()
    myGui.OnEvent("Close", GuiClose)
    myGui.OnEvent("Escape", GuiClose)
    myGui.Add("Text", , "screen saver execute")
    myGui.Add("Button", , "quit").OnEvent("Click", GuiClose)
    myGui.Title := ""
    myGui.Show("w200 h100")
    global MouseVibrate := true
    return
}

GuiClose(*) ; ポップアップを閉じるとき
{
    myGui.Destroy()
    global MouseVibrate := false
    return
}

CheckPopup(){
    if (MouseVibrate)
        {
            MouseGetPos(&xpos, &ypos)
            if (MoveRight)
            {
                MouseMove(xpos + 3, ypos, 0)
                global MoveRight := false
            }
            else
            {
                MouseMove(xpos - 3, ypos, 0)
                global MoveRight := true
            }
        }
}
