<#
.Synopsis
    Runs Windows Update.

    24 november 2021 Shippingport

.EXAMPLE
    ./Run-WUAgent.ps1
#>

Write-Host "Starting Windows Update..."
Register-PSRepository -Default -Confirm:$false
Install-Module PSWindowsUpdate -Force -Confirm:$False
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Confirm:$false
