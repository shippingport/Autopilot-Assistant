# Autopilot-Assistant

Autopilot Assistant is a small script with a GUI that can be used to trigger some commonly used Autopilot-related automations. The script is able to use multithreading using PowerShell Runspaces, although the implementation for this is still lacking. Not all features are currently in a working state, but feel free to use this as a base for your own customization.

### Usage
From the Windows OOBE screen, press shift-F10 to open command prompt. Change to the directory hosting the Autopilot Assistant files, and type Autopilot.bat. This batch file will then call the PowerShell script and launch the GUI.

### File descriptions
###### Autopilot.ps1
The main Autopilot Assistant file. Used to spawn the UI thread and run scripts froms /Scripts/
###### Scripts directory
The directory that holds the script files to be called from the main file.
###### Resources
A folder that may be used to store additional resources, such as branding or configuration files, such as logo.png or wifi.xml.

![Screenshot](https://github.com/shippingport/Autopilot-Assistant/blob/fb6ffc3076ccdedb37214a3b6b4c02e0526da742/Assistant/Resources/AutoPilot%20Assistant%202.0.2.png?raw=true)
