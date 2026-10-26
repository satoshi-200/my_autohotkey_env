#Requires AutoHotkey v2.0
;==============================================================================
; chord_keys.ahk
; 変換 → 無変換 の順に押したまま（両方を押している間）、さらに別のキーを押す 3 キーの割り当て
;   無変換 → 変換 の順は chord_ordered_keys.ahk。どちらも、ここに書いていないキーは何も起きない（通常の割り当ても止まる）。
;   AutoHotkey はどちらを起点にするか決まらないので、同じ処理を 2 つの起点に書く：
;     vk1C & キー::
;     vk1D & キー::  処理  ; コメント      （処理は下の行にだけ書く。キー割り当て一覧もこの行を読む）
;   hold_keys.ahk から、通常の「起点 & キー」の割り当てより先に読み込む（同じホットキーは、先に書いた方が優先されるため）。
;   押した順番は、hold_keys.ahk の 2 キーの組み合わせ（vk1C & vk1D / vk1D & vk1C）が記録する（Lib\chord.ahk）。
;==============================================================================
#Include %A_LineFile%\..\..\Lib\chord.ahk

#HotIf !IH_waiting && Chord_Both() && Chord_order = "CD"
vk1C & a::
vk1D & a::  SendInput("^{z}")                       ; 元に戻す
vk1C & f::
vk1D & f::  SendInput("^{y}")                       ; やり直し
vk1C & j::
vk1D & j::  SendInput("+{Enter}")
vk1C & k::
vk1D & k::  SendInput("^{Enter}")
vk1C & l::
vk1D & l::  SendInput("!{Enter}")
vk1C & i::
vk1D & i::  SendInput("^+{Enter}")
#HotIf
