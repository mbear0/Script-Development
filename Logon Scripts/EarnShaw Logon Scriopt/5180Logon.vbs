'Create a session
Dim oShell, appCmd
Set oShell = CreateObject("WScript.Shell")
'Call Powershell with appropriate session variables
appCmd = "powershell -ExecutionPolicy Bypass -file " & Replace(WScript.ScriptFullName, ".vbs", ".ps1")
oShell.Run appCmd, 0, false
' False as the last parameter because we want to execute ASYNC to speed up logon times.
WScript.quit(0)