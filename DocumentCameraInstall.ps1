<#

CFT Setup Script for Griffin State School
Written by mbear0 on the 27/07/2017

#>

#Function declarations
<#Function Find-IpevoPresenter(){
    $check = Get-WmiObject -Class Win32Reg_AddRemovePrograms | Select-Object DisplayName | Where-Object DisplayName -Like "*IpevoPresenter*"
    if($check -eq $null){
        Write-Verbose 'IpevoPresenter is missing from system commencing install.'
    }Else{
        Write-Verbose 'IpevoPresenter is already installed exiting script.'
        $wshell = New-Object -ComObject Wscript.Shell
        $wshell.Popup('IpevoPresenter is already installed, exiting.',0,'Done',0x1)
        Exit 0
    }
}#>#End Find-IpevoPresenter 
Function Install-IpevoPresenter(){
    #Set-Location -Path $env:TEMP
    Write-Host '====================================================='
    Write-Host 'Ipevo Document Camera Setup for Griffin State School'
    Write-Host 'Please Be patient Software is installing'
    Write-Host '====================================================='
    Start-Process -FilePath msiexec.exe -Wait -ArgumentList '/i Presenter.msi /qn'

}#End Install-IpevoPresenter

Function Use-Proxy{
$ProxyAddress = 'http://9339proxy.sun.eq.edu.au:8080'
$ProxyCredentials = Get-Credential
$null = & netsh('winhttp','set','proxy',$ProxyAddress)
$webclient = New-Object -TypeName System.Net.WebClient
$webclient.Proxy.Credentials = $ProxyCredentials

}#End InstallGet-ProxyCred

#Main
#Find-IpevoPresenter
#Use-Proxy
Install-IpevoPresenter
$wshell = New-Object -ComObject Wscript.Shell
$wshell.Popup('IpevoPresenter has been installed.',0,'Done',0x1)