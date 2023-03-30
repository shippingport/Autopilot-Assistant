<#
.Synopsis
    Version 2.0 of Autopilot Assistant, a complete rewrite from version 1.x, now with a GUI!

    Version history
    1.0 - 26 april 2021 - First version
    1.1 - 24 november 2021 - Fixed some small issues, added AIK-enrollment test
    2.0 - 8 august 2022 - Rewrite with multi-threaded GUI using runspaces.
    2.0.1 - 18 febuary 2023 - Redesigned GUI
    2.0.2 - 30 march 2023 - Added new networking and identification features

    Shippingport 2021-2023

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
    Title="AutoPilot Assistant" Height="450" Width="1076">

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="3*"/>
            <ColumnDefinition Width="8*"/>
            <ColumnDefinition Width="29*"/>
            <ColumnDefinition Width="48*"/>
            <ColumnDefinition Width="926*"/>
        </Grid.ColumnDefinitions>
        <!--Left column-->
        <Rectangle Grid.Column="4" HorizontalAlignment="Left" Height="434" Fill="#eff4f9" VerticalAlignment="Center" Width="264" Margin="728,0,0,0"/>

        <!--Left column-->
        <Label Content="1. Prerequisites" HorizontalAlignment="Left" Margin="3,10,0,0" VerticalAlignment="Top" Width="248" HorizontalContentAlignment="Left" VerticalContentAlignment="Top" FontSize="16" FontWeight="Normal" FontFamily="Segoe UI Semibold" Grid.Column="2" Grid.ColumnSpan="3"/>

        <GroupBox Header="Wireless" Margin="6,46,0,226" HorizontalAlignment="Left" Width="250" Grid.ColumnSpan="3" Grid.Column="2">
            <Grid Height="124" HorizontalAlignment="Center" Width="239">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="3*"/>
                    <ColumnDefinition Width="17*"/>
                    <ColumnDefinition Width="21*"/>
                    <ColumnDefinition Width="168*"/>
                    <ColumnDefinition Width="30*"/>
                </Grid.ColumnDefinitions>
                <Button Content="Import Wi-Fi profile(s)" ToolTip="Loads all .xml Wi-Fi profiles from the \WiFi directory." Name="Button_ImportWiFiXMLNetworkProfiles" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="7,10,0,0" Grid.ColumnSpan="4" Grid.Column="1"/>
                <ComboBox Name="Combobox_WiFi" HorizontalAlignment="Left" Margin="7,47,0,0" VerticalAlignment="Top" Width="184" Grid.Column="1" Grid.ColumnSpan="3"/>
                <Button Content="Connect" Name="Button_ConnectToWiFi" HorizontalAlignment="Right" Margin="0,74,16,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="4" Grid.Column="1"/>
                <Button Name="Button_RefreshWiFiProfiles" Grid.Column="3" Content="Q" FontFamily="Wingdings 3" HorizontalAlignment="Left" Margin="158,47,0,0" VerticalAlignment="Top" Height="22" Width="24" Grid.ColumnSpan="2"/>
            </Grid>
        </GroupBox>
        <GroupBox Header="Wired" Margin="6,185,0,84" HorizontalAlignment="Left" Width="250" Grid.ColumnSpan="3" Grid.Column="2">
        <Grid Height="167" HorizontalAlignment="Center" Width="239">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="3*"/>
                <ColumnDefinition Width="17*"/>
                <ColumnDefinition Width="21*"/>
                <ColumnDefinition Width="60*"/>
                <ColumnDefinition Width="108*"/>
                <ColumnDefinition Width="30*"/>
            </Grid.ColumnDefinitions>

            <Button Content="Get network information" Name="Button_GetNetInfo" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="7,10,0,0" Grid.ColumnSpan="5" Grid.Column="1"/>
            <Button Content="Set static network settings" Name="Button_SetNetInfo" HorizontalAlignment="Right" Margin="0,47,16,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="5" Grid.Column="1"/>
            <Button Content="Bounce network" Name="Button_BounceNetwork" HorizontalAlignment="Right" Margin="0,84,16,0" VerticalAlignment="Top" Height="32" Width="212" Grid.ColumnSpan="5" Grid.Column="1"/>
        </Grid>
    </GroupBox>


        <Label Content="2. Enrollment" HorizontalAlignment="Left" Margin="179,10,0,0" VerticalAlignment="Top" Width="248" HorizontalContentAlignment="Left" VerticalContentAlignment="Top" FontSize="16" FontWeight="Normal" FontFamily="Segoe UI Semibold" Grid.Column="4"/>

        <GroupBox Header="Enrollment" Margin="180,46,0,254" HorizontalAlignment="Left" Width="251" Grid.Column="4">
            <Grid Height="86">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="20*"/>
                    <ColumnDefinition Width="213*"/>
                </Grid.ColumnDefinitions>
                <Button Content="Enroll online" Name="Button_EnrollUsingAAD" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="10,10,0,0" Grid.ColumnSpan="2"/>
                <Button Content="Enroll manually" Name="Button_EnrollManually" HorizontalAlignment="Left" Margin="10,47,0,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="2"/>
            </Grid>
        </GroupBox>

        <!--Right column-->

        <Label Content="3. Postenrollment &amp; troubleshooting" HorizontalAlignment="Left" Margin="432,10,0,0" VerticalAlignment="Top" Width="276" HorizontalContentAlignment="Left" VerticalContentAlignment="Top" FontSize="16" FontWeight="Normal" FontFamily="Segoe UI Semibold" Grid.Column="4"/>

        <GroupBox Header="TPM" HorizontalAlignment="Right" Margin="0,46,284,262" Grid.Column="4" Width="246">
            <Grid Height="86">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="0*"/>
                    <ColumnDefinition Width="55*"/>
                    <ColumnDefinition Width="168*"/>
                </Grid.ColumnDefinitions>
                <Button Content="Clear TPM" Name="Button_ClearTPM" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="10,10,0,0" Grid.ColumnSpan="3"/>
                <Button Content="Initialize TPM" Name="Button_InitTPM" HorizontalAlignment="Left" Margin="10,47,0,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="3"/>
            </Grid>
        </GroupBox>

        <Grid Margin="0,10,1,10" Grid.Column="4" HorizontalAlignment="Right" Width="229">
            <Grid.RowDefinitions>
                <RowDefinition Height="129*"/>
                <RowDefinition Height="73*"/>
            </Grid.RowDefinitions>

            <Label Content="Checklist" HorizontalAlignment="Left" Margin="-9,-4,0,0" VerticalAlignment="Top" Width="248" HorizontalContentAlignment="Left" VerticalContentAlignment="Top" FontSize="16" FontWeight="Normal" FontFamily="Segoe UI Semibold"/>
            <Button Name="Button_ChecklistRefresh" Grid.Column="4" Content="Q" HorizontalAlignment="Right" Margin="0,0,0,0" VerticalAlignment="Top" FontFamily="Wingdings 3" Width="17"/>

            <!--Network indicator-->
            <Ellipse Name="StatusIndicator_NetConnectionAvailable"  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,32,0,0" Fill="Yellow" VerticalAlignment="Top"/>
            <Label Name="Label_NetworkStatus" Content="Checking internet connectivity..." HorizontalAlignment="Left" Margin="17,27,0,0" VerticalAlignment="Top" Width="212"/>

            <!--Intune servers pingable-->
            <Ellipse Name="StatusIndicator_IntunePingResponse"  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,58,0,0" Fill="Yellow" VerticalAlignment="Top"/>
            <Label Name="Label_IntunePingable" Content="Pinging Intune servers..." HorizontalAlignment="Left" Margin="17,51,0,0" VerticalAlignment="Top" Width="212"/>

            <!-- Certreq's AIK vertificate request result-->
            <Ellipse Name="StatusIndicator_AIKCertRequestStatus" ToolTipService.ToolTip="Red = certificate was not issued. Consider clearing the TPM."  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,82,0,0" Fill="Yellow" VerticalAlignment="Top"/>
            <Label Content="AIK certificate status" Name="Label_CertReqLabel" HorizontalAlignment="Left" Margin="17,77,0,0" VerticalAlignment="Top" Width="212"/>

            <!-- TPM RSA keygen failure indicator -->
            <Ellipse Name="StatusIndicator_RSAKeygenVulnerability" ToolTipService.ToolTip="Red = your TPM is vulnerable. Update its firmware before continuing."  HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,135,0,0" Fill="Yellow" VerticalAlignment="Top"/>
            <Label Content="RSA keygen" Name="Label_RSAKeygenVulnStatus" HorizontalAlignment="Left" Margin="17,130,0,0" VerticalAlignment="Top" Width="212"/>

            <!-- AzureADJoined status -->
            <Ellipse Name="StatusIndicator_AzureADJoinedIndicator" ToolTipService.ToolTip="" HorizontalAlignment="Left" Height="15" Width="15" Margin="-3,108,0,0" Fill="Yellow" VerticalAlignment="Top"/>
            <Label Content="Azure AD joined status" Name="Label_AzureADJoinStatus" HorizontalAlignment="Left" Margin="17,103,0,0" VerticalAlignment="Top" Width="212"/>

            <!--Shutdown and reboot buttons-->
            <Button Content="Reboot" Name="Button_Reboot" HorizontalAlignment="Left" Height="32" Width="106" Margin="0,104,0,0" Grid.Row="1" VerticalAlignment="Top"/>
            <Button Content="Shut down" Name="Button_Shutdown" HorizontalAlignment="Left" Height="32" Width="106" Margin="115,104,0,0" Grid.Row="1" VerticalAlignment="Top"/>            
        </Grid>

        <Label Name="MainStatusMessage" Content="Starting up..." HorizontalAlignment="Left" VerticalAlignment="Bottom" Width="533" Height="28" Grid.ColumnSpan="5"/>
        <GroupBox Header="Autopilot instructions" Margin="180,185,0,115" HorizontalAlignment="Left" Width="251" Grid.Column="4" Visibility="Hidden">
            <Grid Height="86">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="21*"/>
                    <ColumnDefinition Width="109*"/>
                    <ColumnDefinition Width="109*"/>
                </Grid.ColumnDefinitions>
            </Grid>
        </GroupBox>
        <GroupBox Header="Hardware" Margin="181,155,0,84" HorizontalAlignment="Left" Width="250" Grid.Column="4">
            <Grid Height="167" HorizontalAlignment="Center" Width="239">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="3*"/>
                    <ColumnDefinition Width="17*"/>
                    <ColumnDefinition Width="21*"/>
                    <ColumnDefinition Width="60*"/>
                    <ColumnDefinition Width="108*"/>
                    <ColumnDefinition Width="30*"/>
                </Grid.ColumnDefinitions>
                <Button Content="Get model &amp; serial number" Name="Button_GetHWSerialNumber" HorizontalAlignment="Left" VerticalAlignment="Top" Height="32" Width="213" Margin="7,10,0,0" Grid.ColumnSpan="5" Grid.Column="1"/>
                <Button Content="Get or set computer name" Name="Button_GetOrSetComputerName" HorizontalAlignment="Right" Margin="0,47,16,0" VerticalAlignment="Top" Height="32" Width="213" Grid.ColumnSpan="5" Grid.Column="1"/>
            </Grid>
        </GroupBox>
    </Grid>
</Window>
"@

[xml]$NetworkSettingsXaml = @"
    <Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    ResizeMode="NoResize"
    Title="Network settings" Height="215" Width="330">
    
    <Grid>
        <CheckBox Name="CB_UseDHCP" Content="Use DHCP" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top"/>
        <Label Content="IP address" HorizontalAlignment="Left" Margin="10,36,0,0" VerticalAlignment="Top"/>
        <Label Content="Subnet mask" HorizontalAlignment="Left" Margin="10,62,0,0" VerticalAlignment="Top"/>
        <Label Content="Primary DNS" HorizontalAlignment="Left" Margin="10,88,0,0" VerticalAlignment="Top"/>
        <Label Content="Secondary DNS" HorizontalAlignment="Left" Margin="10,114,0,0" VerticalAlignment="Top"/>
    
        <TextBox Name="IPAddress" HorizontalAlignment="Left" Margin="115,40,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="180"/>
        <TextBox Name="NetMask" HorizontalAlignment="Left" Margin="115,66,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="180"/>
        <TextBox Name="DNSPrimary" HorizontalAlignment="Left" Margin="115,92,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="180"/>
        <TextBox Name="DNSSecondary" HorizontalAlignment="Left" Margin="115,118,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="180"/>
    
        <Button Name="Button_SaveNetworkSettings" Content="Save" HorizontalAlignment="Left" Margin="197,147,0,0" VerticalAlignment="Top" Width="98"/>
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

    $XAMLReaderForNetSettings = (New-Object System.Xml.XmlNodeReader $NetworkSettingsXaml)
    $SyncHash.NetSettingsWindow = [Windows.Markup.XamlReader]::Load($XAMLReaderForNetSettings)
    $NetworkSettingsXaml.SelectNodes("//*[@Name]") | ForEach-Object {
        $SyncHash.($_.Name) = $SyncHash.NetSettingsWindow.FindName($_.Name)
    }

    $syncHash.NetSettingsWindow.ShowDialog() | Out-Null
})

#region Trafficlight-checklist
$PSThread_TrafficLightChecks = [powershell]::Create().AddScript({
    Function RunChecks {
        # Code for the preflight checks  
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Running checks..."})

        #region Checks
        # Check for active network connections
        # A connection with a valid route for 0.0.0.0/0 should be connected to the internet
        $NetworkConnection = Get-NetRoute | Where-Object DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where-Object ConnectionState -eq 'Connected'
        if($NetworkConnection -ne $null) {
            $SyncHash.StatusIndicator_NetConnectionAvailable.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_NetConnectionAvailable.Fill = "Green"}) # network is up
            $SyncHash.Label_NetworkStatus.Dispatcher.Invoke([action]{$SyncHash.Label_NetworkStatus.Content = "Internet is connected"})

        } else {
            $SyncHash.StatusIndicator_NetConnectionAvailable.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_NetConnectionAvailable.Fill = "Red"}) # network is down
            $SyncHash.Label_NetworkStatus.Dispatcher.Invoke([action]{$SyncHash.Label_NetworkStatus.Content = "Can't connect to the internet"})
        }

        # Check if Intune is pingable
        if(Test-Connection -ComputerName endpoint.microsoft.com -Count 1)
        {
            $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Green"})
            $SyncHash.Label_IntunePingable.Dispatcher.Invoke([action]{$SyncHash.Label_IntunePingable.Content = "Intune is pingable"})

        }
        else {
            $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Red"})
            $SyncHash.Label_IntunePingable.Dispatcher.Invoke([action]{$SyncHash.Label_IntunePingable.Content = "Intune was not pingable."})

        }}


        $dsregresult = (dsregcmd /status)
        $dsregAzureADJoinedResult = $dsregresult | Select-String -Pattern "AzureADJoined"
        $dsregAzureADJoinedResultTrimmed = $dsregAzureADJoinedResult.ToString().Trim(" ")

        if(($dsregAzureADJoinedResultTrimmed -eq "AzureAdJoined : YES" )){
            $dsregTenantName = $dsregresult | Select-String -Pattern "TenantName"

            # this is ugly as sin but it does work...
            # We really should loop trough a chararray but whatever
            $dsregTenantNameTrimmed = $dsregTenantName.ToString().Trim(" ","T","e","n","a","n","t","N","a","m","e"," ",":"," ")

            $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.Fill = "Green"})
          # $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.ToolTip.ToolTipService = "Device is joined to tenant " + $dsregTenantNameTrimmed},9)
            $SyncHash.Label_AzureADJoinStatus.Dispatcher.Invoke([action]{$SyncHash.Label_AzureADJoinStatus.Content = "AAD joined to " + $dsregTenantNameTrimmed})
        } else {
            $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.Fill = "Red"})
            $SyncHash.Label_AzureADJoinStatus.Dispatcher.Invoke([action]{$SyncHash.Label_AzureADJoinStatus.Content = "Device is not AAD joined"})
        }

        # Intel Tiger Lake: check if TPM attestation is working or not, otherwise clear TPM manually
        $certreq = (certreq -enrollaik -config '""')
        if(($LastExitCode -eq 0))
        {
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Green"})
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Green = The certificate was issued. TPM attestation succeeded."})
            $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "TPM passed attestation"})
        }
        elseif (($LastExitCode -eq "-2145844848")) {
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"}) # HTTP_BADREQUEST"
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Orange = certreq returned HTTP_BADREQUEST."},9)
            $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "Certreq returned HTTP_BADREQUEST"})
        }
        elseif (($LastExitCode -eq "-2147024809")) {
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"}) # ACCESS_DENIED"
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Orange = certreq returned ERROR_INVALID_PARAMETER."},9)
            $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "Certreq returned ERROR_INVALID_PARAMETER"})
        }
        else {
            $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"}) # Any other error condition
            $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "TPM did not pass attestation!"})
            # Don't need to update the tooltip here, as red is the default state and is defined in the xaml.
        }

        # RSA keygen vulnerability check
        $RSAKeygenCheck = (TpmTool.exe getdeviceinformation) # | Select-Object -Index 14 # 13 in prod
        # Check if the returned string contains 'false', the omission of which should be enough to determine we're vulnerable

        if ($RSAKeygenCheck.Contains("-TPM Has Vulnerable Firmware: False"))
        {
            $SyncHash.StatusIndicator_RSAKeygenVulnerability.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_RSAKeygenVulnerability.Fill = "Green"})
            $SyncHash.StatusIndicator_RSAKeygenVulnerability.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_RSAKeygenVulnerability.ToolTip = "Green = Your TPM is not vulnerable."},9)
            $SyncHash.Label_RSAKeygenVulnStatus.Dispatcher.Invoke([action]{$SyncHash.Label_RSAKeygenVulnStatus.Content = "TPM is not vulnerable"})
        }
        else
        {
             $SyncHash.StatusIndicator_RSAKeygenVulnerability.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_RSAKeygenVulnerability.Fill = "Red"}) # Any other error condition
             $SyncHash.Label_RSAKeygenVulnStatus.Dispatcher.Invoke([action]{$SyncHash.Label_RSAKeygenVulnStatus.Content = "TPM is vulnerable! Update firmware."})
             $TpmVulnReportMsgBox = [System.Windows.MessageBox]::Show("Your TPM is vulnerable to RSA key generation failure. This will cause MEM enrollment to fail on the TPM attestation phase, as the system will not be able to securely request an AIK certificate from the Microsoft CA.`n`nUpdate your TPM firmware to get remedy this issue.`n`n","TPM was found to be vulnerable",0,16)
        }
    Function SetCheckListToDefaults {
        # Code for the preflight checks
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Resetting checklist."},9)
        $SyncHash.StatusIndicator_NetConnectionAvailable.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_NetConnectionAvailable.Fill = "Red"},9) # network is down
        $SyncHash.Label_NetworkStatus.Dispatcher.Invoke([action]{$SyncHash.Label_NetworkStatus.Content = "Can't connect to the internet"},9)

        $SyncHash.StatusIndicator_IntunePingResponse.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_IntunePingResponse.Fill = "Red"},9)
        $SyncHash.Label_IntunePingable.Dispatcher.Invoke([action]{$SyncHash.Label_IntunePingable.Content = "Intune was not pingable."},9)

        $SyncHash.StatusIndicator_AzureADJoinedIndicator.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AzureADJoinedIndicator.Fill = "Red"},9)
        $SyncHash.Label_AzureADJoinStatus.Dispatcher.Invoke([action]{$SyncHash.Label_AzureADJoinStatus.Content = "Device is not AAD joined"},9)

        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.Fill = "Red"},9) # HTTP_BADREQUEST"
        $SyncHash.StatusIndicator_AIKCertRequestStatus.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_AIKCertRequestStatus.ToolTip = "Orange = certreq returned HTTP_BADREQUEST."},9)
        $SyncHash.Label_CertReqLabel.Dispatcher.Invoke([action]{$SyncHash.Label_CertReqLabel.Content = "Certreq returned HTTP_BADREQUEST"},9)

        $SyncHash.StatusIndicator_RSAKeygenVulnerability.Dispatcher.Invoke([action]{$SyncHash.StatusIndicator_RSAKeygenVulnerability.Fill = "Red"}) # Any other error condition
        $SyncHash.Label_RSAKeygenVulnStatus.Dispatcher.Invoke([action]{$SyncHash.Label_RSAKeygenVulnStatus.Content = "TPM is vulnerable! Update firmware."})
        $TpmVulnReportMsgBox = [System.Windows.MessageBox]::Show("Your TPM is vulnerable to RSA key generation failure. This will cause MEM enrollment to fail on the TPM attestation phase, as the system will not be able to securely request an AIK certificate from the Microsoft CA.`n`nUpdate your TPM firmware to get remedy this issue.`n`n","TPM was found to be vulnerable",0,16)


        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Ready."})
        $invokePSThread_TrafficLights.IsCompleted($true)
    }})

#endregion Trafficlight-checklist

$SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Ready."})
$invokePSThread_TrafficLights.IsCompleted($true)

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
$SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Ready."})

$PSThread_TrafficLightChecks.Runspace = $TrafficLightRunspace
$invoke_TrafficLights = $PSThread_TrafficLightChecks.BeginInvoke()

$SyncHash.Button_ClearTPM.Add_click({
    $TPMClearResult = [System.Windows.MessageBox]::Show("Are you sure you want to clear the TPM?","Clear TPM?")
    if($TPMClearResult -eq 6){ # "6" is the return value for "yes"
        # Testing thingy, don't want to clear my TPM in production
        start powershell { Test-Connection -ComputerName endpoint.microsoft.com -Count 1 }# Clear-Tpm -UsePPI}
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "TPM was cleared. Click reboot to finalize the reset."})
    } else {
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Did not clear TPM."})
    }
})

$SyncHash.Button_InitTPM.Add_click({
    $TPMClearResult = [System.Windows.MessageBox]::Show("Are you sure you want to initialize the TPM?","Initialize TPM?")
    if($TPMClearResult -eq 6){ # "6" is the return value for "yes"
        # Testing thingy, don't want to clear my TPM in production
        # start powershell { [System.Windows.MessageBox]::Show("Just kidding!") } # Initialize-Tpm -AllowClear}
        $return = [System.Windows.MessageBox]::Show("Just kidding!")
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "TPM was initialized. Click reboot to finalize."},9)
    } else {
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Did not initialize TPM."},9)
    }
})

$SyncHash.Button_Reboot.Add_click({
    $rebootConfirmation = [System.Windows.MessageBox]::Show("Are you sure you want to reboot this computer?","Reboot",4)
    if($rebootConfirmation -eq 6){ # "6" is the return value for "yes"
        start powershell { exit } # Restart-Computer -Computername localhost}
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Rebooting..."},9)
    } else {
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Reboot aborted."},9)
    }
})

$SyncHash.Button_Shutdown.Add_Click({
    $shutdownConfirmation = [System.Windows.MessageBox]::Show("Are you sure you want to shut this computer down?","Shut down",4)
    if($shutdownConfirmation -eq 6){ # "6" is the return value for "yes"
        Start-Process powershell { exit } # Stop-Computer -Computername localhost}
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Starting shutdown..."},9)
    } else {
        $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = "Shutdown aborted."},9)
    }
})

$SyncHash.Button_EnrollUsingAAD.Add_Click({
    $Script = "'$PSScriptRoot\Scripts\Get-WindowsAutoPilotInfo.ps1' -Online"
    Start-Process PowerShell -ArgumentList "-NoExit" $Script
})

$SyncHash.Button_EnrollManually.Add_Click({
    $SaveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveDialog.InitialDirectory = "E:"
    $SaveDialog.Title = "Please choose where to save csv file..."
    $SaveDialog.DefaultExt = "csv"
    $SaveDialog.Filter = "csv | *.csv"

    if($SaveDialog.ShowDialog() -eq 'OK'){
        Start-Process PowerShell -ArgumentList "-NoExit  '$PSScriptRoot\Scripts\Get-WindowsAutopilotInfo.ps1 -OutputFile' $SaveDialog.FileName"
    }
})

$SyncHash.Button_GetHWSerialNumber.Add_Click({
    $SerialNumber = Get-WmiObject Win32_BIOS | Select-Object -ExpandProperty Serialnumber
    $MakeModel = Get-WMIObject –class Win32_ComputerSystem | Select-Object -ExpandProperty Model
    $ComputerName = Get-WMIObject –class Win32_ComputerSystem | Select-Object  -ExpandProperty Name

    $ButtonType = [System.Windows.MessageBoxButton]::Ok
    $MessageIcon = [System.Windows.MessageBoxImage]::Information
    $MessageBody = "Model: $MakeModel`n`nSerial number: $SerialNumber`n`nComputer name: $ComputerName"
    $MessageTitle = "Hardware information"

    $PopUpModalMsgBox = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
})

$SyncHash.Button_GetNetInfo.Add_Click({
    $NetworkAdapters = ipconfig | Format-List

    $ButtonType = [System.Windows.MessageBoxButton]::Ok
    $MessageBody = $NetworkAdapters
    $MessageTitle = "Network adapters"

    $PopUpModalMsgBox = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
})


# Doesn't work yet
# function Get-ScriptDirectory { Split-Path $MyInvocation.ScriptName }

$SyncHash.Button_ImportWiFiXML.Add_Click({
    Start-Process PowerShell -ArgumentList "'$PSScriptRoot\Scripts\Import-WiFiProfiles.ps1'"
})

function loadWiFiProfiles {
    # Get WiFi profiles
    $SyncHash.WiFiList = @()
    $WiFi = (netsh.exe wlan show profiles) -match "\s{2,}:\s"

    # Remove non-essential characters and add these to the array
    foreach ($WifiProfileName in $WiFi) {
        $TrimmedWiFiProfileName = ($WiFiProfileName.ToString()).Substring(27)
        $SyncHash.WiFiList += $TrimmedWiFiProfileName
    }
}

# Get WiFi profiles at load
loadWiFiProfiles

$SyncHash.NoProfiles = @("No wireless profiles available.")
$SyncHash.WiFiArray = $SyncHash.WiFiList

if($Synchash.WiFiArray.Count -gt 0) { # We have at least one profile in the array
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.SelectedIndex = 0})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.ItemsSource = $SyncHash.WiFiArray})
} else { # No profiles found
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.IsEnabled = $false})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.ItemsSource = $SyncHash.NoProfiles})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.SelectedIndex = 0})
}

$SyncHash.Button_SetNetInfo.Add_Click({
    $SyncHash.NetSettingsWindow.ShowDialog() | Out-Null
})

$SyncHash.Button_RefreshWiFiProfiles.Add_click({
    $SyncHash.Loading = @("Loading...")
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.IsEnabled = $false})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.ItemsSource = $SyncHash.Loading})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.SelectedIndex = 0})
    loadWiFiProfiles
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.ItemsSource = $SyncHash.WiFiArray})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.SelectedIndex = 0})
    $SyncHash.Combobox_WiFi.Dispatcher.Invoke([action]{$SyncHash.Combobox_WiFi.IsEnabled = $true})
})

$SyncHash.Button_ConnectToWiFi.Add_click({
    $SelectedProfile = $SyncHash.Combobox_WiFi.SelectedValue
    $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = $SelectedProfile})
    $returnMessage = netsh wlan connect name=$SelectedProfile
    $SyncHash.MainStatusMessage.Dispatcher.Invoke([action]{$SyncHash.MainStatusMessage.Content = $returnMessage})
})

$SyncHash.Button_ChecklistRefresh.Add_Click({
    # does not work yet
    $SyncHash.SetCheckListToDefaults.BeginInvoke()
})

$SyncHash.Button_SaveNetworkSettings.Add_Click({
    $SyncHash.NetSettingsWindow.Close()
})
