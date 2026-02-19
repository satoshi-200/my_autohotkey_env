#Requires AutoHotkey v2.0

Toggle_fold_and_expand_on_vscode(){         ;折り畳み、展開のtoggle（vscode）
    SendInput("^k")
    Sleep(200)
    SendInput("^l")
    return
}
Recursive_fold_on_vscode(){                 ;再帰的折りたたみ（vscode）
    SendInput("^k")
    Sleep(100)
    SendInput("^[")
    return
}
Recursive_expand_on_vscode(){               ;再帰的展開（vscode）
    SendInput("^k")
    Sleep(100)
    SendInput("^]")
    return
}
Fold_all_on_vscode(){                       ;全て折りたたむ（vscode）
    SendInput("^k")
    Sleep(200)
    SendInput("^0")
    return
}
Expand_all_on_vscode(){                     ;全て展開する（vscode）
    SendInput("^k")
    Sleep(200)
    SendInput("^j")
    return
}

