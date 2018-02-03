'**** GenericLocalLogon.vbs ****
'Version 1.1
'Functions:
' This is a base local logon script that can be modified for individual sites.
'This script should be renamed to <sitecode>Logon.vbs and should exist in the EQlogon share of the 1st site DC.
'
'********************************************************************
Option explicit
Dim logFile

logFile = "C:\Logs\logonLog.txt"

'********************************************************************
'e.g. map Z: drive to \\EQDDS0383001\SchoolCDs$:
'MapDrive "Z","\\EQDDS0383001\SchoolCDs$"
'You can write to the event log with: EventLog("<comment>")
'You can perform a user group membership test with: If GroupTest("<groupname>") then....
'********************************************************************

'MapDrive "T","\\<server>\Data\Curriculum"
'MapDrive "U","\\<server>\UsrHome$\Curriculum"








'done
wscript.quit(0)
'********************************************************************
Private Sub MapDrive(letter, path)
'map a drive
Dim command
Dim errorMessage
Dim return
letter = letter & ":"
errorMessage = ""
command = "net use " & letter & " /delete"
return = RunShell(command)
errorMessage = "Error mapping drive " & letter & " to " & path
command = "net use " & letter & " " & path & " /PERSISTENT:NO"
return = RunShell(command)
If return <> 0  Then EventLog(errorMessage & "(" & return & ")")
End Sub
'********************************************************************
Private Function RunShell(ByVal command)
'run a shell command
Dim objShell
Dim return
on error resume next
Set objShell = wscript.CreateObject("wscript.Shell")
RunShell = objShell.Run(command,0,True)
End Function
'********************************************************************
Private Sub EventLog(line)
'write to the logfile (logFile)
Dim objFSO
Dim return
Dim errorMessage
Dim txtStream

On Error Resume next
Set objFSO = CreateObject("Scripting.FileSystemObject")

Set txtStream = objFSO.OpenTextFile(logFile, 8, True)
txtStream.writeline(line)

End Sub
'********************************************************************
Private Function GroupTest(testGroup)
'Checks current user for membership in testGroup
Dim objADInfo       'AD user object
Dim currentUser     'LDAP user object
Dim group		'array of groups
Dim errorMessage

Set objADInfo = CreateObject("ADSystemInfo")

On Error Resume Next

testGroup = LCase(testGroup)

Set currentUser = GetObject("LDAP://" & objADInfo.UserName)

If isArray(currentUser.MemberOf) then
	group = LCase(Join(currentUser.MemberOf))
Else
	group = LCase(currentUser.MemberOf)
End If

If InStr(group, lcase("cn=" & testGroup & ",")) Then
	GroupTest = True
	Exit Function
Else
	GroupTest = False
	Exit Function
End If
End Function
'********************************************************************