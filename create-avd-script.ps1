$scriptUrl = "https://wwwuat.nativescript.org/setup/win-avd"
$scriptCommonUrl = "https://wwwuat.nativescript.org/setup/win-common"

# Self-elevate
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isElevated) {
	start-process -FilePath PowerShell.exe -Verb Runas -Wait -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -Command iex ((new-object net.webclient).DownloadString('" + $scriptUrl + "'))")
	exit 0
}

iex ((new-object net.webclient).DownloadString($scriptCommonUrl))
Create-AVD
exit 0