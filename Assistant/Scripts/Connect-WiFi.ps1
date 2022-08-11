<#
.Synopsis
    Imports wifi profile from xml, then connects to this network.
    24 november 2021 Shippingport

.EXAMPLE
    ./Connect-WiFi.ps1
#>


Write-Host "Installing Wi-Fi profile"
$XmlDirectory = ../Resources/
Get-ChildItem $XmlDirectory | Where-Object {$_.extension -eq ".xml"} | ForEach-Object {netsh wlan add profile filename=($XmlDirectory+"\"+$_.name)}

Write-Host "Connecting to Wi-Fi"
netsh wlan connect ssid="<networkname>" name="<networkname>"
