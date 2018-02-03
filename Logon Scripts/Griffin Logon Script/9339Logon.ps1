#Function Declarations
Function IsMember{ 
  Param([string]$GroupName, $User = $env:username, [string]$Type = 'User')
    # Function to check if $User is a member of security group $GroupName
    # Uses ADSI because most machines won't have the ActiveDirectory import module
    
    $returnVal = $False
    $strSiteOU = $env:SITEOU
    $strDistrictOU = $env:DISTRICTOU
    $strRegionCode = $env:REGIONCODE
    $strSearchBase = "LDAP://OU=$strSiteOU,OU=$strDistrictOU,DC=$strRegionCode,DC=eq,DC=edu,DC=au"
  # $Type can be used to specify Computer as our object 
    $strFilter = "(&(objectCategory=$Type)(samAccountName=$User))"
 
    $objSearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList ($strSearchBase)
    $objSearcher.Filter = $strFilter
 
    $objPath = $objSearcher.FindOne()
    $objUser = $objPath.GetDirectoryEntry()
    $DN = $objUser.distinguishedName
    
    $strGrpFilter = "(&(objectCategory=group)(name=$GroupName))"
    $objGrpSearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList ($strSearchBase)
    $objGrpSearcher.Filter = $strGrpFilter
    
    $objGrpPath = $objGrpSearcher.FindOne()
    
    If (!($objGrpPath -eq $Null)){
        $objGrp = $objGrpPath.GetDirectoryEntry()
        
        $grpDN = $objGrp.distinguishedName
        $ADVal = [ADSI]"LDAP://$DN"
        
        if ($ADVal.memberOf.Value -eq $grpDN){
                $returnVal = $True
            } else {
                $returnVal = $False
                LogItem -LogEntry "$env:USERNAME failed to test for group $GroupName"
            }
    } else {
        $returnVal = $False
    }
    
    return $returnVal
}

Function MapDrive{   
  param($Letter,$Path)  
  try{
        LogItem -LogEntry "$Letter has been mapped."
        $strLetter = $Letter + ':'
        net use $strLetter $Path /PERSISTENT:NO}Catch{
        LogItem -LogEntry "$Letter failed to map."}
}

Function LogItem {
    Param ([string]$LogEntry)
    $script:LogFile = "$env:HOMEDRIVE\Logs\PowerShell-LogonLog.txt"
    Add-Content -Path "$LogFile" -Value "$LogEntry"
}

Function CreateLog{
  if (Test-Path -Path "$env:HOMEDRIVE\Logs\PowerShell-LogonLog.txt"){
    Remove-Item -Path "$env:HOMEDRIVE\Logs\PowerShell-LogonLog.txt"
  }
  $TimeStamp = Get-Date -Format g
  Add-Content -Path "$env:HOMEDRIVE\Logs\PowerShell-LogonLog.txt" -Value "Started Powershell Script for $env:USERNAME at $TimeStamp"
}


#Main - Execute code from here.
CreateLog

# Execute PaperCut
Invoke-Expression -Command '\\EQSUN9339001\pcclient\win\pc-client-local-cache.exe --silent -- minimized --cache D:\PapercutClientCache'


# Map Drives for Staff
If(IsMember -GroupName '9339GG_UsrStaff' -User $env:USERNAME){
  MapDrive -Letter 'Q' -Path '\\EQSUN9339001\Apps' -GroupName '9339GG_UsrStaff'
}

#Map Drives for Students
If(IsMember -GroupName '9339GG_UsrStudent' -User $env:USERNAME){
  MapDrive -Letter 'G' -Path '\\EQSUN9339001\Data\Curriculum' -GroupName '9339GG_UsrStudent'
}

#Map Drives for Teachers
If(IsMember -GroupName '9339GG_UsrTeachers' -User $env:USERNAME){
  MapDrive -Letter 'T' -Path '\\EQSUN9339001\Data\Curriculum' -GroupName '9339GG_UsrTeachers'
  MapDrive -Letter 'U' -Path "\\EQSUN9339001\$env:username$" -GroupName '9339GG_UsrTeachers'
}

#Map Drives for Office Staff
if(IsMember -GroupName '9339GG_UsrOffice' -User $env:USERNAME){
  MapDrive -Letter 'O' -Path '\\EQSUN9339001\Data\Coredata\Office' -GroupName '9339GG_UsrOffice'
}

#Map Drives for Roaming Staff
If(IsMember -GroupName '5603GG_RoamingStaff' -User $env:USERNAME){
  MapDrive -Letter 'G' -Path '\\EQSUN9339001\Data' -GroupName '5603GG_RoamingStaff'
  MapDrive -Letter 'M' -Path '\\EQSUN9339001\Menu$' -GroupName '5603GG_RoamingStaff'
  MapDrive -Letter 'N' -Path '\\EQSUN9339001\CDapps$' -GroupName '5603GG_RoamingStaff'
  MapDrive -Letter 'P' -Path '\\EQSUN9339001\Apps' -GroupName '5603GG_RoamingStaff'
}

#Schedule the machine to shutdown at 1am if left on
LogItem -LogEntry 'Scheduled the machine to shutdown at 1am'
if(Get-ScheduledJob -ErrorAction SilentlyContinue | Where-Object Name -Like 'NightlyShutdown'){
}Else{
  $trigger = New-JobTrigger -Once -At '1am'
  $options = New-ScheduledJobOption -StartIfOnBattery -StartIfIdle -WakeToRun -ContinueIfGoingOnBattery
  Register-ScheduledJob -Name NightlyShutdown -ScriptBlock `
{Stop-Computer -Force} -Trigger $trigger -ScheduledJobOption $options}

Add-Content -Path "$env:HOMEDRIVE\Logs\PowerShell-LogonLog.txt" -Value "Powershell Script completed at $TimeStamp"