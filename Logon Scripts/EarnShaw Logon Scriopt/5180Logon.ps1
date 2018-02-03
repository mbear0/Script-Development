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
    #Incase EQ happens may need to map this way:
      $strLetter = $Letter + ":"
      net use $strLetter $Path /PERSISTENT:NO
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
Invoke-Expression "\\EQGBN5180002\pcclient\win\pc-client-local-cache.exe --silent -- minimized --cache D:\PapercutClientCache"


# Map Drives
MapDriveForGroup -Letter "G" -Path "\\EQNOQ2008001\Data\Curriculum" -GroupName "2008GG_UsrSubmissions"

MapDriveForGroup -Letter 'L' -Path 'EQGBN5180001\Log$' -GroupName '5180GG_UsrOffice'
MapDriveForGroup -Letter 'G' -Path '\\EQGBN5180001\Data' -GroupName '5584GG_RoamingStaff'
MapDriveForGroup -Letter 'Y' -Path '\\EQGBN5180001\menu$\Curriculum\Programs' -GroupName '5180GG_UsrStudent'

MapDriveForGroup -Letter 'U' -Path '\\EQGBN5180002\UsrHome$\Curriculum' -GroupName '5180GG_UsrTeachers'
MapDriveForGroup -Letter 'U' -Path '\\EQGBN5180002\UsrHome$\Curriculum' -GroupName '5180GG_UsrAide'
