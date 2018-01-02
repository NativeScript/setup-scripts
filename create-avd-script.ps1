$scriptUrl = "https://raw.githubusercontent.com/NativeScript/setup-scripts/master/create-avd-script.ps1"

# Self-elevate
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isElevated) {
	start-process -FilePath PowerShell.exe -Verb Runas -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command iex ((new-object net.webclient).DownloadString($scriptUrl))"
	exit 0
}

$CommonScript = ".\common-script.ps1" 
If(Test-Path -Path $CommonScript) { 
	 . $CommonScript 
	 Create-AVD
} 
else {
	"$CommonScript not found" ; exit 
}