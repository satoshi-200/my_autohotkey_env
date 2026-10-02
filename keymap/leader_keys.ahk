#Requires AutoHotkey v2.0
;==============================================================================
; leader_keys.ahk
; 起点キー（リーダーキー）を押して離したあと、次に押したキーで機能を分ける割り当て表
;   main.ahk のホットキーから呼ばれ、Lib の各機能を呼び出す「呼び出し元」
;     CapsLock          … WaitForKeyInput_for_Caps_1level()
;     Space + F         … WaitForKeyInput_for_Space_and_f_1level()
;     Space + A         … WaitForKeyInput_Input_letter_only_lefthand_and_symbols()
;     カタカナひらがな  … WaitForKeyInput_kata_hira_romeji()
;   共通部品（ih・待機表示・キャンセル判定）は Lib/key_wait.ahk
;   Fn / Ctrl / Alt / Win 付きの入力モードは Lib/oneshot_modifiers.ahk
;==============================================================================

; 使う部品（単体で開いたときもエディタが関数を見つけられるように。同じファイルは 1 度しか読まれない）
#Include %A_LineFile%\..\..\Lib\key_wait.ahk
#Include %A_LineFile%\..\..\Lib\oneshot_modifiers.ahk
#Include %A_LineFile%\..\..\Lib\text_input.ahk
#Include %A_LineFile%\..\..\Lib\system_utils.ahk
#Include %A_LineFile%\..\..\Lib\multi_clipboard.ahk
#Include %A_LineFile%\..\..\Lib\mouse_cursor.ahk
#Include %A_LineFile%\..\..\Lib\quick_menu.ahk

;------------------------------------------------------------------------------
; 起点キー（Space+F / Space+A は hold_keys.ahk の Space レイヤーから呼ぶ）
;------------------------------------------------------------------------------
#HotIf !isWaitingInput
sc03A:: WaitForKeyInput_for_Caps_1level()        ; CapsLock
sc070:: WaitForKeyInput_kata_hira_romeji()       ; カタカナひらがな
#HotIf

;------------------------------------------------------------------------------
; 割り当て表
;------------------------------------------------------------------------------
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
      return  ; 未割り当て（モニター移動は r へ移した）
    }
    else if (ih.Input = "r") {
      ; SendInput("#{Down}")
      WindowMonitor_Show()  ; ウィンドウを別のモニターへ（r：次、Shift+r：前）system_utils.ahk
    }
    else if (ih.Input = "q")
    {
      ; SendInput("#{Up}")
      WindowResizer_Show()  ; ウィンドウの大きさ変更（w：大きく、e：小さく）system_utils.ahk
    }
    else if (ih.Input = "e") {
      AppSwitcher_Show(false, "w")  ; アプリ切り替え（e：次、w：前）system_utils.ahk
    }
    else if (ih.Input = "w") {
      TabPageSwitcher_Show()  ; タブ・ページ切り替え（f/a：次/前のタブ、d/s：次/前のページ）system_utils.ahk
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
      QM_DesktopMenu_Show() ; 仮想デスクトップメニュー quick_menu.ahk
    }
    else if (ih.Input = "s") {
      ; WaitForKeyInput_call_Ctrl_Fnkeys()
    }
    else if (ih.Input = "b") {
      CheckContent()  ; multi_clipboard.ahk の関数
    }
    else if (ih.Input = "v") {
      ; PasteText() ; multi_clipboard.ahk の関数
      return
    }
    else if (ih.Input = "c") {
      ; SaveText() ; multi_clipboard.ahk の関数
      return
    }
    else if (ih.Input = "z") {
      ; ClearBox()  ; multi_clipboard.ahk の関数
      return
    }
    else if (ih.Input = "x") {
      ; CutAndSaveText()  ; multi_clipboard.ahk の関数
      return
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
      QuickMenu_Show() ; クイックメニュー
    }
    else if (ih.Input = "k") {
      ; AlwaysOnTop_Release()
      QM_SymbolMenu_Show()
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
      WaitForKeyInput_call_CtrlNum_keys()  ; Ctrl + 数字（左手で入力）oneshot_modifiers.ahk
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