#Requires AutoHotkey v2.0

Launch_copilot_on_msedge(){					;microsoft edge上のcopilotページを開く
	Run("msedge.exe `"https://www.bing.com/search?q=Bing+AI&showconv=1&FORM=hpcodx`"") ; "msedge.exe"はMicrosoft Edgeの実行ファイル名です。Copilot pageを開きます
	return
}
Launch_folder_explorer_at_shortcut_list_web_dir(){
	Run("explorer `"C:\Users\KNK07559\Documents\shortcut_list(web_dir)`"")
}

execute_app(){
	SendInput("!{F4}")
	FocusUnderCursor()
}