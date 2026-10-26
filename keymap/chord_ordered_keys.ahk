#Requires AutoHotkey v2.0
;==============================================================================
; chord_ordered_keys.ahk
; 無変換 → 変換 の順に押したまま（両方を押している間）、さらに別のキーを押す 3 キーの割り当て
;   変換 → 無変換 の順は chord_keys.ahk。どちらも、ここに書いていないキーは何も起きない（通常の割り当ても止まる）。
;   書き方は chord_keys.ahk と同じ：
;     vk1C & キー::
;     vk1D & キー::  処理  ; コメント      （処理は下の行にだけ書く。キー割り当て一覧もこの行を読む）
;   押した順番は、hold_keys.ahk の「vk1D & vk1C」「vk1C & vk1D」（2 キーの組み合わせ）が Chord_Begin で記録する（Lib\chord.ahk）。
;   2 キーの組み合わせ自体にも処理を割り当てるときは、Chord_Begin の 2 つ目の引数に渡す（3 つ目のキーを押す前に働く）。
;==============================================================================
#Include %A_LineFile%\..\..\Lib\chord.ahk

#HotIf !IH_waiting && Chord_Both() && Chord_order = "DC"
vk1C & f::
vk1D & f::      return                              ; 未割り当て
vk1C & j::
vk1D & j::  SendInput("{#}")
vk1C & k::
vk1D & k::  SendInput("{$}")
vk1C & l::
vk1D & l::  SendInput("{%}")
vk1C & +::
vk1D & +::  SendInput("{&}")
vk1C & p::
vk1D & p::  SendInput("{\}")
vk1C & o::
vk1D & o::  SendInput("{|}")
vk1C & u::
vk1D & u::  SendInput("{``}")
vk1C & i::
vk1D & i::  SendInput("{^}")
#HotIf
