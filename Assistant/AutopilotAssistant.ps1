<#
.Synopsis
    Version 2.0 of Autopilot Assistant, a complete rewrite from version 1.x, now with a GUI!

    Version history
    1.0 - 26 april 2021 - First version
    1.1 - 24 november 2021 - Fixed some small issues, added AIK-enrollment test
    2.0 - 8 august 2022 - Rewrite with multi-threaded GUI using runspaces.

    Shippingport 2022

.EXAMPLE
    ./AutopilotAssistant.ps1
#>

# Load all nessecary assemblies
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Xml")
Add-Type -AssemblyName PresentationFramework

# Start multithreading the UI
$global:SyncHash = [hashtable]::Synchronized(@{})
$UIRunspace = [runspacefactory]::CreateRunspace()
$UIRunspace.ThreadOptions = "ReuseThread"
$UIRunspace.ApartmentState = "STA"
$UIRunspace.Open()
$UIRunspace.SessionStateProxy.SetVariable("SyncHash",$global:SyncHash)

# Runspace for the preflight checklist
$TrafficLightRunspace = [runspacefactory]::CreateRunspace()
$TrafficLightRunspace.ThreadOptions = "ReuseThread"
$TrafficLightRunspace.ApartmentState = "STA"
$TrafficLightRunspace.Open()
$TrafficLightRunspace.SessionStateProxy.SetVariable("SyncHash",$global:SyncHash)

# Code for the UI thread
$PSThread_UI = [powershell]::Create().AddScript({

#region XAML
    # Parse the XAML into a GUI and objects vars
    [xml]$Xaml = @"
    <Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    ResizeMode="NoResize"
    Title="AutoPilot Assistant" Height="450" Width="800">

<Grid>
<!--Left column-->
<Button Content="Import Wi-Fi profile(s)" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Height="32" Width="250"/>
<Button Content="Connect to available Wi-Fi" HorizontalAlignment="Left" Margin="10,47,0,0" VerticalAlignment="Top" Height="32" Width="250"/>

<!--Right column-->
<Button Content="Clear TPM" Name="Button_ClearTPM" HorizontalAlignment="Left" Margin="265,10,0,0" VerticalAlignment="Top" Height="32" Width="250"/>
<Button Content="Initialize TPM" Name="Button_InitTPM" HorizontalAlignment="Left" Margin="265,47,0,0" VerticalAlignment="Top" Height="32" Width="250"/>

<Image Name="Logo" HorizontalAlignment="Right" Height="250" Margin="0,-72,10,0" VerticalAlignment="Top" Width="250" Source="./logo.png" Stretch="Uniform" StretchDirection="Both"/>
    <Separator HorizontalAlignment="Left" Margin="341,187,0,0" VerticalAlignment="Top" Height="8" Width="384" RenderTransformOrigin="0.5,0.5">
        <Separator.RenderTransform>
            <TransformGroup>
                <ScaleTransform/>
                <SkewTransform/>
                <RotateTransform Angle="-90"/>
                <TranslateTransform/>
            </TransformGroup>
        </Separator.RenderTransform>
    </Separator>

    <Grid Margin="545,10,10,10">
        <!--Network indicator-->
        <Ellipse Name="StatusIndicator_NetConnectionAvailable"  HorizontalAlignment="Left" Height="15" Width="15" Margin="4,8,0,0" Fill="Red" VerticalAlignment="Top"/>
        <Label Content="Network connection" HorizontalAlignment="Left" Margin="24,3,0,0" VerticalAlignment="Top" Width="212"/>

        <!--Intune servers pingable-->
        <Ellipse Name="StatusIndicator_IntunePingResponse"  HorizontalAlignment="Left" Height="15" Width="15" Margin="4,34,0,0" Fill="Red" VerticalAlignment="Top"/>
        <Label Content="Intune is pingable" HorizontalAlignment="Left" Margin="24,27,0,0" VerticalAlignment="Top" Width="212"/>

        <!-- Certreq's AIK vertificate request result-->
        <Ellipse Name="StatusIndicator_AIKCertRequestStatus"  HorizontalAlignment="Left" Height="15" Width="15" Margin="4,58,0,0" Fill="Red" VerticalAlignment="Top"/>
        <Label Content="AIK certificate status" HorizontalAlignment="Left" Margin="24,53,0,0" VerticalAlignment="Top" Width="212"/>

        <!-- Unimplemented indicator-->
        <Ellipse Name="StatusIndicator_UnimplementedIndicator"  HorizontalAlignment="Left" Height="15" Width="15" Margin="4,84,0,0" Fill="Orange" VerticalAlignment="Top"/>
        <Label Content="Unimplemented indicator" HorizontalAlignment="Left" Margin="24,79,0,0" VerticalAlignment="Top" Width="212"/>
    </Grid>

    <Label Name="MainStatusMessage" Content="Starting up..." HorizontalAlignment="Left" VerticalAlignment="Bottom" Width="533" Height="28"/>

</Grid>
</Window>
"@
#endregion XAML

    # Start building the UI from XAML
    $XamlReader = (New-Object System.Xml.XmlNodeReader $Xaml)
    $SyncHash.MainWindow = [Windows.Markup.XamlReader]::Load($XamlReader)
    $SyncHash.MainStatusMessage = $SyncHash.MainWindow.FindName("MainStatusMessage")

    # Automatically expose all of our controls and UI elements to the other threads
    $Xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        $SyncHash.($_.Name) = $SyncHash.MainWindow.FindName($_.Name)
    }

    # Show the window
    $syncHash.MainWindow.ShowDialog() | Out-Null
    $syncHash.Error = $Error
})

# Code for the preflight checks
$PSThread_TrafficLightChecks = [powershell]::Create().AddScript({
    $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Running checks..."},9)

    #region Checks
    # Check for active network connections
    $NetworkConnection = Get-NetRoute | Where-Object DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where-Object ConnectionState -eq 'Connected'
    if($NetworkConnection -ne $null) {
        $SyncHash.StatusIndicator_NetConnectionAvailable.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_NetConnectionAvailable.Fill = "Green"},9) # network is up
    } else {
        $SyncHash.StatusIndicator_NetConnectionAvailable.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_NetConnectionAvailable.Fill = "Red"},9) # network is down
    }

    # Check if Intune is pingable
    if(Test-Connection -ComputerName endpoint.microsoft.com -Count 1)
    {
        $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Green"},9)
    }
    else {
        $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Red"},9)
    }

    # Intel Tiger Lake: check if TPM attestation is working or not, otherwise clear TPM manually
    $certreq = (certreq -enrollaik -config '""')
    if(($LastExitCode -eq 0))
    {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Green"},9)
    }
    elseif (($LastExitCode -eq "-2145844848")) {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Orange"},9) # HTTP_BADREQUEST"
    }
    else {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"},9) # Any other error condition
    }
    #endregion checks

    $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Ready."},9)
    $invokePSThread_TrafficLights.IsCompleted($true)
})

# Start the UI thread
$PSThread_UI.Runspace = $UIRunspace
$invoke = $PSThread_UI.BeginInvoke()

# Wait until the final UI element has initialized.
# We have to wait for every object to instantiate, otherwise everything will just error out with a "You cannot call a method on a null-valued expression"
# exception when we try to write to them.
do{
    Start-Sleep -Milliseconds 10
} while (!($SyncHash.MainStatusMessage))

# Update the status line text
# DispatchPriority value '9' is 'normal', which should be OK for our purposes.
$SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Ready."},9)

$PSThread_TrafficLightChecks.Runspace = $TrafficLightRunspace
$invoke_TrafficLights = $PSThread_TrafficLightChecks.BeginInvoke()
