# Declare variables -Most unused but in future can be used to create a dynamic script.
$ComputerName = $env:COMPUTERNAME + '$' # this is what we look for in AD.
$CleanComputer = $env:COMPUTERNAME
$SiteCode = $env:SITECODE
$DC = $env:DC
$Username = $env:USERNAME

$isTrolley = (IsMobile).Trolley
$isStudent = (IsMember -GroupName "5180GG_UsrStudent")

Function IsMember ($GroupName, $User = $env:username, $Type = "User") { 
    # Function to check if $User is a member of security group $GroupName
    # Uses ADSI because most machines won't have the ActiveDirectory import module
    
    $returnVal = $False
    $strSiteOU = $env:SITEOU
    $strDistrictOU = $env:DISTRICTOU
    $strRegionCode = $env:REGIONCODE
    $strSearchBase = "LDAP://OU=$strSiteOU,OU=$strDistrictOU,DC=$strRegionCode,DC=eq,DC=edu,DC=au"
  # $Type can be used to specify Computer as our object 
    $strFilter = "(&(objectCategory=$Type)(samAccountName=$User))"
 
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher($strSearchBase)
    $objSearcher.Filter = $strFilter
 
    $objPath = $objSearcher.FindOne()
    $objUser = $objPath.GetDirectoryEntry()
    $DN = $objUser.distinguishedName
    
    $strGrpFilter = "(&(objectCategory=group)(name=$GroupName))"
    $objGrpSearcher = New-Object System.DirectoryServices.DirectorySearcher($strSearchBase)
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
            }
    } else {
        $returnVal = $False
    }
    
    return $returnVal
}

Function IsMobile(){
    $returnVal = $False
    $User = $env:COMPUTERNAME + "$"
    $strSiteOU = $env:SITEOU
    $strDistrictOU = $env:DISTRICTOU
    $strRegionCode = $env:REGIONCODE
    $strSearchBase = "LDAP://OU=$strSiteOU,OU=$strDistrictOU,DC=$strRegionCode,DC=eq,DC=edu,DC=au"
    $strFilter = "(&(objectCategory=Computer)(samAccountName=$User))"
 
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher($strSearchBase)
    $objSearcher.Filter = $strFilter
 
    $objPath = $objSearcher.FindOne()
    $objUser = $objPath.GetDirectoryEntry()
    $DN = $objUser.distinguishedName
    
    $mobileProperties = @{
        Staff = $DN.Contains("Mobile Staff")
        Student = $DN.Contains("Mobile Students")
    Lab = ($DN.Contains("C3") -or $DN.Contains("C7") -or $DN.Contains("SMC2"))
        Trolley = If ($DN -like "*2008_Trolleys*") { $True } Else { $False }
    }

    LogItem $DN
    LogItem $mobileProperties
    
    return $mobileProperties
}

Function MapDriveForGroup($Letter, $Path, $GroupName, $User = $env:username){
    If (IsMember $GroupName $User) {
      $strLetter = $Letter + ":"
      net use $strLetter $Path /PERSISTENT:NO
      LogItem("Mapped $Letter for $env:username")
    }
}

Function LogItem {
    Param ([string]$LogEntry)
    $LogFile = "$env:HOMEDRIVE\Logs\PowerShell-LogonLog.txt"
    $TimeStamp = Get-Date -Format "HH:mm:ss"
    Add-Content "$LogFile" -value "$TimeStamp - $LogEntry"
}
LogItem 'Started PowerShell Script'

# Execute PaperCut
if(IsMember -GroupName '7575GG_UsrStaff'){
Invoke-Expression "\\EQSUN75750002\pcclient\win\pc-client-local-cache.exe --silent -- minimized --cache D:\PapercutClientCache"
}

MapDriveForGroup -Letter 'G' -Path "\\eqsun7575001\Data\Curriculum" -GroupName "7575GG_UsrStudent"
MapDriveForGroup -Letter 'T' -Path '\\eqsun7575001\Data\Curriculum' -GroupName '7575GG_UsrTeachers'
MapDriveForGroup -Letter 'O' -Path '\\eqsun7575001\Folio$' -GroupName '7575GG_UsrStaff'
MapDriveForGroup -Letter 'U' -Path "\\eqsun7575001\$env:username$\Curriculum" -GroupName "GG_UsrStudent Support"

#MapDriveForGroup -Letter 'G' -Path "\\eqsun7575001\Data\Curriculum" -GroupName '5603GG_RoamingStaff'
#MapDriveForGroup -Letter 'T' -Path "\\eqsun7575001\Data\Curriculum" -GroupName '5603GG_RoamingStaff'