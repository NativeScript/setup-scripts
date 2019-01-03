
# A PowerShell script to set up Windows machine for NativeScript development
# NOTE: The script requires at least a version 4.0 .NET framework installed
# To run it inside a COMMAND PROMPT against the production branch (only one supported with self-elevation) use
# @powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((new-object net.webclient).DownloadString('https://www.nativescript.org/setup/win'))"
# To run it inside a WINDOWS POWERSHELL console against the production branch (only one supported with self-elevation) use
# start-process -FilePath PowerShell.exe -Verb Runas -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command iex ((new-object net.webclient).DownloadString('https://www.nativescript.org/setup/win'))"
param(
	[switch] $SilentMode
)

$scriptUrl = "https://www.nativescript.org/setup/win"

# Check if latest .NET framework installed is at least 4
$dotNetVersions = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version,Release -EA 0 | Where { $_.PSChildName -match '^(?!S)\p{L}'} | Select Version
$latestDotNetVersion = $dotNetVersions.GetEnumerator() | Sort-Object Version | Select-Object -Last 1
$latestDotNetMajorNumber = $latestDotNetVersion.Version.Split(".")[0]
if ($latestDotNetMajorNumber -lt 4) {
	Write-Host -ForegroundColor Red "To run this script, you need .NET 4.0 or later installed"
	if ((Read-Host "Do you want to open .NET Framework 4.6.1 download page (y/n)") -eq 'y') {
		Start-Process -FilePath "http://go.microsoft.com/fwlink/?LinkId=671729"
	}

	exit 1
}

# Self-elevate
$isElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isElevated) {
	start-process -FilePath PowerShell.exe -Verb Runas -Wait -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -file ""native-script.ps1"" ""--silentMode""")
	exit 0
}

# Help with installing other dependencies
$script:answer = if ($SilentMode) {"a"} else {""}
function Install($programName, $message, $script, $shouldExit) {
	if ($script:answer -ne "a") {
		Write-Host -ForegroundColor Green "Allow the script to install $($programName)?"
		Write-Host "Tip: Note that if you type A you won't be prompted for subsequent installations"
		do {
			$script:answer = (Read-Host "(Y)es/(N)o/(A)ll").ToLower()
		} until ($script:answer -eq "y" -or $script:answer -eq "n" -or $script:answer -eq "a")

		if ($script:answer -eq "n") {
			Write-Host -ForegroundColor Yellow "WARNING: You have chosen not to install $($programName). Some features of NativeScript may not work correctly if you haven't already installed it"
			return
		}
	}

	Write-Host $message
	Invoke-Expression($script)
	if ($LASTEXITCODE -ne 0) {
		Write-Host -ForegroundColor Yellow "WARNING: $($programName) not installed"
	}
}

function Pause {
	Write-Host "Press any key to continue..."
	[void][System.Console]::ReadKey($true)
}

# Actually installing all other dependencies
# Install Chocolatey
Install "Chocolatey (It's mandatory for the rest of the script)" "Installing Chocolatey" "iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))"

if ((Get-Command "cinst" -ErrorAction SilentlyContinue) -eq $null) {
	Write-Host -ForegroundColor Red "Chocolatey is not installed or not configured properly. Download it from https://chocolatey.org/, install, set it up and run this script again."
	Pause
	exit 1
}

# Install dependencies with Chocolatey

Install "Google Chrome" "Installing Google Chrome (required to debug NativeScript apps)" "cinst googlechrome --force --yes"

$androidHomePathExists = $False
if($env:ANDROID_HOME){
	$androidHomePathExists = Test-Path $env:ANDROID_HOME
}

if($androidHomePathExists -eq $False){
	[Environment]::SetEnvironmentVariable("ANDROID_HOME",$null,"User")
}

Install "Android SDK" "Installing Android SDK" "cinst android-sdk --force --yes"

refreshenv
# setup environment

if (!$env:ANDROID_HOME) {
	Write-Host -ForegroundColor DarkYellow "Setting up ANDROID_HOME"
	# in case the user has `android` in the PATH, use it as base for setting ANDROID_HOME
	$androidExecutableEnvironmentPath = Get-Command android -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Definition
	if ($androidExecutableEnvironmentPath -ne $null) {
		$androidHomeJoinedPath = [io.path]::combine($androidExecutableEnvironmentPath, "..", "..")
		$androidHome = Resolve-Path $androidHomeJoinedPath | Select-Object -ExpandProperty Path
	}
	else {
		$androidHome = "${Env:SystemDrive}\Android\android-sdk"
	}

	$env:ANDROID_HOME = $androidHome;
	[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:ANDROID_HOME", "User")
	refreshenv
}

# Install OpenJDK after Android SDK, as currently installing the Android SDK also installs the Oracle Java 1.8 version.
Install "Java Development Kit (OpenJDK)" "Installing Java Development Kit (OpenJDK)" "choco upgrade adoptopenjdk --version 8.192 --force --yes"

# For some reason refreshing the environment variables is not working with Chocolatey.
# To force it, refresh the $PROFILE, as shown here: https://stackoverflow.com/a/46760714/3357767
$env:ChocolateyInstall = Convert-Path "$((Get-Command choco).path)\..\.."
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
refreshenv

if (!$env:JAVA_HOME) {
	$openJdkLocation = "C:\Program Files\OpenJDK";
	$openJdkLocationExists = Test-Path $openJdkLocation;

	if ($openJdkLocationExists -eq $True) {
		# We should never come here, the installation of OpenJDK should set the variable
		Write-Host -ForegroundColor DarkYellow "Setting up JAVA_HOME to $openJdkLocation";
		[Environment]::SetEnvironmentVariable("JAVA_HOME", $openJdkLocation, "User");
		$env:JAVA_HOME = $openJdkLocation;
		refreshenv;
	}
}

Write-Host -ForegroundColor DarkYellow "Setting up Android SDK..."

# Update android-sdk tools in order to have avdmanager available and create AVDs later
# NOTE: This step can be removed once chocolatey provides later version of Android SDK
$androidToolsPath = [io.path]::combine($env:ANDROID_HOME, "tools")
$androidToolsOldPath = [io.path]::combine($env:ANDROID_HOME, "toolsOld")

$androidToolsPathExists = $False
if($androidToolsPath){
	$androidToolsPathExists = Test-Path $androidToolsPath
}

if($androidToolsPathExists -eq $True){
	Write-Host -ForegroundColor DarkYellow "Updating Android SDK tools..."
	Copy-Item "$androidToolsPath" "$androidToolsOldPath" -recurse
	# Do NOT auto-accept license with `echo y` since the command requires acceptance of MULTIPLE licenses on a clean machine which breaks in this case
	cmd /c "%ANDROID_HOME%\toolsOld\bin\sdkmanager.bat" "tools"
	Remove-Item "$androidToolsOldPath" -Force -Recurse
} else {
	Write-Host -ForegroundColor Red "ERROR: Failed to update Android SDK tools. This is a blocker to install default emulator, so please update manually once this installation has finished."
}

# add repositories.cfg if it is not created
$repositoriesConfigPath = [io.path]::combine($env:USERPROFILE, ".android", "repositories.cfg")

$pathExists = $False
if($repositoriesConfigPath){
	$pathExists = Test-Path $repositoriesConfigPath
}

if($pathExists -eq $False){
	Write-Host -ForegroundColor DarkYellow "Creating file $repositoriesConfigPath ..."
	New-Item $repositoriesConfigPath -type file
}

# setup android sdk
# following commands are separated in case of having to answer to license agreements
$androidExecutable = [io.path]::combine($env:ANDROID_HOME, "tools", "bin", "sdkmanager")

Write-Host -ForegroundColor DarkYellow "Setting up Android SDK platform-tools..."
echo y | cmd /c "$androidExecutable" "platform-tools"
Write-Host -ForegroundColor DarkYellow "Setting up Android SDK build-tools;28.0.3..."
echo y | cmd /c "$androidExecutable" "build-tools;28.0.3"
Write-Host -ForegroundColor DarkYellow "Setting up Android SDK platforms;android-28..."
echo y | cmd /c "$androidExecutable" "platforms;android-28"
Write-Host -ForegroundColor DarkYellow "Setting up Android SDK extras;android;m2repository..."
echo y | cmd /c "$androidExecutable" "extras;android;m2repository"
Write-Host -ForegroundColor DarkYellow "Setting up Android SDK extras;google;m2repository..."
echo y | cmd /c "$androidExecutable" "extras;google;m2repository"
Write-Host -ForegroundColor DarkYellow "FINISHED setting up Android SDK."

# Setup Default Emulator
$androidExecutable = [io.path]::combine($env:ANDROID_HOME, "tools", "bin", "sdkmanager")
$avdManagerExecutable = [io.path]::combine($env:ANDROID_HOME, "tools", "bin", "avdmanager")

# Emulator will be not installed in silent mode since Intel HAXM fails to install in silent mode.
$installEmulatorAnswer = if ($SilentMode) {"n"} else {
	Do {
		$installEmulatorAnswer = (Read-Host "Do you want to install Android emulator? (Y)es/(N)o").ToLower()
	}
	While ($installEmulatorAnswer -ne 'y' -and $installEmulatorAnswer -ne 'n')
}

if ($installEmulatorAnswer -eq 'y') {
	Write-Host -ForegroundColor DarkYellow "Setting up Android SDK system-images;android-28;google_apis;x86..."
	echo y | cmd /c "$androidExecutable" "system-images;android-28;google_apis;x86"

	echo y | cmd /c "$androidExecutable" "extras;intel;Hardware_Accelerated_Execution_Manager"
	$haxmSilentInstaller = [io.path]::combine($env:ANDROID_HOME, "extras", "intel", "Hardware_Accelerated_Execution_Manager", "silent_install.bat")
	cmd /c "$haxmSilentInstaller"

	if ($LASTEXITCODE -ne 0) {
		Write-Host -ForegroundColor Yellow "WARNING: Failed to install HAXM in silent mode. Starting interactive mode."
		$haxmInstaller = [io.path]::combine($env:ANDROID_HOME, "extras", "intel", "Hardware_Accelerated_Execution_Manager", "intelhaxm-android.exe")
		cmd /c "$haxmInstaller"
	}

	$cmdArgList = @(
		"create",
		"avd",
		"-n","Emulator-Api28-Default",
		"-k",'"system-images;android-28;google_apis;x86"'
	)

	echo no | cmd /c $avdManagerExecutable $cmdArgList
	
	if ($LASTEXITCODE -ne 0) {
		Write-Host -ForegroundColor Red "ERROR: An error occurred while installing Android emulator. Please, install it manually."
	}else{
		Write-Host -ForegroundColor Green "Android emulator is successfully installed."
	}
}

Write-Host -ForegroundColor Green "This script has modified your environment. You need to log off and log back on for the changes to take effect."
if (-Not $SilentMode) {
Pause
}
