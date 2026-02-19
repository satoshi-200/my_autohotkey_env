#Requires AutoHotkey v2.0

; init
SetTimer(CheckPopup,1000)

; gloval variables
global MouseVibrate := false
global MoveRight := false

; method
Popup_Screen_saver(){
    global myGui := Gui()
    myGui.OnEvent("Close", GuiClose)
    myGui.OnEvent("Escape", GuiClose)
    myGui.Add("Text", , "screen saver execute")
    myGui.Add("Button", , "quit").OnEvent("Click", GuiClose)
    myGui.Title := ""
    myGui.Show("w200 h100")
    global MouseVibrate := true
    return
}

GuiClose(*) ; ポップアップを閉じるとき
{
    myGui.Destroy()
    global MouseVibrate := false
    return
}

CheckPopup(){
    if (MouseVibrate)
        {
            MouseGetPos(&xpos, &ypos)
            if (MoveRight)
            {
                MouseMove(xpos + 3, ypos, 0)
                global MoveRight := false
            }
            else
            {
                MouseMove(xpos - 3, ypos, 0)
                global MoveRight := true
            }
        }
}