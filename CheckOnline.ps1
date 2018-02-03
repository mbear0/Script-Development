
$computers = Get-ADComputer -Filter * ForEach ($computer in $computers) {
$client = $Computer.Name
if (Test-Connection -Computername $client -BufferSize 16 -Count 1 -Quiet) {
     Write-Host $client is online
     }
 }