; ==============================================================================
; 【テンキー・ショートカット設定集（アーカイブ版）】
;
; ●概要
;   テンキー（Numpad）を利用して各種操作を呼び出すためのホットキー設定集です。
;
; ●ステータス: ARCHIVE（アーカイブ）
;   ・現在はメイン環境で使用していない「過去の作例」です。
;   ・設定の参考や、部品取り用として公開しています。
;
; ●主な内容
;   ・テンキーの各キーへの機能割り当て
;   ・NumLockの状態を活用した工夫など
;
; ●環境: AutoHotkey v2.0
; ==============================================================================



; NumlockがONのとき
#HotIf GetKeyState("NumLock", "T")

#HotIf

; NumlockがOFFのとき
#HotIf !GetKeyState("NumLock", "T")

; 単押し
sc04F:: SendInput("{F1}")                    ; 1
sc050:: SendInput("{F2}")                    ; 2
sc051:: SendInput("{F3}")                    ; 3
sc04B:: SendInput("{F4}")                    ; 4
sc04C:: SendInput("{F5}")                    ; 5
sc04D:: SendInput("{F6}")                    ; 6
sc047:: SendInput("{F7}")                    ; 7
sc048:: SendInput("{F8}")                    ; 8
sc049:: SendInput("{F9}")                    ; 9
sc052:: SendInput("{F10}")                   ; 0
sc135:: SendInput("{F11}")                   ; /
sc037:: SendInput("{F12}")                   ; *
; + 同時押し
sc04E & sc04A:: SendInput("{Right}")         ; -
sc04E & sc00F:: SendInput("{Left}")          ; Tab
sc04E & sc135:: SendInput("{Up}")            ; /
sc04E & sc037:: SendInput("{Down}")          ; *
sc04E & sc11C:: SendInput("{Enter}")         ; Enter

; Enter 同時押し -> Shift + Fキー
sc11C & sc04F:: SendInput("+{F1}")                   ; 1
sc11C & sc050:: SendInput("+{F2}")                   ; 2
sc11C & sc051:: SendInput("+{F3}")                   ; 3
sc11C & sc04B:: SendInput("+{F4}")                   ; 4
sc11C & sc04C:: SendInput("+{F5}")                   ; 5
sc11C & sc04D:: SendInput("+{F6}")                   ; 6
sc11C & sc047:: SendInput("+{F7}")                   ; 7
sc11C & sc048:: SendInput("+{F8}")                   ; 8
sc11C & sc049:: SendInput("+{F9}")                   ; 9
sc11C & sc00F:: SendInput("+{F10}")                  ; Tab
sc11C & sc135:: SendInput("+{F11}")                  ; /
sc11C & sc037:: SendInput("+{F12}")                  ; *
sc11C & sc052:: SendInput("+{F10}")                  ; 0
sc11C & sc04E:: SendInput("{Enter}")

; dot 同時押し -> Ctrl + Fキー
sc053 & sc04F:: SendInput("^{F1}")                   ; 1
sc053 & sc050:: SendInput("^{F2}")                   ; 2
sc053 & sc051:: SendInput("^{F3}")                   ; 3
sc053 & sc04B:: SendInput("^{F4}")                   ; 4
sc053 & sc04C:: SendInput("^{F5}")                   ; 5
sc053 & sc04D:: SendInput("^{F6}")                   ; 6
sc053 & sc047:: SendInput("^{F7}")                   ; 7
sc053 & sc048:: SendInput("^{F8}")                   ; 8
sc053 & sc049:: SendInput("^{F9}")                   ; 9
sc053 & sc00F:: SendInput("^{F10}")                  ; Tab
sc053 & sc135:: SendInput("^{F11}")                  ; /
sc053 & sc037:: SendInput("^{F12}")                  ; *
sc053 & sc052:: SendInput("^{F10}")                  ; 0

; - 同時押し
sc04A & sc00F:: Toggle_fold_and_expand_on_vscode()  ; NumpadSub and Tab > vscode 折りたたみ／展開のトグル
sc04A & sc135:: Recursive_fold_on_vscode()      ; NumpadSub and NumpadDiv > vscode 再帰的折りたたみ
sc04A & sc037:: Recursive_expand_on_vscode()    ; NumpadSub and NumpadMult > vscode 再帰的展開
sc04A & sc001:: Fold_all_on_vscode()            ; NumpadSub and NumpadClear > vscode すべて折りたたみ
sc04A & sc00E:: Expand_all_on_vscode()          ; NumpadSub and NumpadBackspace > vscode すべて展開
#HotIf