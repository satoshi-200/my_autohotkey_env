#Requires AutoHotkey v2.0

Paste_string(signature){					;指定した文字列をpasteする
	A_Clipboard := signature
	SendInput("^v")
}

SendInput_char_without_switching_IME(char){
	if(IME_GET() = 0){
		IME_SET(0)
		SendInput(char)
		Sleep(100) 			; - の後のスペースが全角になるのを防ぐため
		IME_SET(0)
	}
	else{
		IME_SET(0) 
		SendInput(char)
		Sleep(100) 			; - の後のスペースが全角になるのを防ぐため
		IME_SET(1)
	}
}


Input_current_Date1(){						;現在の日付時刻を入力する（yyyy/MM/dd HH:mm:ss形式）
	CurrentDateTime := FormatTime(, "yyyy/MM/dd HH:mm:ss")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date2(){						;現在の日付を入力する（yyyy/MM/dd形式）
	CurrentDateTime := FormatTime(, "yyyy/MM/dd")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date3(){						;現在の日付を入力する（yy/MM/dd形式）
	CurrentDateTime := FormatTime(, "yy/MM/dd")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date4(){						;現在の日付を入力する（yyyyMMdd形式）
	CurrentDateTime := FormatTime(, "yyyyMMdd")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date5(){						;現在の日付を入力する　obsidian_pagetitle用　　（yyyyMMdd_形式）
	CurrentDateTime0 := FormatTime(, "yyMMdd_")
	SendInput_char_without_switching_IME(CurrentDateTime0) ;現在の日時を入力する
}
Input_current_Time1(){						;現在の時刻を入力する(HH:mm)
	CurrentDateTimeSub := FormatTime(, "HH:mm")
	SendInput_char_without_switching_IME(CurrentDateTimeSub) ;現在の日時を入力する
}