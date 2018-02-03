'********************************************************************
'**** Local Logon Script for Mango Hill SS ****
'Version 2.1
'
' V2.1	tkspe0	16-12-14: Added O365 code.
'********************************************************************
Option Explicit
Const Domain = "SUN"
Const SiteCode = "7575"

Dim logFile
logFile = "C:\Logs\logonLog.txt"

Dim DomCont1
Dim MbrSver1
'Dim DomCont2
'Dim MbrSver2

Dim SvrCDapps
Dim SvrAltApps
Dim SvrCurric
Dim SvrStuHome

	On Error Resume Next
	DomCont1 = "\\EQ" & Domain & SiteCode & "001"
	MbrSver1 = "\\EQ" & Domain & SiteCode & "002"

	SvrCDapps   = DomCont1    'Server with CDApps$ share in use
	SvrAltApps  = DomCont1    'Server with Alternate (to DomCont1) Apps share in use
	SvrCurric   = DomCont1    'Server with Data\Curriculum share in use
	SvrStuHome  = DomCont1    'Server with Student Home Directories share in use	

	'********************************************************************
	' OFFICE 365 Account processing
	'********************************************************************
	EventLog("Commencing O365 Configuration")
	On Error Resume Next
	Err.Clear
	dim adsys
	Set adsys = CreateObject("ADSystemInfo")
	dim logonsite
	dim regioncode
	logonSite = "7575"
	regioncode = "SUN"

	If GroupTest(logonSite & "GG_OutlookUsers") then
		If GroupTest(logonSite & "GG_MobileUsers") and GroupTest(logonSite & "GG_UsrStaff") then 
			If instr(adsys.ComputerName,"Mobile Staff") then
				'mobile staff user on mobile staff machine
				EventLog("Mobile Staff on Mobile Machine - Running O365 Configuration")
				Runshell("cscript //nologo \\EQ" & regionCode & logonSite & "001\eqlogon\outlookmigration.vbs")
			else
				'mobile staff user on non-staff mobile machine
				EventLog("Mobile Staff on non-mobile Machine - Skipping O365 Configuration")
			End If
		ElseIf GroupTest(logonSite & "GG_MobileUsers") and GroupTest(logonSite & "GG_UsrStudent") then 
			If instr(adsys.ComputerName,"Mobile Students") Then
				'mobile student user on mobile student machine
				EventLog("Mobile Student on a Mobile Machine - Running O365 Configuration")
				Runshell("cscript //nologo \\EQ" & regionCode & logonSite & "001\eqlogon\outlookmigration.vbs")
			else
				'mobile student on non-student mobile machine
				EventLog("Mobile Student on non-mobile Machine - Skipping O365 Configuration")
			End If
		Else
			'non-mobile user
			EventLog("Outlook User on a Desktop Machine - Running O365 Configuration")
			Runshell("cscript //nologo \\EQ" & regionCode & logonSite & "001\eqlogon\outlookmigration.vbs")
		End If
		'non Outlook user
	Else	
		EventLog("Non-Outlook User - Skipping O365 Configuration")
	End If

	If Err.Number <> 0 Then
		EventLog("Error (" & Err.Number & "): " & Err.Description)
		Err.Clear
	Else
		EventLog("Completed O365 Configuration")	
	End If	
	      
	'********************************************************************
	'********************************************************************
	'********************************************************************

	'**********************************************************************
	'*               FYI Main Login Script Mappings                       *
	'**********************************************************************
	'* Members of "GG_UsrStudent" - MapDrive "G", DC & "\Data\Curriculum" *
	'* Members of "GG_UsrStaff"   - MapDrive "M", DC & "\Menu$"           *
	'*                            - MapDrive "G", DC & "\Data"            *
	'* All Users                  - MapDrive "P", DC & "\Apps"            *
	'*                            - MapDrive "N", DC & "\CDApps$"         *
	'**********************************************************************

	'**********************************************************************
	'*               Assigned Drive Letters                               *
	'**********************************************************************
	'* G: User Common Data Drive                                          *
	'* H: User Home Drive                                                 *
	'* I:                                                                 *
	'* J: Reserved - USB pen drive                                        *
	'* K: Reserved - USB pen drive                                        *
	'* L: Reserved - USB pen drive                                        *
	'* M: Domain Controller Menu$ Share (Redirected Menus)                *
	'* N: "CD" Applications (CDApps$ Share)                               *
	'* O:                                                                 *
	'* P: Applications on Domain Controller                               *
	'* Q: Applications on Alternate Server                                *
	'* R: Reserved - Memory Card Reader                                   *
	'* S: Reserved - Memory Card Reader                                   *
	'* T: Alternate User Common Data Drive                                *
	'* U: Student Home Directory Root                                     *
	'* V: Reserved - Memory Card Reader                                   *
	'* W: Reserved - Memory Card Reader                                   *
	'* X: Reserved - Memory Card Reader                                   *
	'* Y: Reserved - Memory Card Reader                                   *
	'* Z: Reserved - Memory Card Reader                                   *
	'**********************************************************************


	If GroupTest("5603GG_RoamingStaff") Then
		MapDrive "G", DomCont1 & "\Data"
		MapDrive "P", DomCont1 & "\Apps"
		MapDrive "M", DomCont1 & "\Menu$\Staff"
		MapDrive "N", DomCont1 & "\CDApps$"
	End If



	If GroupTest(SiteCode & "GG_UsrStudent") then MapDrive "G", SvrCurric & "\Data\Curriculum"
'	If GroupTest(SiteCode & "GG_UsrTeachers") then MapDrive "T", SvrCurric & "\Data\Curriculum"
	If GroupTest(SiteCode & "GG_UsrStaff") then MapDrive "O", DomCont1 & "\Folios$"
	If GroupTest(SiteCode & "GG_UsrStudent Support") then MapDrive "U", SvrStuHome & "\UsrHome$\Curriculum"
	
'	If GroupTest("5603GG_RoamingStaff") then MapDrive "G", SvrCurric & "\Data\Curriculum"
'	If GroupTest("5603GG_RoamingStaff") then MapDrive "T", SvrCurric  & "\Data\Curriculum"
'*	QuickRunShell "\\eqsun7575001\PCClient\win\pc-client-local-cache.exe"*
'	If GroupTest(SiteCode & "GG_OutlookUsers") then QuickRunShell "\\eqsun7575001\eqlogon\SetFreeBusyServer.exe"
'done
	If GroupTest("7575GG_UsrStaff") then
		EventLog("7575Logon - " & time & " - Launching Papercut Client")
		RunShell "\\EQSUN7575019\pcclient\win\pc-client-local-cache.exe --silent --noquit"
  	End If

wscript.quit(0)

'********************************************************************
Private Sub MapDrive(letter, path)
'map a drive
Dim command
Dim errorMessage
Dim return
	letter = letter & ":"
	errorMessage = "Error deleting drive " & letter & " to " & path
	command = "net use " & letter & "  /DELETE"
	return = RunShell(command)
	errorMessage = "Error mapping drive " & letter & " to " & path
	command = "net use " & letter & " " & path & " /PERSISTENT:NO"
	return = RunShell(command)
	If return <> 0  Then wscript.echo errorMessage & "(" & return & ")"
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
Private Function QuickRunShell(ByVal command)
'run a shell command
Dim objShell
Dim return
	on error resume next
	Set objShell = wscript.CreateObject("wscript.Shell")
	RunShell = objShell.Run(command,0,False)
End Function

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
