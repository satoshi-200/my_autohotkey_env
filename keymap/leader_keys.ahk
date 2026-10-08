#Requires AutoHotkey v2.0
;==============================================================================
; leader_keys.ahk
; 起点キー（リーダーキー）を押して離したあと、次に押したキーで機能を分ける割り当て表
;   CapsLock          … Leader_Caps()
;   Space + F         … Leader_SpaceF()   （hold_keys.ahk の Space レイヤーから呼ぶ）
;   Space + A         … Leader_SpaceA()   （同上）
;   カタカナひらがな  … Leader_Kana()
;
; 割り当ての書き方（各関数の中の表）
;   keys     … 文字キー → 処理（大文字・小文字は区別しない）
;   specials … 特殊キーのスキャンコード → 処理（Tab 0x0F / Space 0x39 / 変換 0x79 / 無変換 0x7B / かな 0x70）
;   処理は「送るキーの文字列」か「呼び出す関数」。表にないキーは何もしない
;==============================================================================
#Include %A_LineFile%\..\..\Lib\key_wait.ahk
#Include %A_LineFile%\..\..\Lib\oneshot_modifiers.ahk
#Include %A_LineFile%\..\..\Lib\text_input.ahk
#Include %A_LineFile%\..\..\Lib\system_utils.ahk
#Include %A_LineFile%\..\..\Lib\multi_clipboard.ahk
#Include %A_LineFile%\..\..\Lib\mouse_cursor.ahk
#Include %A_LineFile%\..\..\Lib\quick_menu.ahk

;------------------------------------------------------------------------------
; 起点キー（Space+F / Space+A は hold_keys.ahk から呼ぶ）
;------------------------------------------------------------------------------
#HotIf !isWaitingInput
sc03A:: Leader_Caps()                               ; CapsLock
sc070:: Leader_Kana()                               ; カタカナひらがな
#HotIf

; 無変換は hold_keys.ahk の「vk1D & ○」のプレフィックスとして止められ InputHook に届かないので、ホットキーで渡す
#HotIf isWaitingInput && ih.InProgress
vk1D:: IH_StopWithKey("sc07B")
#HotIf

; 大文字入力モードの終了（これらもプレフィックスなので InputHook に届かない）
#HotIf UpperMode_IsOn()
vk1D:: UpperMode_Stop()
vk1C:: UpperMode_Stop()
vk20:: UpperMode_Stop(), SendInput("{Space}")
vk1C & b:: UpperMode_Stop(), SendInput("{F8}")      ; 組み合わせが発動すると上の vk1C:: は発動しない
vk1C & n:: UpperMode_Stop(), SendInput("{F9}")
#HotIf

;------------------------------------------------------------------------------
; 割り当て表
;------------------------------------------------------------------------------
Leader_Caps() {
    static keys := Leader_Keys(
        "r",  WindowMonitor_Show,                   ; ウィンドウを別のモニターへ（r：次、Shift+r：前）
        "q",  WindowResizer_Show,                   ; ウィンドウの大きさ
        "e",  () => AppSwitcher_Show(false, "w"),   ; アプリ切り替え（e：次、w：前）
        "w",  QM_DesktopMenu_Show,                  ; 仮想デスクトップメニュー
        "d",  TabPageSwitcher_Show,                 ; タブ・ページ切り替え
        "f",  Oneshot_Fn,                           ; Fn キー
        "l",  Oneshot_CtrlChar,                     ; Ctrl + 文字キー
        "o",  Oneshot_CtrlShiftChar,                ; Ctrl + Shift + 文字キー
        "i",  Oneshot_AltChar,                      ; Alt + 文字キー
        ";",  Oneshot_WinChar,                      ; Win + 文字キー
        ",",  Oneshot_CtrlNum,                      ; Ctrl + 数字キー（左手で入力）
        ".",  Oneshot_CtrlNum,
        "u",  QuickPalette_Show,                    ; コマンドパレット
        "j",  QuickMenu_Show,                       ; クイックメニュー
        "k",  QM_SymbolMenu_Show,                   ; 記号メニュー
        "b",  Mouse_ToggleDrag,                     ; ドラッグ開始／解除
        "n",  Mouse_ToggleDrag,
        "\",  Clip_ClearAll,                        ; マルチクリップボードを全消去
        "g",  "{Enter}",
        "h",  "{Enter}")
    static specials := Map(
        0x0F, WindowMonitor_Show,                   ; Tab：ウィンドウを別のモニターへ（Tab：次、Shift+Tab：前）
        0x39, Ime_Alnum,                            ; Space：IME を半角英数に
        0x79, Ime_Hiragana,                         ; 変換：IME をひらがなに
        0x7B, UpperMode_Start,                      ; 無変換：大文字入力モード
        0x70, Text_CapitalizeNext)                  ; かな：次の 1 文字を大文字に
    Leader_Run("Caps", keys, specials, true)
}

Leader_SpaceF() {
    static keys := Leader_Keys(
        "q",  "^{Home}",                            ; 文書の先頭 / 末尾
        "r",  "^{End}",
        "w",  "{Home}",                             ; 行頭 / 行末
        "e",  "{End}",
        "j",  "+{Enter}",
        "k",  "^{Enter}",
        "l",  "!{Enter}",
        "a",  "{LWin}",
        "s",  "{LCtrl}",
        "d",  "{LAlt}",
        "f",  Mouse_ContextMenu,                    ; 右クリックメニュー
        "y",  () => Text_InsertDate("yyyy/MM/dd HH:mm:ss"),
        "u",  () => Text_InsertDate("yyyy/MM/dd"),
        "i",  () => Text_InsertDate("yy/MM/dd"),
        "o",  () => Text_InsertDate("yyyyMMdd"),
        "p",  () => Text_InsertDate("yyMMdd_"),     ; Obsidian のページ名用
        "[",  Window_CloseAndFocus,                 ; ウィンドウを閉じてカーソル下にフォーカス
        "]",  Window_CloseAndFocus,
        "4",  "!{F4}")
    Leader_Run("Space + F", keys)
}

; 右手側の文字・記号を左手で入力する
Leader_SpaceA() {
    static keys := Leader_Keys(
        "t", "{y}",  "r", "{u}",  "e", "{i}",  "w", "{o}",  "q", "{p}",
        "g", "{h}",  "f", "{j}",  "d", "{k}",  "s", "{l}",  "a", "{Space}",
        "b", "{n}",  "v", "{m}",
        "u", "{|}",  "i", "{~}",  "o", "{!}",  "p", "{^}",
        "j", "{#}",  "k", "{$}",  "l", "{%}",  ";", "{&}",
        "@", "{\}",  ":", "{~}",
        "1", "{0}",  "2", "{9}",  "3", "{8}",  "4", "{7}",  "5", "{6}")
    static specials := Map(
        0x79, Text_CapitalizeNext)                  ; 変換：次の 1 文字を大文字に
    Leader_Run("Space + A：左手で文字・記号", keys, specials)
}

; 遠いキー（y / u / o / p）を近いキーで入力する
Leader_Kana() {
    static keys := Leader_Keys(
        "j", "{y}",  "k", "{u}",  "l", "{o}",  ";", "{p}")
    Leader_Run("カタカナひらがな", keys)
}

;------------------------------------------------------------------------------
; 共通処理
;------------------------------------------------------------------------------
LEADER_END_KEYS := "{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}"
LEADER_KEY_NAMES := Map(0x138, "右Alt", 0x2A, "LShift", 0x0F, "Tab", 0x39, "Spaceキー"
    , 0x79, "変換キー", 0x7B, "無変換キー", 0x70, "カタカナひらがなキー")

; 文字キーの割り当て表を作る（大文字・小文字を区別しない）
Leader_Keys(pairs*) {
    m := Map()
    m.CaseSense := false
    m.Set(pairs*)
    return m
}

; 次のキーを待ち、表に従って処理する
;   forcedAsSpecial … ホットキーから渡された無変換も特殊キーとして扱う（Caps のみ）
Leader_Run(mode, keys, specials := 0, forcedAsSpecial := false) {
    if !IH_WaitNext(mode, , LEADER_END_KEYS)
        return
    endKey := forcedAsSpecial ? IH_EndKeyOf() : (ih.EndReason = "EndKey" ? ih.EndKey : "")
    if (endKey != "") {
        sc := GetKeySC(endKey)
        if (specials && specials.Has(sc))
            specials[sc]()
        else if LEADER_KEY_NAMES.Has(sc)
            ToolTip(LEADER_KEY_NAMES[sc] "検知")    ; 未割り当ての特殊キー（動作確認用）
    }
    else if keys.Has(ih.Input) {
        action := keys[ih.Input]
        if (action is String)
            SendInput(action)
        else
            action()
    }
    ih.Stop()
}
