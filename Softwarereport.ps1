if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{Write-Output 'Running as Administrator!'}
else
{Write-Output 'Running Limited!'}

function Find-Folders{
Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    SelectedPath = 'C:\’
}
 
[void]$FolderBrowser.ShowDialog()
$FolderBrowser.SelectedPath
}


#Fetch list of software from registry then write to report file. 
'Retrieving registered software'
$SoftwareList = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher | Out-GridView
#Prompt user for report
[String]$ReportConf = Read-Host -Prompt "Would You Like a text report? y/n"
if($ReportConf -eq 'y'){
[String]$ReportLocation = Find-Folders
$ReportLocation = $ReportLocation + '\Software Report.txt'
[String]$DateStamp = Get-Date
'Report Generated on the ' + $DateStamp | Out-File $ReportLocation
'Computer Name: ' + $env:COMPUTERNAME | Out-File -Append $ReportLocation
Get-NetIPAddress | Select-Object IPAddress,InterfaceIndex | Out-File -Append $ReportLocation
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher | Format-List | Out-File -Append $ReportLocation 
'Report has been placed in ' + $ReportLocation
}
Pause