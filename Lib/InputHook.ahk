#Requires AutoHotkey v2.0

; InputHookオブジェクトを作成
ih := InputHook("L1")
isWaitingInput := false              ; InputHookで変換・無変換・スペースキーをつかえるようにするため
tooltipDuration := 500
IH_TIMEOUT_SEC := 5                  ; この秒数キー入力がなければ入力待ちをキャンセル
IH_FN_HINT := "q:F12  w:F7  e:F8  r:F9`na:F11  s:F4  d:F5  f:F6`nz:F10  x:F1  c:F2  v:F3"

; キャンセル用：Esc・Caps で終了、一定時間でタイムアウト（各モードの KeyOpt でも消えない）
ih.Timeout := IH_TIMEOUT_SEC
ih.KeyOpt("{Esc}{sc03A}", "ES")

; いま何のキー待ちかをツールチップで表示する
IH_TipWaiting(mode, hint := "") {
  global isWaitingInput := true  ; 待機中はほかのホットキーを止める（下位のモードでも）
  SetTimer(IH_TipClear, 0)  ; 前のモードの「消去タイマー」で待ち表示が消えないように
  ToolTip("⌨️ [" mode "] 次のキー待ち..." (hint != "" ? "`n" hint : "")
    "`nEsc / Caps / Space+Caps：キャンセル（" IH_TIMEOUT_SEC " 秒で自動キャンセル）")
}

; 入力待ちの終了処理。受け付けたキーを表示し、キャンセルされたら true を返す
IH_EndWait(mode) {
  global ih, isWaitingInput
  cancelled := ""
  if (ih.EndReason = "Timeout")
    cancelled := "タイムアウト"
  else if (ih.EndKey = "Escape" || ih.EndKey = "CapsLock")
    cancelled := "キャンセル"
  else if (ih.EndKey = "Space" && IH_CapsWhileSpaceHeld())
    cancelled := "キャンセル"
  isWaitingInput := false

  if (cancelled != "")
    ToolTip("❌ [" mode "] " cancelled)
  else
    ToolTip("✅ [" mode "] accepted:[" ((ih.EndKey != "") ? ih.EndKey : ih.Input) "]")
  SetTimer(IH_TipClear, -tooltipDuration)
  return cancelled != ""
}

; Space で入力待ちが終わったとき、Space を離すまでに Caps が押されたか（Space+Caps でのキャンセル）
IH_CapsWhileSpaceHeld() {
  h := InputHook("L0 T" IH_TIMEOUT_SEC)
  h.KeyOpt("{sc03A}", "ES")
  h.KeyOpt("{vk20}", "NS")                    ; 押しっぱなしの Space の連打を止め、離したら終える
  h.OnKeyUp := (hk, vk, sc) => (vk = 0x20 ? hk.Stop() : 0)
  h.Start()
  if !GetKeyState("vk20", "P") {
    h.Stop()
    return false
  }
  h.Wait()
  return h.EndReason = "EndKey"
}

IH_TipClear() => ToolTip()

; 動作チェック用
WaitForKeyInput_show_input(){
  global ih
  ih.Start() ; 入力を開始
  ih.Wait() ; 入力が完了するまで待機
  MsgBox("入力された文字: " ih.Input)
}

WaitForKeyInput_for_Caps_1level() {
    global ih, isWaitingInput
    isWaitingInput := true ; 他のスペース系スクリプトを一時停止
    ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
    IH_TipWaiting("Caps")

    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機

    if IH_EndWait("Caps")
        return

    ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
    ; ToolTip()
    isWaitingInput := false
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
        key := ih.EndKey
        if (key = "RAlt") {   ; 右Alt
          ; MsgBox("右Alt検知")
          ToolTip("右Alt検知")
        }
        else if (key = "LShift") { ; 左Shift
          ; MsgBox("LShift検知")
          ToolTip("LShift検知")
        }
        else if (key = "Tab") {
          WindowMonitor_Show()  ; ウィンドウを別のモニターへ（Tab：次、Shift+Tab：前）system_utils.ahk
        }
        else if (key = "Space") {
          turn_on_roman_input_mode() 
          ; MsgBox("{Spaceキー検知")
        }
        else if (key = "sc079") {
          turn_on_hiragana_input_mode()
          ; MsgBox("{変換キー検知}")
        }
        else if (key = "sc07B") {
          ; Capitalize_next_character_you_type()
          ; 🤮　これだけ機能しない。
          MsgBox("無変換キー検知")
        }
        else if (key = "sc070") {
          Capitalize_next_character_you_type()
          ; MsgBox("カタカナひらがなローマ字キー検知")
        }
        ih.Stop()
        return
    }
    ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "t") {
      return
    }
    else if (ih.Input = "r") {
      SendInput("#{Down}")
    }
    else if (ih.Input = "q")
    {
      SendInput("#{Up}")
    }
    else if (ih.Input = "e") {
      AppSwitcher_Show(false, "w")  ; アプリ切り替え（e：次、w：前）system_utils.ahk
    }
    else if (ih.Input = "w") {
      AppSwitcher_Show(true, "e")   ; アプリ切り替え（w：前、e：次）system_utils.ahk
    }
    else if (ih.Input = "g") {
      ; SendInput("^{y}")
      SendInput("{Enter}")
    }
    else if (ih.Input = "f") {
      WaitForKeyInput_call_Fnkeys()
      ; Right_click()
    }
    else if (ih.Input = "a") {
      ; SendInput("{LWin}")
      ; WaitForKeyInput_call_Ctrl_Shift_Fnkeys()
      ; turn_on_roman_input_mode()
    }
    else if (ih.Input = "d") {
      ; WaitForKeyInput_call_Shift_Fnkeys()
    }
    else if (ih.Input = "s") {
      ; WaitForKeyInput_call_Ctrl_Fnkeys()
    }
    else if (ih.Input = "b") {
      CheckContent()  ; multi_clipboard.ahk の関数
    }
    else if (ih.Input = "v") {
      ; SendInput ("^!{l}")                          ; vscode 次のbookmarkへ移動
      PasteText() ; multi_clipboard.ahk の関数
    }
    else if (ih.Input = "c") {
      ; SendInput ("^!{k}")                          ; vscode bookmark toggle
      SaveText() ; multi_clipboard.ahk の関数
    }
    else if (ih.Input = "z") {
      ClearBox()  ; multi_clipboard.ahk の関数
    }
    else if (ih.Input = "x") {
      ; SendInput ("^!{j}")                          ; vscode 前のbookmarkへ移動
      CutAndSaveText()  ; multi_clipboard.ahk の関数
    }
    else if(ih.Input = "y") {
      ; Input_current_Date1() 
    }
    else if(ih.Input = "u") {
      QuickPalette_Show() ; コマンドパレット
    }
    else if(ih.Input = "i") {
      ; Input_current_Date3()
      ; Right_click()
      ; WaitForKeyInput_call_CtrlShiftChar_keys()
      WaitForKeyInput_call_AltChar_keys()
    }
    else if(ih.Input = "o") {
      ; Input_current_Date4()
      ; WaitForKeyInput_call_AltChar_keys()
      WaitForKeyInput_call_CtrlShiftChar_keys()
    }
    else if(ih.Input = "p") {
      ; Input_current_Date5()
      
    }
    else if (ih.Input = "h") {
      ; turn_on_roman_input_mode()
      ; WaitForKeyInput_call_CtrlChar_keys()
      ; Capitalize_next_character_you_type()  ;次の文字を大文字に
      ; SendInput("^{z}")
      SendInput("{Enter}")
    }
    else if (ih.Input = "j") {
      ; AlwaysOnTop_Set()
      QM_SymbolMenu_Show()
    }
    else if (ih.Input = "k") {
      ; AlwaysOnTop_Release()
      QuickMenu_Show() ; クイックメニュー
    }
    else if (ih.Input = "l") {
      ; WaitForKeyInput_call_AltChar_keys()
      ; turn_on_hiragana_input_mode()
      ; toggle_input_mode()
      WaitForKeyInput_call_CtrlChar_keys()
    }
    else if (ih.Input = ";") {
      ; Capitalize_next_character_you_type()  ;次の文字を大文字に
      ; toggle_input_mode()
      WaitForKeyInput_call_WinChar_keys()
    }
    else if (ih.Input = ":") {
      ; turn_on_hiragana_input_mode()               ; ひらがな入力モード
    }
    else if (ih.Input = "n") {
      Capitalize_next_character_you_type()  ;次の文字を大文字に
    }
    ; else if (ih.Input = " ") {
    ;   turn_on_roman_input_mode()                ; ローマ字入力モード
    ; }
    else if (ih.Input = "\") {
      ResetAll()  ; multi_clipboard.ahk
    }
    else if (ih.Input = "m") {
      return
    }
    else if (ih.Input = ",") {
      return
    }
    else if (ih.Input = ".") {
      return
    }
    ih.Stop()
    return
}

WaitForKeyInput_for_Space_and_f_1level() {
    global ih, isWaitingInput
    global ih, isWaitingInput
    isWaitingInput := true ; 他のスペース系スクリプトを一時停止
    ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
    IH_TipWaiting("Space + F")

    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機

    if IH_EndWait("Space + F")
        return

    ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
    ; ToolTip()
    isWaitingInput := false
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
        key := ih.EndKey
        if (key = "RAlt") {   ; 右Alt
          ; MsgBox("右Alt検知")
          ToolTip("右Alt検知")
        }
        else if (key = "LShift") { ; 左Shift
          ; MsgBox("LShift検知")
          ToolTip("LShift検知")
        }
        else if (key = "Tab") {
          ; MsgBox("Tab検知")
          ToolTip("Tab検知")
        }
        else if (key = "Space") {
          ; MsgBox("{Spaceキー検知")
          ToolTip("{Spaceキー検知")
        }
        else if (key = "sc079") {
          ; MsgBox("{変換キー検知}")
          ToolTip("{変換キー検知}")
        }
        else if (key = "sc07B") {
          ; MsgBox("無変換キー検知")
          ToolTip("無変換キー検知")
        }
        else if (key = "sc070") {
          ; MsgBox("カタカナひらがなローマ字キー検知")
          ToolTip("カタカナひらがなローマ字キー検知")
        }
        ih.Stop()
        return
    }

  ; 入力されたキーに応じて処理を分岐
  if (ih.Input = "t") {
    return
  }
  else if (ih.Input = "r") {
    SendInput("^{End}")
    }
  else if (ih.Input = "q")
  {
    SendInput("^{Home}")
    }
  else if (ih.Input = "e") {
    SendInput("{End}")
  }
  else if (ih.Input = "w") {
    SendInput("{Home}")
  }
  else if (ih.Input = "g") {
    ; SendInput("!{F4}")
  }
  else if (ih.Input = "h") {
    ; SendInput("!{F4}")
  }
  else if (ih.Input = "f") {
    Right_click()
  }
  else if (ih.Input = "a") {
    SendInput("{LWin}")
  }
  else if (ih.Input = "d") {
    SendInput("{LAlt}")
  }
  else if (ih.Input = "s") {
    ; SendInput("{LAlt}")
    SendInput("{LCtrl}")
  }
  else if (ih.Input = "b") {
    ; SendInput("!{F4}")
  }
  else if (ih.Input = "n") {
    ; SendInput("!{F4}")
  }
  else if (ih.Input = "v") {
    ; SendInput("^#{Right}")
  }
  else if (ih.Input = "z") {
    ; SendInput("^#{Left}")
  }
  else if (ih.Input = "x") {
    ; SendInput("^#{d}")
  }
  else if (ih.Input = "c") {
    ; SendInput("^#{F4}")
  }
  else if (ih.Input = "j") {
    ; WaitForKeyInput_call_CtrlChar_keys()
    ; turn_on_roman_input_mode()                ; 半角入力モード
    ; turn_on_hiragana_input_mode()               ; ひらがな入力モード
    SendInput("+{Enter}")
  }
  else if (ih.Input = "k") {
    ; WaitForKeyInput_call_CtrlShiftChar_keys()
    ; turn_on_hiragana_input_mode()               ; ひらがな入力モード
    ; turn_on_roman_input_mode()                ; 半角入力モード
    SendInput("^{Enter}")
  }
  else if (ih.Input = "l") {
    ; WaitForKeyInput_call_AltChar_keys()
    SendInput("!{Enter}")
  }
  else if (ih.Input = ";") {
    ; WaitForKeyInput_call_WinChar_keys()
    return
  }
  else if(ih.Input = "y") {
    Input_current_Date1() 
  }
  else if(ih.Input = "u") {
    Input_current_Date2()
  }
  else if(ih.Input = "i") {
    Input_current_Date3()
  }
  else if(ih.Input = "o") {
    Input_current_Date4()
  }
  else if(ih.Input = "p") {
    Input_current_Date5()
  }
  else if(ih.Input = "[") {
    ; SendInput("!{F4}")
    execute_app()
  }
  else if(ih.Input = "]") {
    ; SendInput("!{F4}")
    execute_app()
  }
  else if (ih.Input = "1") {
    
  }
  else if (ih.Input = "2") {
    
  }
  else if (ih.Input = "3") {
    
  }
  else if (ih.Input = "4") {
    SendInput("!{F4}")
  }
  else if (ih.Input = "5") {
    
  }
  else if (ih.Input = "6") {
    
  }
  else if (ih.Input = "7") {
    
  }
  else if (ih.Input = "8") {
    
  }
  else if (ih.Input = "9") {
    
  }
  else if (ih.Input = "0") {
    
  }
  ih.Stop()
  return
}

WaitForKeyInput_Input_letter_only_lefthand_and_symbols() {
  global ih, isWaitingInput
  global ih, isWaitingInput
  isWaitingInput := true ; 他のスペース系スクリプトを一時停止
  ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
  IH_TipWaiting("Space + A：左手で文字・記号")

  ; 特殊キーを「EndKey（終了キー）」として登録
  ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
  ih.Start() ; 入力を開始
  ih.Wait() ; 入力が完了するまで待機

  if IH_EndWait("Space + A：左手で文字・記号")
    return

  ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
  ; ToolTip()
  isWaitingInput := false
  ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
  if (ih.EndReason = "EndKey") {
      key := ih.EndKey
      if (key = "RAlt") {   ; 右Alt
        ; MsgBox("右Alt検知")
        ToolTip("右Alt検知")
      }
      else if (key = "LShift") { ; 左Shift
        ; MsgBox("LShift検知")
        ToolTip("LShift検知")
      }
      else if (key = "Tab") {
        ; MsgBox("Tab検知")
        ToolTip("Tab検知")
      }
      else if (key = "Space") {
        ; MsgBox("{Spaceキー検知")
        ToolTip("{Spaceキー検知")
      }
      else if (key = "sc079") {
        Capitalize_next_character_you_type() ;次の入力だけ大文字化
      }
      else if (key = "sc07B") {
        ; MsgBox("無変換キー検知")
        ToolTip("無変換キー検知")
      }
      else if (key = "sc070") {
        ; MsgBox("カタカナひらがなローマ字キー検知")
        ToolTip("カタカナひらがなローマ字キー検知")
      }
      ih.Stop()
      return
  }
  ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
  ; 入力されたキーに応じて処理を分岐
  if (ih.Input = "t") {
    SendInput("{y}")
  }
  else if (ih.Input = "r") {
    SendInput("{u}")
  }
  else if (ih.Input = "q"){
    SendInput("{p}")
  }
  else if (ih.Input = "e") {
    SendInput("{i}")
  }
  else if (ih.Input = "w") {
    SendInput("{o}")
  }
  else if (ih.Input = "g") {
    SendInput("{h}")
  }
  else if (ih.Input = "f") {
    SendInput("{j}")
  }
  else if (ih.Input = "a") {
    SendInput("{Space}")
  }
  else if (ih.Input = "d") {
    SendInput("{k}")
  }
  else if (ih.Input = "s") {
    SendInput("{l}")
  }
  else if (ih.Input = "b") {
    SendInput("{n}")
  }
  else if (ih.Input = "v") {
    SendInput("{m}")
  }
  else if (ih.Input = "c") {
    
  }
  else if (ih.Input = "z") {
    
  }
  else if (ih.Input = "x") {
    
  }
  else if(ih.Input = "y") {
    
  }
  else if(ih.Input = "u") {
    SendInput("{|}")
  }
  else if(ih.Input = "i") {
    SendInput("{~}")
  }
  else if(ih.Input = "o") {
    SendInput("{!}")
  }
  else if(ih.Input = "p") {
    SendInput("{^}")
  }
  else if (ih.Input = "h") {
    
  }
  else if (ih.Input = "j") {
    SendInput("{#}")
  }
  else if (ih.Input = "k") {
    SendInput("{$}")
  }
  else if (ih.Input = "l") {
    SendInput("{%}")
  }
  else if (ih.Input = ";") {
    SendInput("{&}")
  }
  else if (ih.Input = "@") {
    SendInput("{\}")
  }
  else if (ih.Input = ":") {
    SendInput("{~}")
  }
  else if (ih.Input = "[") {
    return
  }
  else if (ih.Input = "]") {
    return
  }
  else if (ih.Input = "1") {
    SendInput("{0}")
  }
  else if (ih.Input = "2") {
    SendInput("{9}")
  }
  else if (ih.Input = "3") {
    SendInput("{8}")
  }
  else if (ih.Input = "4") {
    SendInput("{7}")
  }
  else if (ih.Input = "5") {
    SendInput("{6}")
  }
  ih.Stop()
  return
}

WaitForKeyInput_call_Fnkeys() { ; キー入力を待つ関数 Fnキー関連
    global ih
    IH_TipWaiting("Fn キー", IH_FN_HINT)
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Fn キー")
        return

    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "z") {
    SendInput("{F10}")
    }
  else if (ih.Input = "x") {
    SendInput("{F1}")
    }
  else if (ih.Input = "c") {
    SendInput("{F2}")
    }
  else if (ih.Input = "v") {
    SendInput("{F3}")
    }
  else if (ih.Input = "a") {
    SendInput("{F11}")
    }
  else if (ih.Input = "s") {
    SendInput("{F4}")
    }
  else if (ih.Input = "d") {
    SendInput("{F5}")
    }
  else if (ih.Input = "f") {
    SendInput("{F6}")
    }
  else if (ih.Input = "q") {
    SendInput("{F12}")
    }
  else if (ih.Input = "w") {
    SendInput("{F7}")
    }
  else if (ih.Input = "e") {
    SendInput("{F8}")
    }
  else if (ih.Input = "r") {
    SendInput("{F9}")
    }
  ih.Stop()
  return
}

WaitForKeyInput_call_Shift_Fnkeys() { ; キー入力を待つ関数 Fnキー関連
    global ih
    IH_TipWaiting("Shift + Fn キー", IH_FN_HINT)
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Shift + Fn キー")
        return

    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "z") {
    SendInput("+{F10}")
    }
  else if (ih.Input = "x") {
    SendInput("+{F1}")
    }
  else if (ih.Input = "c") {
    SendInput("+{F2}")
    }
  else if (ih.Input = "v") {
    SendInput("+{F3}")
    }
  else if (ih.Input = "a") {
    SendInput("+{F11}")
    }
  else if (ih.Input = "s") {
    SendInput("+{F4}")
    }
  else if (ih.Input = "d") {
    SendInput("+{F5}")
    }
  else if (ih.Input = "f") {
    SendInput("+{F6}")
    }
  else if (ih.Input = "q") {
    SendInput("+{F12}")
    }
  else if (ih.Input = "w") {
    SendInput("+{F7}")
    }
  else if (ih.Input = "e") {
    SendInput("+{F8}")
    }
  else if (ih.Input = "r") {
    SendInput("+{F9}")
    }
  ih.Stop()
  return
}

WaitForKeyInput_call_Ctrl_Fnkeys() {  ; キー入力を待つ関数 Fnキー関連
    global ih
    IH_TipWaiting("Ctrl + Fn キー", IH_FN_HINT)
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Ctrl + Fn キー")
        return

    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "z") {
    SendInput("^{F10}")
    }
  else if (ih.Input = "x") {
    SendInput("^{F1}")
    }
  else if (ih.Input = "c") {
    SendInput("^{F2}")
    }
  else if (ih.Input = "v") {
    SendInput("^{F3}")
    }
  else if (ih.Input = "a") {
    SendInput("^{F11}")
    }
  else if (ih.Input = "s") {
    SendInput("^{F4}")
    }
  else if (ih.Input = "d") {
    SendInput("^{F5}")
    }
  else if (ih.Input = "f") {
    SendInput("^{F6}")
    }
  else if (ih.Input = "q") {
    SendInput("^{F12}")
    }
  else if (ih.Input = "w") {
    SendInput("^{F7}")
    }
  else if (ih.Input = "e") {
    SendInput("^{F8}")
    }
  else if (ih.Input = "r") {
    SendInput("^{F9}")
    }
  ih.Stop()
  return
}

WaitForKeyInput_call_Ctrl_Shift_Fnkeys() {  ; キー入力を待つ関数 Fnキー関連
    global ih
    IH_TipWaiting("Ctrl + Shift + Fn キー", IH_FN_HINT)
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Ctrl + Shift + Fn キー")
        return

    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "z") {
    SendInput("^+{F10}")
    }
  else if (ih.Input = "x") {
    SendInput("^+{F1}")
    }
  else if (ih.Input = "c") {
    SendInput("^+{F2}")
    }
  else if (ih.Input = "v") {
    SendInput("^+{F3}")
    }
  else if (ih.Input = "a") {
    SendInput("^+{F11}")
    }
  else if (ih.Input = "s") {
    SendInput("^+{F4}")
    }
  else if (ih.Input = "d") {
    SendInput("^+{F5}")
    }
  else if (ih.Input = "f") {
    SendInput("^+{F6}")
    }
  else if (ih.Input = "q") {
    SendInput("^+{F12}")
    }
  else if (ih.Input = "w") {
    SendInput("^+{F7}")
    }
  else if (ih.Input = "e") {
    SendInput("^+{F8}")
    }
  else if (ih.Input = "r") {
    SendInput("^+{F9}")
    }
  ih.Stop()
  return
}

WaitForKeyInput_call_CtrlChar_keys() {  ; キー入力を待つ関数 Ctrlキー関連
  global ih
  IH_TipWaiting("Ctrl + 文字キー")
  ih.Start() ; 入力を再開
  ih.Wait() ; 入力が完了するまで待機
  if IH_EndWait("Ctrl + 文字キー")
    return

  ; 入力されたキーに応じて処理を分岐
  if (ih.Input = "a") {
    SendInput("^{a}")
  }
  else if (ih.Input = "b") {
    SendInput("^{b}")
  }
  else if (ih.Input = "c") {
    ; 変更内容：明示的にCtrlの押下を指示してから該当のキーを押す
    ; 変更日時：2025/08/07
    Try{
      Send("{Ctrl down}")
      Sleep(5)
      Send("{c}")
      Sleep(5)
      Send("{Ctrl up}")
    } finally {
      Send("{Ctrl up}")
    }
    ; 元々の処理
    ; SendInput("^{c}")
    }
  else if (ih.Input = "d") {
    SendInput("^{d}")
    }
  else if (ih.Input = "e") {
    SendInput("^{e}")
    }
  else if (ih.Input = "f") {
    SendInput("^{f}")
    }
  else if (ih.Input = "g") {
    SendInput("^{g}")
    }
  else if (ih.Input = "h") {
    SendInput("^{h}")
    }
  else if (ih.Input = "i") {
    SendInput("^{i}")
    }
  else if (ih.Input = "j") {
    SendInput("^{j}")
    }
  else if (ih.Input = "k") {
    SendInput("^{k}")
    }
  else if (ih.Input = "l") {
    SendInput("^{l}")
    }
  else if (ih.Input = "m") {
    SendInput("^{m}")
    }
  else if (ih.Input = "n") {
    SendInput("^{n}")
    }
  else if (ih.Input = "o") {
    SendInput("^{o}")
    }
  else if (ih.Input = "p") {
    SendInput("^{p}")
    }
  else if (ih.Input = "q") {
    SendInput("^{q}")
    }
  else if (ih.Input = "r") {
    SendInput("^{r}")
    }
  else if (ih.Input = "s") {
    SendInput("^{s}")
    }
  else if (ih.Input = "t") {
    SendInput("^{t}")
    }
  else if (ih.Input = "u") {
    SendInput("^{u}")
    }
  else if (ih.Input = "v") {
    ; 変更内容：明示的にCtrlの押下を指示してから該当のキーを押す
    ; 変更日時：2025/08/07
    Try{
      Send("{Ctrl down}")
      Sleep(5)
      Send("{v}")
      Sleep(5)
      Send("{Ctrl up}")
    } finally {
      Send("{Ctrl up}")
    }
    ; 元々の処理
    ; SendInput("^{v}")
    }
  else if (ih.Input = "w") {
    SendInput("^{w}")
    }
  else if (ih.Input = "x") {
    ; 変更内容：明示的にCtrlの押下を指示してから該当のキーを押す
    ; 変更日時：2025/08/07
    Try{
      Send("{Ctrl down}")
      Sleep(5)
      Send("{x}")
      Sleep(5)
      Send("{Ctrl up}")
    } finally {
      Send("{Ctrl up}")
    }
    ; 元々の処理
    ; SendInput("^{x}")
    }
  else if (ih.Input = "y") {
    SendInput("^{y}")
    }
  else if (ih.Input = "z") {
    SendInput("^{z}")
    }
    else if (ih.Input = "1") {
    SendInput("^{1}")
    }
    else if (ih.Input = "2") {
    SendInput("^{2}")
    }
    else if (ih.Input = "3") {
    SendInput("^{3}")
    }
    else if (ih.Input = "4") {
    SendInput("^{4}")
    }
    else if (ih.Input = "5") {
    SendInput("^{5}")
    }
    else if (ih.Input = "6") {
    SendInput("^{6}")
    }
    else if (ih.Input = "7") {
    SendInput("^{7}")
    }
    else if (ih.Input = "8") {
    SendInput("^{8}")
    }
    else if (ih.Input = "9") {
    SendInput("^{9}")
    }
  ih.Stop()
  return
}

WaitForKeyInput_call_CtrlShiftChar_keys() { ; キー入力を待つ関数 Ctrlキー関連
    global ih
    IH_TipWaiting("Ctrl + Shift + 文字キー")
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Ctrl + Shift + 文字キー")
        return

    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "a") {
      SendInput("^+{a}")
    }
    else if (ih.Input = "b") {
      SendInput("^+{b}")
      }
    else if (ih.Input = "c") {
      SendInput("^+{c}")
      }
    else if (ih.Input = "d") {
      SendInput("^+{d}")
      }
    else if (ih.Input = "e") {
      SendInput("^+{e}")
      }
    else if (ih.Input = "f") {
      SendInput("^+{f}")
      }
    else if (ih.Input = "g") {
      SendInput("^+{g}")
      }
    else if (ih.Input = "h") {
      SendInput("^+{h}")
      }
    else if (ih.Input = "i") {
      SendInput("^+{i}")
      }
    else if (ih.Input = "j") {
      SendInput("^+{j}")
      }
    else if (ih.Input = "k") {
      SendInput("^+{k}")
      }
    else if (ih.Input = "l") {
      SendInput("^+{l}")
      }
    else if (ih.Input = "m") {
      SendInput("^+{m}")
      }
    else if (ih.Input = "n") {
      SendInput("^+{n}")
      }
    else if (ih.Input = "o") {
      SendInput("^+{o}")
      }
    else if (ih.Input = "p") {
      SendInput("^+{p}")
      }
    else if (ih.Input = "q") {
      SendInput("^+{q}")
      }
    else if (ih.Input = "r") {
      SendInput("^+{r}")
      }
    else if (ih.Input = "s") {
      SendInput("^+{s}")
      }
    else if (ih.Input = "t") {
      SendInput("^+{t}")
      }
    else if (ih.Input = "u") {
      SendInput("^+{u}")
      }
    else if (ih.Input = "v") {
      SendInput("^+{v}")
      }
    else if (ih.Input = "w") {
      SendInput("^+{w}")
      }
    else if (ih.Input = "x") {
      SendInput("^+{x}")
      }
    else if (ih.Input = "y") {
      SendInput("^+{y}")
      }
    else if (ih.Input = "z") {
      SendInput("^+{z}")
    }
    else if (ih.Input = ";") {
      SendInput("^+{;}")
    }
    ih.Stop()
    return
}

WaitForKeyInput_call_WinChar_keys() {  ; キー入力を待つ関数 Ctrlキー関連
    global ih
    IH_TipWaiting("Win + 文字キー")
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Win + 文字キー")
        return

    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "a") {
        SendInput("#{a}")
    }
    else if (ih.Input = "b") {
        SendInput("#{b}")
    }
    else if (ih.Input = "c") {
        SendInput("#{c}")
    }
    else if (ih.Input = "d") {
        SendInput("#{d}")
    }
    else if (ih.Input = "e") {
        SendInput("#{e}")
    }
    else if (ih.Input = "f") {
        SendInput("#{f}")
    }
    else if (ih.Input = "g") {
        SendInput("#{g}")
    }
    else if (ih.Input = "h") {
        SendInput("#{h}")
    }
    else if (ih.Input = "i") {
        SendInput("#{i}")
    }
    else if (ih.Input = "j") {
        SendInput("#{j}")
    }
    else if (ih.Input = "k") {
        SendInput("#{k}")
    }
    else if (ih.Input = "l") {
        SendInput("#{l}")
    }
    else if (ih.Input = "m") {
        SendInput("#{m}")
    }
    else if (ih.Input = "n") {
        SendInput("#{n}")
    }
    else if (ih.Input = "o") {
        SendInput("#{o}")
    }
    else if (ih.Input = "p") {
        SendInput("#{p}")
    }
    else if (ih.Input = "q") {
        SendInput("#{q}")
    }
    else if (ih.Input = "r") {
        SendInput("#{r}")
    }
    else if (ih.Input = "s") {
        SendInput("#{s}")
    }
    else if (ih.Input = "t") {
        SendInput("#{t}")
    }
    else if (ih.Input = "u") {
        SendInput("#{u}")
    }
    else if (ih.Input = "v") {
        SendInput("#{v}")
    }
    else if (ih.Input = "w") {
        SendInput("#{w}")
    }
    else if (ih.Input = "x") {
        SendInput("#{x}")
    }
    else if (ih.Input = "y") {
        SendInput("#{y}")
    }
    else if (ih.Input = "z") {
        SendInput("#{z}")
    }
    else if (ih.Input = ",") {
        SendInput("#{,}")
    }
    else if (ih.Input = ".") {
        SendInput("#{.}")
    }
    ih.Stop()
    return
}

WaitForKeyInput_call_AltChar_keys() {  ; キー入力を待つ関数 Ctrlキー関連
    global ih
    IH_TipWaiting("Alt + 文字キー")
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
    if IH_EndWait("Alt + 文字キー")
        return
    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "a") {
        SendInput("!{a}")
    }
    else if (ih.Input = "b") {
        SendInput("!{b}")
    }
    else if (ih.Input = "c") {
        SendInput("!{c}")
    }
    else if (ih.Input = "d") {
        SendInput("!{d}")
    }
    else if (ih.Input = "e") {
        SendInput("!{e}")
    }
    else if (ih.Input = "f") {
        SendInput("!{f}")
    }
    else if (ih.Input = "g") {
        SendInput("!{g}")
    }
    else if (ih.Input = "h") {
        SendInput("!{h}")
    }
    else if (ih.Input = "i") {
        SendInput("!{i}")
    }
    else if (ih.Input = "j") {
        SendInput("!{j}")
    }
    else if (ih.Input = "k") {
        SendInput("!{k}")
    }
    else if (ih.Input = "l") {
        SendInput("!{l}")
    }
    else if (ih.Input = "m") {
        SendInput("!{m}")
    }
    else if (ih.Input = "n") {
        SendInput("!{n}")
    }
    else if (ih.Input = "o") {
        SendInput("!{o}")
    }
    else if (ih.Input = "p") {
        SendInput("!{p}")
    }
    else if (ih.Input = "q") {
        SendInput("!{q}")
    }
    else if (ih.Input = "r") {
        SendInput("!{r}")
    }
    else if (ih.Input = "s") {
        SendInput("!{s}")
    }
    else if (ih.Input = "t") {
        SendInput("!{t}")
    }
    else if (ih.Input = "u") {
        SendInput("!{u}")
    }
    else if (ih.Input = "v") {
        SendInput("!{v}")
    }
    else if (ih.Input = "w") {
        SendInput("!{w}")
    }
    else if (ih.Input = "x") {
        SendInput("!{x}")
    }
    else if (ih.Input = "y") {
        SendInput("!{y}")
    }
    else if (ih.Input = "z") {
        SendInput("!{z}")
    }
    ih.Stop()
    return
}

WaitForKeyInput_kata_hira_romeji() {
    global ih, isWaitingInput
    global ih, isWaitingInput
    isWaitingInput := true ; 他のスペース系スクリプトを一時停止
    ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
    IH_TipWaiting("カタカナひらがな")

    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機

    if IH_EndWait("カタカナひらがな")
        return

    ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
    ; ToolTip()
    isWaitingInput := false
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
        key := ih.EndKey
        if (key = "RAlt") {   ; 右Alt
          ; MsgBox("右Alt検知")
          ToolTip("右Alt検知")
        }
        else if (key = "LShift") { ; 左Shift
          ; MsgBox("LShift検知")
          ToolTip("LShift検知")
        }
        else if (key = "Tab") {
          ; MsgBox("Tab検知")
          ToolTip("Tab検知")
        }
        else if (key = "Space") {
          ; MsgBox("{Spaceキー検知")
          ToolTip("{Spaceキー検知}")
        }
        else if (key = "sc079") {
          ; MsgBox("{変換キー検知}")
          ToolTip("{変換キー検知}")
        }
        else if (key = "sc07B") {
          ; MsgBox("無変換キー検知")
          ToolTip("無変換キー検知")
        }
        else if (key = "sc070") {
          ; MsgBox("カタカナひらがなローマ字キー検知")
          ToolTip("カタカナひらがなローマ字キー検知")
        }
        ih.Stop()
        return
    }

    ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "t") {
      
    }
    else if (ih.Input = "r") {
      
    }
    else if (ih.Input = "q"){
      
    }
    else if (ih.Input = "e") {
      
    }
    else if (ih.Input = "w") {
      
    }
    else if (ih.Input = "g") {
      
    }
    else if (ih.Input = "f") {
      
    }
    else if (ih.Input = "a") {
      
    }
    else if (ih.Input = "d") {
      
    }
    else if (ih.Input = "s") {
      
    }
    else if (ih.Input = "b") {
      
    }
    else if (ih.Input = "v") {
      
    }
    else if (ih.Input = "c") {
      
    }
    else if (ih.Input = "z") {
      
    }
    else if (ih.Input = "x") {
      
    }
    else if(ih.Input = "y") {
      
    }
    else if(ih.Input = "u") {
      
    }
    else if(ih.Input = "i") {
      
    }
    else if(ih.Input = "o") {
      
    }
    else if(ih.Input = "p") {
      
    }
    else if (ih.Input = "h") {
      
    }
    else if (ih.Input = "j") {
      SendInput("{y}")
    }
    else if (ih.Input = "k") {
      SendInput("{u}")
    }
    else if (ih.Input = "l") {
      SendInput("{o}")
    }
    else if (ih.Input = ";") {
      SendInput("{p}")
    }
    else if (ih.Input = ":") {
      
    }
    else if (ih.Input = "n") {
      
    }
    ih.Stop()
    return
}

WaitForKeyInput_for_pressing_far_keys() {
    global ih, isWaitingInput
    global ih, isWaitingInput
    isWaitingInput := true ; 他のスペース系スクリプトを一時停止
    ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
    IH_TipWaiting("遠いキー")

    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機

    if IH_EndWait("遠いキー")
        return

    ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
    ; ToolTip()
    isWaitingInput := false
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
        key := ih.EndKey
        if (key = "RAlt") {   ; 右Alt
          ; MsgBox("右Alt検知")
          ToolTip("右Alt検知")
        }
        else if (key = "LShift") { ; 左Shift
          ; MsgBox("LShift検知")
          ToolTip("LShift検知")
        }
        else if (key = "Tab") {
          ; MsgBox("Tab検知")
          ToolTip("Tab検知")
        }
        else if (key = "Space") {
          ; MsgBox("{Spaceキー検知")
          ToolTip("{Spaceキー検知}")
        }
        else if (key = "sc079") {
          ; MsgBox("{変換キー検知}")
          ToolTip("{変換キー検知}")
        }
        else if (key = "sc07B") {
          ; MsgBox("無変換キー検知")
          ToolTip("無変換キー検知")
        }
        else if (key = "sc070") {
          ; MsgBox("カタカナひらがなローマ字キー検知")
          ToolTip("カタカナひらがなローマ字キー検知")
        }
        ih.Stop()
        return
    }
    
    ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "t") {
      
    }
    else if (ih.Input = "r") {
      
    }
    else if (ih.Input = "q"){
      
    }
    else if (ih.Input = "e") {
      SendInput("{r}")
    }
    else if (ih.Input = "w") {
      
    }
    else if (ih.Input = "g") {
      
    }
    else if (ih.Input = "f") {
      SendInput("{t}")
    }
    else if (ih.Input = "a") {
      SendInput("{q}")
    }
    else if (ih.Input = "d") {
      
    }
    else if (ih.Input = "s") {
      
    }
    else if (ih.Input = "b") {
      
    }
    else if (ih.Input = "v") {
      
    }
    else if (ih.Input = "c") {
      
    }
    else if (ih.Input = "z") {
      
    }
    else if (ih.Input = "x") {
      
    }
    else if(ih.Input = "y") {
      
    }
    else if(ih.Input = "u") {
      
    }
    else if(ih.Input = "i") {
      SendInput("{u}")
    }
    else if(ih.Input = "o") {
      
    }
    else if(ih.Input = "p") {
      
    }
    else if (ih.Input = "h") {
      
    }
    else if (ih.Input = "j") {
      SendInput("{y}")
    }
    else if (ih.Input = "k") {
      
    }
    else if (ih.Input = "l") {
      
    }
    else if (ih.Input = ";") {
      SendInput("{p}")
    }
    else if (ih.Input = ":") {
      
    }
    else if (ih.Input = "n") {
      
    }
    ih.Stop()
    return
}

WaitForKeyInput_symbol_keys() {
global ih, isWaitingInput
    global ih, isWaitingInput
    isWaitingInput := true ; 他のスペース系スクリプトを一時停止
    ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
    IH_TipWaiting("記号")

    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機

    if IH_EndWait("記号")
        return

    ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
    ; ToolTip()
    isWaitingInput := false
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
        key := ih.EndKey
        if (key = "RAlt") {   ; 右Alt
          ; MsgBox("右Alt検知")
          ToolTip("右Alt検知")
        }
        else if (key = "LShift") { ; 左Shift
          ; MsgBox("LShift検知")
          ToolTip("LShift検知")
        }
        else if (key = "Tab") {
          ; MsgBox("Tab検知")
          ToolTip("Tab検知")
        }
        else if (key = "Space") {
          ; MsgBox("{Spaceキー検知")
          ToolTip("{Spaceキー検知}")
        }
        else if (key = "sc079") {
          ; MsgBox("{変換キー検知}")
          ToolTip("{変換キー検知}")
        }
        else if (key = "sc07B") {
          ; MsgBox("無変換キー検知")
          ToolTip("無変換キー検知")
        }
        else if (key = "sc070") {
          ; MsgBox("カタカナひらがなローマ字キー検知")
          ToolTip("カタカナひらがなローマ字キー検知")
        }
        ih.Stop()
        return
    }
    
    ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "t") {
      
    }
    else if (ih.Input = "r") {
      
    }
    else if (ih.Input = "q"){
      
    }
    else if (ih.Input = "e") {
      
    }
    else if (ih.Input = "w") {
      
    }
    else if (ih.Input = "g") {
      
    }
    else if (ih.Input = "f") {
      
    }
    else if (ih.Input = "a") {
      
    }
    else if (ih.Input = "d") {
      
    }
    else if (ih.Input = "s") {
      
    }
    else if (ih.Input = "b") {
      
    }
    else if (ih.Input = "v") {
      
    }
    else if (ih.Input = "c") {
      
    }
    else if (ih.Input = "z") {
      
    }
    else if (ih.Input = "x") {
      
    }
    else if(ih.Input = "y") {
      
    }
    else if(ih.Input = "u") {
      
    }
    else if(ih.Input = "i") {
      
    }
    else if(ih.Input = "o") {
      
    }
    else if(ih.Input = "p") {
            
    }
    else if (ih.Input = "h") {
      
    }
    else if (ih.Input = "j") {
      SendInput("{#}")
    }
    else if (ih.Input = "k") {
      SendInput("{$}")
    }
    else if (ih.Input = "l") {
      SendInput("{%}")
    }
    else if (ih.Input = ";") {
      SendInput("{&}")
    }
    else if (ih.Input = ":") {
      SendInput("{~}")
    }
    else if (ih.Input = "n") {
      
    }   
    ih.Stop()
    return
}

; --------------------------------------------
; テンプレ
; --------------------------------------------
WaitForKeyInput_templete() {
    global ih
    
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}", "E")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
        key := ih.EndKey
        if (key = "RAlt") {   ; 右Alt
          MsgBox("右Altが押されたよ！")
        }
        else if (key = "LShift") { ; 左Shift
          MsgBox("LShiftが押されたよ！")
        }
        else if (key = "Tab") {
          MsgBox("Tabが押されたよ！")
        }
        ih.Stop()
        return
    }
    ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
    ; 入力されたキーに応じて処理を分岐
    if (ih.Input = "t") {
      
    }
    else if (ih.Input = "r") {
      
    }
    else if (ih.Input = "q"){
      
    }
    else if (ih.Input = "e") {
      
    }
    else if (ih.Input = "w") {
      
    }
    else if (ih.Input = "g") {
      
    }
    else if (ih.Input = "f") {
      
    }
    else if (ih.Input = "a") {
      
    }
    else if (ih.Input = "d") {
      
    }
    else if (ih.Input = "s") {
      
    }
    else if (ih.Input = "b") {
      
    }
    else if (ih.Input = "v") {
      
    }
    else if (ih.Input = "c") {
      
    }
    else if (ih.Input = "z") {
      
    }
    else if (ih.Input = "x") {
      
    }
    else if(ih.Input = "y") {
      
    }
    else if(ih.Input = "u") {
      
    }
    else if(ih.Input = "i") {
      
    }
    else if(ih.Input = "o") {
      
    }
    else if(ih.Input = "p") {
            
    }
    else if (ih.Input = "h") {
      
    }
    else if (ih.Input = "j") {
      
    }
    else if (ih.Input = "k") {
      
    }
    else if (ih.Input = "l") {
      
    }
    else if (ih.Input = ";") {
      
    }
    else if (ih.Input = ":") {
      
    }
    else if (ih.Input = "n") {
      
    }
    ih.Stop()
    return
}

WaitForKeyInput_templete_v2() {
    global ih, isWaitingInput
    isWaitingInput := true ; 他のスペース系スクリプトを一時停止
    ; 1. ツールチップを表示（マウスカーソルのそばに出現します）
    IH_TipWaiting("モード名")

    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}", "ES")
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機

    if IH_EndWait("モード名")
        return

    ; 2. 入力が終わったら、ツールチップを消す（空の文字を送ると消えます）
    ; ToolTip()
    isWaitingInput := false
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (ih.EndReason = "EndKey") {
      key := ih.EndKey
      if (key = "RAlt") {   ; 右Alt
        MsgBox("右Alt検知")
      }
      else if (key = "LShift") { ; 左Shift
        MsgBox("LShift検知")
      }
      else if (key = "Tab") {
        MsgBox("Tab検知")
      }
      else if (key = "Space") {
        MsgBox("{Spaceキー検知")
      }
      else if (key = "sc079") {
        MsgBox("{変換キー検知}")
      }
      else if (key = "sc07B") {
        MsgBox("無変換キー検知")
      }
      else if (key = "sc070") {
        MsgBox("カタカナひらがなローマ字キー検知")
      }
      ih.Stop()
      return
    }
  ; MsgBox("入力されたキー: [" ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
  ; 入力されたキーに応じて処理を分岐
  if (ih.Input = "t") {
    
  }
  else if (ih.Input = "r") {
    
  }
  else if (ih.Input = "q")
  {
    
  }
  else if (ih.Input = "e") {
    
  }
  else if (ih.Input = "w") {
    
  }
  else if (ih.Input = "g") {
    
  }
  else if (ih.Input = "f") {
    
  }
  else if (ih.Input = "a") {
    
  }
  else if (ih.Input = "d") {
    
  }
  else if (ih.Input = "s") {
    
  }
  else if (ih.Input = "b") {
    
  }
  else if (ih.Input = "v") {
    
  }
  else if (ih.Input = "c") {
    
  }
  else if (ih.Input = "z") {
    
  }
  else if (ih.Input = "x") {
    
  }
  else if(ih.Input = "y") {
    
  }
  else if(ih.Input = "u") {
    
  }
  else if(ih.Input = "i") {
    
  }
  else if(ih.Input = "o") {
    
  }
  else if(ih.Input = "p") {
    
  }
  else if (ih.Input = "h") {
    
  }
  else if (ih.Input = "j") {
    
  }
  else if (ih.Input = "k") {
    
  }
  else if (ih.Input = "l") {
    
  }
  else if (ih.Input = ";") {
    
  }
  else if (ih.Input = ":") {
    
  }
  else if (ih.Input = "n") {
    
  }
  else if (ih.Input = "\") {
    
  }
  ih.Stop()
  return
}