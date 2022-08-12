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
Add-Type -AssemblyName PresentationFramework,PresentationCore

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

    <GroupBox Header="WiFi" Margin="10,4,538,304">
        <Grid Height="86">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="20*"/>
                <ColumnDefinition Width="213*"/>
            </Grid.ColumnDefinitions>
            <Button Content="Import Wi-Fi profile(s)" Name="Button_ImportWiFiXML" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="10,10,0,0" Grid.ColumnSpan="2"/>
            <Button Content="Connect to available Wi-Fi" Name="Button_ConnectToWiFi" HorizontalAlignment="Left" Margin="10,47,0,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="2"/>
        </Grid>
    </GroupBox>


    <!--Right column-->

    <GroupBox Header="TPM" Margin="266,4,282,304">
        <Grid Height="86">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="20*"/>
                <ColumnDefinition Width="213*"/>
            </Grid.ColumnDefinitions>
            <Button Content="Clear TPM" Name="Button_ClearTPM" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="10,10,0,0" Grid.ColumnSpan="2"/>
            <Button Content="Initialize TPM" Name="Button_InitTPM" HorizontalAlignment="Left" Margin="10,47,0,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="2"/>
        </Grid>
    </GroupBox>

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

    <Grid Margin="545,0,0,20">
        <Grid.RowDefinitions>
            <RowDefinition Height="129*"/>
            <RowDefinition Height="73*"/>
        </Grid.RowDefinitions>
        <Label Content="Checklist" HorizontalAlignment="Left" Margin="-9,-4,0,0" VerticalAlignment="Top" Width="248" HorizontalContentAlignment="Left" VerticalContentAlignment="Top" FontSize="16" FontWeight="Normal" FontFamily="Segoe UI Semibold"/>

        <!--Network indicator-->
        <Ellipse Name="StatusIndicator_NetConnectionAvailable"  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,32,0,0" Fill="Red" VerticalAlignment="Top"/>
        <Label Name="Label_NetworkStatus" Content="Checking internet connectivity..." HorizontalAlignment="Left" Margin="17,27,0,0" VerticalAlignment="Top" Width="212"/>

        <!--Intune servers pingable-->
        <Ellipse Name="StatusIndicator_IntunePingResponse"  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,58,0,0" Fill="Red" VerticalAlignment="Top"/>
        <Label Name="Label_IntunePingable" Content="Pinging Intune servers.." HorizontalAlignment="Left" Margin="17,51,0,0" VerticalAlignment="Top" Width="212"/>

        <!-- Certreq's AIK vertificate request result-->
        <Ellipse Name="StatusIndicator_AIKCertRequestStatus" ToolTipService.ToolTip="Red = certificate was not issued. Consider clearing the TPM."  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,82,0,0" Fill="Orange" VerticalAlignment="Top"/>
        <Label Content="AIK certificate status" Name="Label_CertReqLabel" HorizontalAlignment="Left" Margin="17,77,0,0" VerticalAlignment="Top" Width="212"/>

        <!-- AzureADJoined status -->
        <Ellipse Name="StatusIndicator_AzureADJoinedIndicator" ToolTipService.ToolTip="" HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,108,0,0" Fill="Orange" VerticalAlignment="Top"/>
        <Label Content="Azure AD joined status" Name="Label_AzureADJoinStatus" HorizontalAlignment="Left" Margin="17,103,0,0" VerticalAlignment="Top" Width="212"/>
    
        <!--Shutdown and reboot buttons-->
        <Button Content="Reboot" Name="Button_Reboot" HorizontalAlignment="Left" Height="32" Width="106" Margin="0,104,0,0" Grid.Row="1" VerticalAlignment="Top"/>
        <Button Content="Shut down" Name="Button_Shutdown" HorizontalAlignment="Left" Height="32" Width="106" Margin="115,104,0,0" Grid.Row="1" VerticalAlignment="Top"/>

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
        $SyncHash.Label_NetworkStatus.Dispatcher.Invoke([action]{$SyncHash.Label_NetworkStatus.Content = "Internet is connected."},9)

    } else {
        $SyncHash.StatusIndicator_NetConnectionAvailable.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_NetConnectionAvailable.Fill = "Red"},9) # network is down
        $SyncHash.Label_NetworkStatus.Dispatcher.Invoke([action]{$SyncHash.Label_NetworkStatus.Content = "Can't connect to the internet"},9)

    }

    # Check if Intune is pingable
    if(Test-Connection -ComputerName endpoint.microsoft.com -Count 1)
    {
        $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Green"},9)
        $SyncHash.Label_IntunePingable.Dispatcher.Invoke([action]{$SyncHash.Label_IntunePingable.Content = "Intune is pingable"},9)

    }
    else {
        $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Red"},9)
        $SyncHash.Label_IntunePingable.Dispatcher.Invoke([action]{$SyncHash.Label_IntunePingable.Content = "Intune was not pingable."},9)

    }

    $dsregresult = (dsregcmd /status)
    $dsregAzureADJoinedResult = $dsregresult | Select-String -Pattern "AzureADJoined"
    $dsregAzureADJoinedResultTrimmed = $dsregAzureADJoinedResult.ToString().Trim(" ")
    
    if(($dsregAzureADJoinedResultTrimmed -eq "AzureAdJoined : YES" )){
        $dsregTenantName = $dsregresult | Select-String -Pattern "TenantName"
        # this is ugly as sin but it does work...
        # We really should loop trough a chararray but whatever
        $dsregTenantNameTrimmed = $dsregTenantName.ToString().Trim(" ","T","e","n","a","n","t","N","a","m","e"," ",":"," ")

        $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.Fill = "Green"},9)
      # $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.ToolTip.ToolTipService = "Device is joined to tenant " + $dsregTenantNameTrimmed},9)
        $SyncHash.Label_AzureADJoinStatus.Dispatcher.Invoke([action]{$SyncHash.Label_AzureADJoinStatus.Content = "AAD joined to " + $dsregTenantNameTrimmed},9)
    } else {
        $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.Fill = "Red"},9)
        $SyncHash.Label_AzureADJoinStatus.Dispatcher.Invoke([action]{$SyncHash.Label_AzureADJoinStatus.Content = "Device is not AAD joined"},9)
    }



    # Intel Tiger Lake: check if TPM attestation is working or not, otherwise clear TPM manually
    $certreq = (certreq -enrollaik -config '""')
    if(($LastExitCode -eq 0))
    {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Green"},9)
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Green = The certificate was issued. TPM attestation succeeded."},9)
        $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "TPM passed attestation"},9)
    }
    elseif (($LastExitCode -eq "-2145844848")) {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"},9) # HTTP_BADREQUEST"
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Orange = certreq returned HTTP_BADREQUEST."},9)
        $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "Certreq returned HTTP_BADREQUEST"},9)
    }
    elseif (($LastExitCode -eq "-2147024809")) {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"},9) # ACCESS_DENIED"
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Orange = certreq returned ERROR_INVALID_PARAMETER."},9)
        $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "Certreq returned ERROR_INVALID_PARAMETER"},9)
    }
    else {
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"},9) # Any other error condition
        $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "TPM did not pass attestation!"},9)
        # Don't need to update the tooltip here, as red is the default state and is defined in the xaml.
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

$SyncHash.Button_ClearTPM.Add_click({
    $TPMClearResult = [System.Windows.MessageBox]::Show("Are you sure you want to clear the TPM?","Clear TPM?",4)
    if($TPMClearResult -eq 6){ # "6" is the return value for "yes"
        # Testing thingy, don't want to clear my TPM in production
        start powershell { Test-Connection -ComputerName endpoint.microsoft.com -Count 1 }# Clear-Tpm -UsePPI}
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "TPM was cleared. Click reboot to finalize the reset."},9)
    } else {
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Did not clear TPM."},9)
    }
})

$SyncHash.Button_InitTPM.Add_click({
    $TPMClearResult = [System.Windows.MessageBox]::Show("Are you sure you want to initialize the TPM?","Initialize TPM?",4)
    if($TPMClearResult -eq 6){ # "6" is the return value for "yes"
        # Testing thingy, don't want to clear my TPM in production
        start powershell { [System.Windows.MessageBox]::Show("Just kidding!") } # Initialize-Tpm -AllowClear}
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "TPM was initialized. Click reboot to finalize."},9)
    } else {
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Did not initialize TPM."},9)
    }
})
