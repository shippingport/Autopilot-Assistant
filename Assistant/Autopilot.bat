@ECHO OFF
REM This batch file is used to call PowerShell from the Windows OOBE command prompt (i.e. shift+f10)
PowerShell -NoProfile -ExecutionPolicy Unrestricted -Command %~dp0AutopilotAssistant.ps1
