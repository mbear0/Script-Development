Function IsMember ($GroupName, $User = $env:username, $Type = 'User') 
{ 
    Write-Debug 'Function to check if $User is a member of security group $GroupName'
    Write-Debug  "Uses ADSI because most machines won't have the ActiveDirectory import module"
    
    $returnval = $False
    $siteOU = $env:SITEOU
    $districtOU = $env:DISTRICTOU
    $regioncode = $env:REGIONCODE
    $searchbase = "LDAP://OU=$siteOU,OU=$districtOU,DC=$regioncode,DC=eq,DC=edu,DC=au"
	# $Type can be used to specify Computer as our object 
    $filter = "(&(objectCategory=$Type)(samAccountName=$User))"
 
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher($searchbase)
    $objSearcher.Filter = $filter
 
    $objPath = $objSearcher.FindOne()
    $objUser = $objPath.GetDirectoryEntry()
    $DN = $objUser.distinguishedName
    
    $strGrpFilter = "(&(objectCategory=group)(name=$GroupName))"
    $objGrpSearcher = New-Object System.DirectoryServices.DirectorySearcher($searchbase)
    $objGrpSearcher.Filter = $strGrpFilter
    
    $objGrpPath = $objGrpSearcher.FindOne()
    
    If (!($objGrpPath -eq $Null)){
        $objGrp = $objGrpPath.GetDirectoryEntry()
        
        $grpDN = $objGrp.distinguishedName
        $ADVal = [ADSI]"LDAP://$DN"
        
        if ($ADVal.memberOf.Value -eq $grpDN){
                $returnval = $True
            } else {
                $returnval = $False
            }
    } else {
        $returnval = $False
    }
    
    return $returnval
}

Function IsMobile()
{
    $returnval = $False
    $User = $env:COMPUTERNAME + '$'
    [string]$siteOU = $env:SITEOU
    $districtOU = $env:DISTRICTOU
    $regioncode = $env:REGIONCODE
    $searchbase = "LDAP://OU=$siteOU,OU=$districtOU,DC=$regioncode,DC=eq,DC=edu,DC=au"
    $filter = "(&(objectCategory=Computer)(samAccountName=$User))"
 
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher($searchbase)
    $objSearcher.Filter = $filter
 
    $objPath = $objSearcher.FindOne()
    $objUser = $objPath.GetDirectoryEntry()
    $DN = $objUser.distinguishedName
    
    $mobileProperties = @{
        Staff = $DN.Contains('Mobile Staff')
        Student = $DN.Contains('Mobile Students')
		Lab = ($DN.Contains('C3') -or $DN.Contains('C7') -or $DN.Contains('SMC2'))
        Trolley = If ($DN -like '*2008_Trolleys*') { $True } Else { $False }
    }

    LogItem $DN
    LogItem $mobileProperties
    
    return $mobileProperties
}

Function MapDriveForGroup($Letter, $Path, $GroupName, $User = $env:username)
{
    If (IsMember $GroupName $User) {
		# With PowerShell 3.0 the following is applicable:
         New-PSDrive -Name $Letter -PSProvider 'FileSystem' -Root $Path -Persist
		# But, since most machines are 2.0 we must use:
		#$strLetter = $Letter + ":"
		#net use $strLetter $Path /PERSISTENT:NO
    }
}

Function LogItem {
    Param ([string]$LogEntry)
    $LogFile = 'C:\Logs\PowerShell-LogonLog.txt'
    $TimeStamp = Get-Date -Format 'HH:mm:ss'
    Add-Content "$LogFile" -value "$TimeStamp - $LogEntry"
}

<#
Function LogItem($Text) {
    Write-Host $Text
    Add-Content "C:\Logs\PowerShell-LogonLog.txt" "$Text `r`n"
    # Removed event log functionality at this stage.
    # New-EventLog -Source "LogonScript" -LogName "Application" -ErrorAction SilentlyContinue
    # Write-EventLog -LogName Application -Source LogonScript -Message $Text -EventId 0 -EntryType Information
}
#>

Function IsBYOx() {
	$web = New-Object System.Net.WebClient
	$strUserName = $env:USERNAME
	
	$apiEndpoint = "http://ayrshs-byox.noq.eq.edu.au/api/v2/IsBYOx/$strUserName"

	$web.Headers.Add('User-Agent', 'BYOxCheck/1.0.0.0')
	$web.Headers.Add('Content-Type', 'application/json')
	
	$jsonResult = $web.DownloadString($apiEndpoint) | ConvertFrom-Json
	
	return $jsonResult.IsBYOx
}

Function LogItemToWeb($Category, $Text) {
	# Execute Event Logger
	
	$Username = (Get-WmiObject -Query 'Select * from Win32_ComputerSystem').UserName.Split('\')[1] # splits domain from user
	
	if ($Username -eq '') {
		# Username is blank, use env variable.
		$Username = $env:USERNAME
	}
	
	$SerialNumber = (Get-WmiObject -Class Win32_SystemEnclosure).SerialNumber
	$Hostname = (Get-WmiObject -Class Win32_ComputerSystem).Name # Has no $ on the end.

	If (($SerialNumber -eq "Chassis Serial Number") -or ([String]::IsNullOrWhiteSpace($SerialNumber))) {
	    write-debug 'Serial Number is stored in the Bios retry serial number grab'
	    $SerialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
	}

	# Log our event to our API endpoint.

	$web = New-Object System.Net.WebClient
	$eventEndpoint = "http://EQNOQ2008002.noq.eq.edu.au/InsightPublic/api/Event/CreateEvent"
	
	# Replace macros in string.
	$Text = $Text.Replace('[Username]', $Username)
	$Text = $Text.Replace('[Computer]', $ComputerName)
	$Text = $Text.Replace('[Serial_Number]', $SerialNumber)
	
	# Make this one last
	$Text = $Text.Replace(" ", "%20")

	$postData = @{
	    "Hostname" = $Hostname # no $ on the end
	    "Serial_Number" = $SerialNumber
	    "Category" = $Category
	    "Data" = $Text
	    "Time" = (Get-Date).Ticks.ToString()
	    "Username" = $Username
	}

	$postString = ''
	
	foreach ($key in $postData.Keys) {
		$keyValue = $postData[$key]
		$postString += "$key=$keyValue&"

        # Log Key, Value.
        # For troubleshooting event service if issues.
        LogItem "$key = $keyValue"
	}

	$web.Headers.Add('User-Agent', 'InsightLogonClient/1.0.0.0')
	$web.Headers.Add('Content-Type', 'application/x-www-form-urlencoded')

	# Change second parameter to be encoded string.
	$webResponse = $web.UploadString($eventEndpoint, $postString)

    LogItem $webResponse
}

<#
# Utility function for producing XAML dialog boxes.
#>
function Convert-XAMLtoWindow
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $XAML,
         
        [string[]]
        $NamedElements,
         
        [switch]
        $PassThru
    )
     
    Add-Type -AssemblyName PresentationFramework
     
    $reader = [XML.XMLReader]::Create([IO.StringReader]$XAML)
    $result = [Windows.Markup.XAMLReader]::Load($reader)
    foreach($Name in $NamedElements)
    {
        $result | Add-Member NoteProperty -Name $Name -Value $result.FindName($Name) -Force
    }
     
    if ($PassThru)
    {
        $result
    }
    else
    {
        $result.ShowDialog()
    }
}

function Get-DamagePrompt() {
    $xaml = @'
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d"
        Title="Laptop Damage Report" Height="350" Width="525" WindowStyle="None" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label x:Name="lblTitle" Content="Laptop Damage Report" HorizontalAlignment="Center" Margin="10,10,0,0" VerticalAlignment="Top" FontSize="22" FontWeight="Bold"/>
        <TextBlock x:Name="txtWarning" HorizontalAlignment="Center" Margin="10,55,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="52" Width="495"><Run Text="Before the "/><Run Text="login process completes, you are asked to confirm there is no damage to the device when you received it.  If you do find damage, please indicate the type, and provide further information.  When complete, return the device to your teacher."/></TextBlock>
        <RadioButton x:Name="chkYesDamage" Content="Yes" HorizontalAlignment="Left" Margin="18,139,0,0" VerticalAlignment="Top" GroupName="IsDamage" />
        <Label x:Name="lblYesNoQuestion" Content="Is there any damage to this device? (Keyboard, Screen, Graffiti)" HorizontalAlignment="Left" Margin="12,113,0,0" VerticalAlignment="Top" FontWeight="Bold"/>
        <RadioButton x:Name="chkNoDamage" Content="No" HorizontalAlignment="Left" Margin="75,139,0,0" VerticalAlignment="Top" GroupName="IsDamage" />
        <Button x:Name="btnConfirm" IsEnabled="False" Content="Confirm Details" HorizontalAlignment="Center" Margin="0,0,0,15" VerticalAlignment="Bottom" Width="490" Height="40" FontWeight="Bold" FontSize="20"/>
        <Grid x:Name="gridExtendedDetails" HorizontalAlignment="Center" Height="124" Margin="0,161,0,0" VerticalAlignment="Top" Width="517" Visibility="Hidden">
            <Label x:Name="lblDamageQuestion" Content="What sort of Damage?" HorizontalAlignment="Left" Margin="10,0,0,0" VerticalAlignment="Top" FontWeight="Bold"/>
            <ComboBox x:Name="cmbDamageType" HorizontalAlignment="Left" Margin="18,25,0,0" VerticalAlignment="Top" Width="160" >
                <ComboBoxItem Content="Damaged Keyboard" Tag="Keyboard-Damaged"/>
                <ComboBoxItem Content="Cracked Screen" Tag="LCD-Cracked" />
                <ComboBoxItem Content="Graffiti/Major Scratches" Tag="Cosmetic-Major" />
                <ComboBoxItem Content="Minor Scratches" Tag="Cosmetic-Minor" />
                <ComboBoxItem Content="Other" Tag="Other" />
            </ComboBox>
            <Grid HorizontalAlignment="Center" Height="59" Margin="0,0,0,10" VerticalAlignment="Bottom" Width="517">
                <TextBox x:Name="txtComment" HorizontalAlignment="Center" Height="42" Margin="17,10,10,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="490" ToolTip="asdasdasd"/>
                <TextBlock x:Name="txtCommentPlaceholder" HorizontalAlignment="Right" Margin="0,0,15,10" TextWrapping="Wrap" Text="Enter a short comment in this box." VerticalAlignment="Bottom" RenderTransformOrigin="0.489,0.504" Foreground="Gray"/>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

    # Do not move indent of trailing '@
    # Yes, polluting the global space -- but for a good reason.

    $window = Convert-XAMLtoWindow -XAML $xaml -NamedElements 'chkYesDamage','chkNoDamage','cmbDamageType','txtComment','btnConfirm','gridExtendedDetails' -PassThru

    $window.btnConfirm.add_Click({
        [Object]$sender = $args[0]
        [Windows.RoutedEventArgs]$e = $args[1]

        # Do okay options here.

        $window.Close()
    })

    $window.chkYesDamage.add_Checked({
        [Object]$sender = $args[0]
        [Windows.RoutedEventArgs]$e = $args[1]

        # Event Triggers when "Yes" is ticked.
        $gExtended = $window.FindName('gridExtendedDetails')

        $gExtended.Visibility = [Windows.Visibility]::Visible
    })

    $window.chkNoDamage.add_Checked({
        [Object]$sender = $args[0]
        [Windows.RoutedEventArgs]$e = $args[1]

        # Event Triggers when "Yes" is ticked.
        $gExtended = $window.FindName('gridExtendedDetails')
        $btnConfirm = $window.FindName('btnConfirm')

        $gExtended.Visibility = [Windows.Visibility]::Hidden
        $btnConfirm.IsEnabled = $True
    })

    $window.txtComment.add_GotFocus({
        [Object]$sender = $args[0]
        [Windows.RoutedEventArgs]$e = $args[1]

        $txtPlaceHolder = $window.FindName('txtCommentPlaceholder')
        $txtPlaceHolder.Visibility = [Windows.Visibility]::Collapsed
    })

    $window.cmbDamageType.add_SelectionChanged({
        [Object]$sender = $args[0]
        [Windows.Controls.SelectionChangedEventArgs]$e = $args[1]

        # Enable button.
        $btnConfirm = $window.FindName('btnConfirm')
        $btnConfirm.IsEnabled = $True
    })

    $window.txtComment.add_LostFocus({
        [Object]$sender = $args[0]
        [Windows.RoutedEventArgs]$e = $args[1]
        
        $txtComment = $window.FindName('txtComment')
        $txtPlaceHolder = $window.FindName('txtCommentPlaceholder')

        if ([String]::IsNullOrEmpty($txtComment.Text)) {
            $txtPlaceHolder.Visibility = [Windows.Visibility]::Visible
        }
    })

    $null = $window.ShowDialog()

    return [PSCustomObject]@{
        IsDamage=$window.chkYesDamage.IsChecked;
        DamageType=$window.cmbDamageType.SelectedValue.Tag;
        Details=$window.txtComment.Text;
    }
}

function Get-BYOxWindow() {
    $xaml = @'
    <Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d"
        Title="BYOx Notification" Height="220.482" Width="361.446" WindowStyle="ToolWindow" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label x:Name="lblHeading" Content="BYOx" HorizontalAlignment="Center" Margin="0,5,0,0" VerticalAlignment="Top" FontWeight="Bold" FontSize="24"/>
        <TextBox x:Name="textBox" HorizontalAlignment="Center" Height="86" Margin="10,51,10,0" TextWrapping="Wrap" Text="The school system shows that you have joined a BYOx device to the network previously.  Please ensure that you bring it as frequently as possible in order to free up laptop trolleys for people who need them." VerticalAlignment="Top" Width="272" TextAlignment="Center" BorderThickness="0"/>
        <Button x:Name="btnConfirm" Content="OK" HorizontalAlignment="Center" Margin="0,0,0,20" VerticalAlignment="Bottom" Width="75" IsDefault="True" FontWeight="Bold"/>
    </Grid>
</Window>
'@

    $window = Convert-XAMLtoWindow -XAML $xaml -NamedElements 'btnConfirm' -PassThru

    $window.btnConfirm.add_Click({
        [Object]$sender = $args[0]
        [Windows.RoutedEventArgs]$e = $args[1]

        # Do okay options here.

        $window.Close()
    })

    $null = $window.ShowDialog()
}

# Set variables
$ComputerName = $env:COMPUTERNAME + "$" # this is what we look for in AD.
$CleanComputer = $env:COMPUTERNAME
$SiteCode = $env:SITECODE
$DC = $env:DC
$Username = $env:USERNAME

$isMobileStaff = (IsMobile).Staff
$isMobileStudent = (IsMobile).Student
$isTrolley = (IsMobile).Trolley
$isStudent = (IsMember -GroupName "2008GG_UsrStudent")

LogItem 'Started PowerShell Script'

# Execute PaperCut
 '\\EQNOQ2008007\PCClient\win\pc-client-local-cache.exe --silent --minimized --cache D:\PaperCutClientCache'

# Misc Groups
MapDriveForGroup -Letter "G" -Path "$env:DC\Data\Curriculum" -GroupName "2008GG_UsrSubmissions"

# Teacher Group
MapDriveForGroup -Letter "U" -Path "\\EQNOQ2008003\UsrHome$\Curriculum" -GroupName "2008GG_UsrTeachers"
MapDriveForGroup -Letter "Z" -Path "\\EQNOQ2008003\PhotoCommon" -GroupName "2008GG_UsrYeardisk"
MapDriveForGroup -Letter "Z" -Path "\\EQNOQ2008003\PhotoCommon" -GroupName "2008GG_UsrStaff"
MapDriveForGroup -Letter "G" -Path "$env:DC\Data" -GroupName "5599GG_RoamingStaff"

# Log that a user logged onto the machine.
LogItemToWeb -Category "Logon-PSH" -Text "[Username] logged on to [Computer]"

# Check for BYOx.
If (IsBYOx -eq $True) {
	# User is BYOx.
	Get-BYOxWindow
    LogItemToWeb -Category "User-BYOx" -Text "[Username] has a BYOx device.  Notified that they should bring the device on a regular occasion."
	LogItem "User is BYOx"
} else {
	LogItem "User is not BYOx"
}

# Show laptop 
if (($isStudent -eq $True) -and ($isTrolley -eq $True)) {
    $wResult = Get-DamagePrompt

    If (($wResult -eq $Null) -or ($wResult.IsDamage -eq $false)) {
        LogItemToWeb -Category "Damage-None" -Text "[Username] recorded as confirming no damage on device."
        LogItem $wResult
    } else {
        # Set category.
        $strCategory = "Damage-" + $wResult.DamageType
        LogItemToWeb -Category $strCategory -Text "Comment from [Username]: $($wResult.Details)"
        LogItem $wResult
    }
} else {
    LogItem "Is Student: $isStudent"
    LogItem "Is Trolley: $isTrolley"
}

<#
# Now Check for ABTutor
$bAbInstalled = Test-Path "C:\Program Files\ABTutor\"

If ($bAbInstalled -eq $True) {
	# Check for Status of ABClient
	
	$bABClientRunning = (Get-Service -Name ABClient -ErrorAction SilentlyContinue).Status -eq "Running"
	
	If ($bABClientRunning -ne $true) {
		# Perhaps make a web notification
		LogItem "[WARN] ABTutor is not running on this client."
		LogItemToWeb -Category "ABTutor" -Text "ABTutor is not running on [Computer]"
	}
} else {
	If (IsMember "2008GG_UsrStudent") {
		LogItem "[WARN] ABTutor is not installed on this client."
		LogItemToWeb -Category "ABTutor" -Text "ABTutor is not installed on [Computer]"
	}
}
#>

# Grab MAC Addresses and UUID
$macAddresses = Get-WmiObject Win32_NetworkAdapter | Where-Object{ $_.PhysicalAdapter -eq $True } | Select-Object -ExpandProperty MACAddress
$strMac = ""
$macAddresses | ForEach-Object{ $strMac += $_ + "|" }
$strUUID = Get-WmiObject Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
LogItemToWeb -Category "OAMPS" -Text $strMac
LogItemToWeb -Category "OAMPS-UUID" -Text $strUUID

# Check for failed drives (or failing)
$driveEnum = Get-WmiObject -Class Win32_DiskDrive

foreach ($drive in $driveEnum) {
	switch ($drive.Status) {
	{ ($_ -eq "Error") -or ($_ -eq "Degraded") -or ($_ -eq "Pred Fail") -or ($_ -eq "NonRecover") }
	{
		LogItemToWeb -Category "HDD-Fail" -Text "A SMART error state has been logged on [Computer]: $_"
		$driveStatus = $_
		
		# Show to the user.
		[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
		[Windows.Forms.MessageBox]::Show("Hi there! Your hard drive has reported to Windows that it is probably failing.  Please backup your data and see Brent ASAP. Status reported was: $driveStatus")
	}
	default {
		LogItem "[INFO] Completed HDD Check"
	}
	}
}