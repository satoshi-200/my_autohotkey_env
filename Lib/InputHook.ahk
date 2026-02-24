#Requires AutoHotkey v2.0

; InputHookオブジェクトを作成
ih := InputHook("L1")


; ih := InputHook("M")

; 動作チェック用
WaitForKeyInput_show_input(){
  global ih
  ih.Start() ; 入力を開始
  ih.Wait() ; 入力が完了するまで待機
  MsgBox("入力された文字: " ih.Input)
}
; キー入力を待つ関数 1階層目
WaitForKeyInput_for_Caps_1level() {
    ; global ih
    ; 1. 関数が呼ばれるたびに、新しい監視員（インスタンス）を作成する
    local_ih := InputHook()
    ; 特殊キーを「EndKey（終了キー）」として登録
    local_ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "ES")
    ; マウスカーソルの横に状態を表示
    ToolTip("⌨️ キー入力待機中... (Escでキャンセル)")
    
    local_ih.Start()
    local_ih.Wait()
    ; 入力が終わったらすぐにツールチップを消す
    ToolTip()
    ; --- 1. 特殊キー（EndKey）が押された場合の処理 ---
    if (local_ih.EndReason = "EndKey") {
        key := local_ih.EndReason = "EndKey" ? local_ih.EndKey : ""
        ; 画面に何を押したか出す（確認用）
        ToolTip("EndKey検出: " key)
        SetTimer(() => ToolTip(), -1000)
        if (key = "RAlt") {   ; 右Alt
          MsgBox("右Altが押されたよ！")
        }
        else if (key = "LShift") { ; 左Shift
          MsgBox("LShiftが押されたよ！")
        }
        else if (key = "Tab") {
          MsgBox("Tabが押されたよ！")
        }
        else if (key = "Space") {
          turn_on_roman_input_mode()
        }
        else if (key = "vk1C") {
          turn_on_hira_input_mode()
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
        }
        local_ih.Stop()
        return
    }
    ; MsgBox("入力されたキー: [" local_ih.Input "]")  ; 入力されたキーを表示（動作チェック用）
    ; 入力されたキーに応じて処理を分岐
    ; --- 2. 一般キーの判定 ---
    ; もし何も動かない場合は、ここが実行されているかチェックするため、
    ; 一瞬だけツールチップで押された文字を出してみます
    ; ここを if に戻し、else を外します
    if (local_ih.Input != "") {
        ToolTip("一般キー受理: " local_ih.Input)
        SetTimer(() => ToolTip(), -1000)
    }

    ; 全ての if を独立させるか、Inputの中身を順番にチェックします
    ; (さっきの else if だと一番上しか実行されませんでした)
    keyIn := local_ih.Input
    if (KeyIn = "t") {
      Toggle_fold_and_expand_on_vscode()                ; vscode 折りたたみ／展開のトグル
    }
    else if (KeyIn = "r") {
      Recursive_expand_on_vscode()                  ; vscode 再帰的展開
    }
    else if (KeyIn = "q")
    {
      Recursive_fold_on_vscode()                    ; vscode 再帰的折りたたみ
    }
    else if (KeyIn = "e") {
      Expand_all_on_vscode()                      ; vscode すべて展開
    }
    else if (KeyIn = "w") {
      Fold_all_on_vscode()                      ; vscode すべて折りたたみ
    }
    else if (KeyIn = "g") {
      ; SendInput("^{y}")
      SendInput("{Enter}")
    }
    else if (KeyIn = "f") {
      WaitForKeyInput_call_Fnkeys()
      ; Right_click()
    }
    else if (KeyIn = "a") {
      ; SendInput("{LWin}")
      WaitForKeyInput_call_Ctrl_Shift_Fnkeys()
      ; turn_on_roman_input_mode()
    }
    else if (KeyIn = "d") {
      WaitForKeyInput_call_Shift_Fnkeys()
    }
    else if (KeyIn = "s") {
      
      WaitForKeyInput_call_Ctrl_Fnkeys()
    }
    else if (KeyIn = "b") {
      CheckContent()  ; multi_clipboard.ahk の関数
    }
    else if (KeyIn = "v") {
      ; SendInput ("^!{l}")                          ; vscode 次のbookmarkへ移動
      PasteText() ; multi_clipboard.ahk の関数
    }
    else if (KeyIn = "c") {
      ; SendInput ("^!{k}")                          ; vscode bookmark toggle
      SaveText() ; multi_clipboard.ahk の関数
    }
    else if (KeyIn = "z") {
      ClearBox()  ; multi_clipboard.ahk の関数
    }
    else if (KeyIn = "x") {
      ; SendInput ("^!{j}")                          ; vscode 前のbookmarkへ移動
      CutAndSaveText()  ; multi_clipboard.ahk の関数
    }
    else if(KeyIn = "y") {
      ; Input_current_Date1() 
    }
    else if(KeyIn = "u") {
      ; Input_current_Date2()
      ; SendInput("{Ctrl}")
      ; WaitForKeyInput_call_CtrlChar_keys()
    }
    else if(KeyIn = "i") {
      ; Input_current_Date3()
      ; Right_click()
      ; WaitForKeyInput_call_CtrlShiftChar_keys()
      WaitForKeyInput_call_AltChar_keys()
    }
    else if(KeyIn = "o") {
      ; Input_current_Date4()
      ; WaitForKeyInput_call_AltChar_keys()
      WaitForKeyInput_call_CtrlShiftChar_keys()
    }
    else if(KeyIn = "p") {
      ; Input_current_Date5() 
    }
    else if (KeyIn = "h") {
      ; turn_on_roman_input_mode()
      ; WaitForKeyInput_call_CtrlChar_keys()
      ; Capitalize_next_character_you_type()  ;次の文字を大文字に
      ; SendInput("^{z}")
      SendInput("{Enter}")
    }
    else if (KeyIn = "j") {
      turn_on_roman_input_mode()
    }
    else if (KeyIn = "k") {
      turn_on_hira_input_mode()
    }
    else if (KeyIn = "l") {
      ; WaitForKeyInput_call_AltChar_keys()
      ; turn_on_hiragana_input_mode()
      ; toggle_input_mode()
      WaitForKeyInput_call_CtrlChar_keys()
    }
    else if (KeyIn = ";") {
      ; Capitalize_next_character_you_type()  ;次の文字を大文字に
      ; toggle_input_mode()
      WaitForKeyInput_call_WinChar_keys()
    }
    else if (KeyIn = ":") {
      ; turn_on_hiragana_input_mode()               ; ひらがな入力モード
    }
    else if (KeyIn = "n") {
      Capitalize_next_character_you_type()  ;次の文字を大文字に
    }
    ; else if (KeyIn = " ") {
    ;   turn_on_roman_input_mode()                ; ローマ字入力モード
    ; }
    else if (KeyIn = "\") {
      ResetAll()  ; multi_clipboard.ahk
    }
    local_ih.Stop()
}

WaitForKeyInput_for_Space_and_f_1level() {
  global ih
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "E")
    ; ▼▼▼ 1. ここで一時的にキーの割り当てルールをお休みさせる ▼▼▼
    Suspend(True)
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; ▼▼▼ 2. 入力が終わったら、すぐにお休みを解除して元に戻す ▼▼▼
    Suspend(False)
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
        else if (key = "Space") {
          MsgBox("Spaceが押されたよ！")
        }
        else if (key = "vk1C") {
          MsgBox("変換が押されたよ！")
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
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
}

WaitForKeyInput_Input_letter_only_lefthand_and_symbols() {
global ih
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "E")
    ; ▼▼▼ 1. ここで一時的にキーの割り当てルールをお休みさせる ▼▼▼
    Suspend(True)
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; ▼▼▼ 2. 入力が終わったら、すぐにお休みを解除して元に戻す ▼▼▼
    Suspend(False)
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
        else if (key = "Space") {
          MsgBox("Spaceが押されたよ！")
        }
        else if (key = "vk1C") {
          MsgBox("変換が押されたよ！")
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
        }
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
      SendInput("{\}")       
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
      SendInput("{^}")
    }
    else if (ih.Input = ":") {
      SendInput("{~}")
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
}

WaitForKeyInput_call_Fnkeys() { ; キー入力を待つ関数 Fnキー関連
global ih
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "E")
    ; ▼▼▼ 1. ここで一時的にキーの割り当てルールをお休みさせる ▼▼▼
    Suspend(True)
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; ▼▼▼ 2. 入力が終わったら、すぐにお休みを解除して元に戻す ▼▼▼
    Suspend(False)
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
        else if (key = "Space") {
          MsgBox("Spaceが押されたよ！")
        }
        else if (key = "vk1C") {
          MsgBox("変換が押されたよ！")
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
        }
        return
    }

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
}

WaitForKeyInput_call_Shift_Fnkeys() { ; キー入力を待つ関数 Fnキー関連
    global ih
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機

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
}

WaitForKeyInput_call_Ctrl_Fnkeys() {  ; キー入力を待つ関数 Fnキー関連
    global ih
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機

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
}

WaitForKeyInput_call_Ctrl_Shift_Fnkeys() {  ; キー入力を待つ関数 Fnキー関連
    global ih
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機

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
}

WaitForKeyInput_call_CtrlChar_keys() {  ; キー入力を待つ関数 Ctrlキー関連
  global ih
  ih.Start() ; 入力を再開
  ih.Wait() ; 入力が完了するまで待機

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
}

WaitForKeyInput_call_CtrlShiftChar_keys() { ; キー入力を待つ関数 Ctrlキー関連
    global ih
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機

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
    ih.Stop()
}

WaitForKeyInput_call_WinChar_keys() {  ; キー入力を待つ関数 Ctrlキー関連
    global ih
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機

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
    ih.Stop()

}

WaitForKeyInput_call_AltChar_keys() {  ; キー入力を待つ関数 Ctrlキー関連
    global ih
    ih.Start() ; 入力を再開
    ih.Wait() ; 入力が完了するまで待機
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
}

WaitForKeyInput_kata_hira_romeji() {
global ih
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "E")
    ; ▼▼▼ 1. ここで一時的にキーの割り当てルールをお休みさせる ▼▼▼
    Suspend(True)
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; ▼▼▼ 2. 入力が終わったら、すぐにお休みを解除して元に戻す ▼▼▼
    Suspend(False)
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
        else if (key = "Space") {
          MsgBox("Spaceが押されたよ！")
        }
        else if (key = "vk1C") {
          MsgBox("変換が押されたよ！")
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
        }
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
}

WaitForKeyInput_for_pressing_far_keys() {
    global ih
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "E")
    ; ▼▼▼ 1. ここで一時的にキーの割り当てルールをお休みさせる ▼▼▼
    Suspend(True)
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; ▼▼▼ 2. 入力が終わったら、すぐにお休みを解除して元に戻す ▼▼▼
    Suspend(False)
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
        else if (key = "Space") {
          MsgBox("Spaceが押されたよ！")
        }
        else if (key = "vk1C") {
          MsgBox("変換が押されたよ！")
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
        }
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
}

WaitForKeyInput_symbol_keys() {
    global ih
    ; 特殊キーを「EndKey（終了キー）」として登録
    ih.KeyOpt("{Tab}{Esc}{RAlt}{LShift}{Space}{vk1C}{vk1D}", "E")
    ; ▼▼▼ 1. ここで一時的にキーの割り当てルールをお休みさせる ▼▼▼
    Suspend(True)
    ih.Start() ; 入力を開始
    ih.Wait() ; 入力が完了するまで待機
    ; ▼▼▼ 2. 入力が終わったら、すぐにお休みを解除して元に戻す ▼▼▼
    Suspend(False)
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
        else if (key = "Space") {
          MsgBox("Spaceが押されたよ！")
        }
        else if (key = "vk1C") {
          MsgBox("変換が押されたよ！")
        }
        else if (key = "vk1D") {
          MsgBox("無変換が押されたよ！")
        }
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
}