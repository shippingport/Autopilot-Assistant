<#
.Synopsis
    Importeerd wifi via xml.
    24 november 2021 Christian Wedema

.EXAMPLE
    ./Import-WiFiProfiles.ps1
    ./Import-WiFiProfiles.ps1 -Connect $true -Profile WiFi1
    ./Import-WiFiProfiles.ps1 -Connect $true -SSID AirportWiFi
#>

param ([bool]$Connect,
       [string]$Profile,
       [string]$SSID)

Write-Host "Installing Wi-Fi profiles..."
Get-ChildItem $PSScriptRoot | Where-Object {$_.extension -eq ".xml"} | ForEach-Object {netsh wlan add profile filename=($PSScriptRoot+"\"+$_.name); Write-Host "Imported $_"; $script:WiFiProfileName = $_}

# Remove the '.xml' from the profile name
$WiFiProfileName -Replace ".{4}$"

if($PSBoundParameters.ContainsKey('Connect'))
{
    if($PSBoundParameters.ContainsKey('Profile')) {
        Write-Host "Connecting with profile $Profile"
        netsh wlan connect name="$Profile"
    } elseif(!([string]::IsNullOrEmpty($WiFiProfileName))-and (!($PSBoundParameters.ContainsKey('Profile')))) {
        Write-Host "Connecting with profile $WiFiProfileName"
        netsh wlan connect name="$WiFiProfileName"
        } else {
            Write-Host "Connecting with profile $Profile"
            netsh wlan connect name="$Profile"
        }
    }
    elseif($PSBoundParameters.ContainsKey('SSID')) {
        Write-Host "Connecting with SSID $SSID"
        netsh wlan connect ssid="$SSID"
    }
    else {
        Write-Warning "I need to known what network to connect to! Please tell me using -Profile or -SSID."
}
