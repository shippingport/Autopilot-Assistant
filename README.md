# Autopilot-Assistant

Autopilot Assistant is a small script with a GUI that can be used to trigger some commonly used Autopilot-related automations.

### Usage
From the Windows OOBE screen, press shift-F10 to open command prompt. Change to the directory hosting the Autopilot Assistant files, and type Autopilot.bat. This batch file will then call the PowerShell script and launch the GUI.

### File descriptions
###### Autopilot.ps1
The main Autopilot Assistant file. Used to spawn the UI thread and run scripts froms /Scripts/
###### Scripts directory
The directory that holds the script files to be called from the main file.
###### Resources
A folder that may be used to store additional resources, such as branding or configuration files, such as logo.png or wifi.xml.
