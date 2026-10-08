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
;   処理は「送るキーの文字列」か「呼び出す関数」。"" は未割り当て（空きが分かるように主要なキーはすべて書く）
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
        ; --- 数字列 ---
        "1",  "",
        "2",  "",
        "3",  "",
        "4",  "",
        "5",  "",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",                        ; ￥ / ろ：マルチクリップボードを全消去
        ; --- 上段 ---
        "q",  WindowResizer_Show,                   ; ウィンドウの大きさ
        "w",  QM_DesktopMenu_Show,                  ; 仮想デスクトップメニュー
        "e",  () => AppSwitcher_Show(false, "w"),   ; アプリ切り替え（e：次、w：前）
        "r",  WindowMonitor_Show,                   ; ウィンドウを別のモニターへ（r：次、Shift+r：前）
        "t",  "",
        "y",  "",
        "u",  QuickPalette_Show,                    ; コマンドパレット
        "i",  Oneshot_AltChar,                      ; Alt + 文字キー
        "o",  Oneshot_CtrlShiftChar,                ; Ctrl + Shift + 文字キー
        "p",  "",
        "@",  "",
        "[",  "",
        ; --- 中段 ---
        "a",  "",
        "s",  "",
        "d",  TabPageSwitcher_Show,                 ; タブ・ページ切り替え
        "f",  Oneshot_Fn,                           ; Fn キー
        "g",  "{Enter}",
        "h",  "{Enter}",
        "j",  QuickMenu_Show,                       ; クイックメニュー
        "k",  QM_SymbolMenu_Show,                   ; 記号メニュー
        "l",  Oneshot_CtrlChar,                     ; Ctrl + 文字キー
        ";",  Oneshot_WinChar,                      ; Win + 文字キー
        ":",  "",
        "]",  "",
        ; --- 下段 ---
        "z",  "",
        "x",  "",
        "c",  "",
        "v",  "",
        "b",  Mouse_ToggleDrag,                     ; ドラッグ開始／解除
        "n",  Mouse_ToggleDrag,
        "m",  "",
        ",",  Oneshot_CtrlNum,                      ; Ctrl + 数字キー（左手で入力）
        ".",  Oneshot_CtrlNum,
        "/",  "")
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
        ; --- 数字列 ---
        "1",  "",
        "2",  "",
        "3",  "",
        "4",  "!{F4}",
        "5",  "",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",
        ; --- 上段 ---
        "q",  "^{Home}",                            ; 文書の先頭
        "w",  "{Home}",                             ; 行頭
        "e",  "{End}",                              ; 行末
        "r",  "^{End}",                             ; 文書の末尾
        "t",  "",
        "y",  () => Text_InsertDate("yyyy/MM/dd HH:mm:ss"),
        "u",  () => Text_InsertDate("yyyy/MM/dd"),
        "i",  () => Text_InsertDate("yy/MM/dd"),
        "o",  () => Text_InsertDate("yyyyMMdd"),
        "p",  () => Text_InsertDate("yyMMdd_"),     ; Obsidian のページ名用
        "@",  "",
        "[",  Window_CloseAndFocus,                 ; ウィンドウを閉じてカーソル下にフォーカス
        ; --- 中段 ---
        "a",  "{LWin}",
        "s",  "{LCtrl}",
        "d",  "{LAlt}",
        "f",  Mouse_ContextMenu,                    ; 右クリックメニュー
        "g",  "",
        "h",  QM_DateMenu_Show,                     ; 日付・時刻のメニュー（時刻の書式も選べる）
        "j",  "+{Enter}",
        "k",  "^{Enter}",
        "l",  "!{Enter}",
        ";",  "",
        ":",  "",
        "]",  Window_CloseAndFocus,
        ; --- 下段 ---
        "z",  "",
        "x",  "",
        "c",  "",
        "v",  "",
        "b",  "",
        "n",  "",
        "m",  "",
        ",",  "",
        ".",  "",
        "/",  "")
    Leader_Run("Space + F", keys)
}

; 右手側の文字・記号を左手で入力する
Leader_SpaceA() {
    static keys := Leader_Keys(
        ; --- 数字列 ---
        "1",  "{0}",
        "2",  "{9}",
        "3",  "{8}",
        "4",  "{7}",
        "5",  "{6}",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",
        ; --- 上段 ---
        "q",  "{p}",
        "w",  "{o}",
        "e",  "{i}",
        "r",  "{u}",
        "t",  "{y}",
        "y",  "",
        "u",  "{|}",
        "i",  "{~}",
        "o",  "{!}",
        "p",  "{^}",
        "@",  "{\}",
        "[",  "",
        ; --- 中段 ---
        "a",  "{Space}",
        "s",  "{l}",
        "d",  "{k}",
        "f",  "{j}",
        "g",  "{h}",
        "h",  "",
        "j",  "{#}",
        "k",  "{$}",
        "l",  "{%}",
        ";",  "{&}",
        ":",  "{~}",
        "]",  "",
        ; --- 下段 ---
        "z",  "",
        "x",  "",
        "c",  "",
        "v",  "{m}",
        "b",  "{n}",
        "n",  "",
        "m",  "",
        ",",  "",
        ".",  "",
        "/",  "")
    static specials := Map(
        0x79, Text_CapitalizeNext)                  ; 変換：次の 1 文字を大文字に
    Leader_Run("Space + A：左手で文字・記号", keys, specials)
}

; 遠いキー（y / u / o / p）を近いキーで入力する
Leader_Kana() {
    static keys := Leader_Keys(
        ; --- 数字列 ---
        "1",  "",
        "2",  "",
        "3",  "",
        "4",  "",
        "5",  "",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",
        ; --- 上段 ---
        "q",  "",
        "w",  "",
        "e",  "",
        "r",  "",
        "t",  "",
        "y",  "",
        "u",  "",
        "i",  "",
        "o",  "",
        "p",  "",
        "@",  "",
        "[",  "",
        ; --- 中段 ---
        "a",  "",
        "s",  "",
        "d",  "",
        "f",  "",
        "g",  "",
        "h",  "",
        "j",  "{y}",
        "k",  "{u}",
        "l",  "{o}",
        ";",  "{p}",
        ":",  "",
        "]",  "",
        ; --- 下段 ---
        "z",  "",
        "x",  "",
        "c",  "",
        "v",  "",
        "b",  "",
        "n",  "",
        "m",  "",
        ",",  "",
        ".",  "",
        "/",  "")
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
        if !(action is String)
            action()
        else if (action != "")
            SendInput(action)
    }
    ih.Stop()
}
