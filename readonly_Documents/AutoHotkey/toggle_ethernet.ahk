#Requires AutoHotkey v2.0

; Instruction
; Set this as a scheduled task on logon
; Program: pwsh $env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe
; Add arguments: -command "C:\Users\eleung\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe C:\Users\eleung\Documents\AutoHotkey\toggle_ethernet.ahk"
; Tick `Run with highest privileges`

; TODO: One hotkey to toggle on/off

; Ctrl+Alt+Shift+t
; Disable ALL ethernet connection
^+!t::
{
    RunWait 'pwsh -command "Disable-NetAdapter -Name `"*`" -Confirm:$false"'
}

; Ctrl+Alt+Shift+y
; Enable ALL ethernet connection

^+!y::
{
    RunWait 'pwsh -command "Enable-NetAdapter -Name `"*`""'
}