function Create-AVD{
    $androidExecutable = [io.path]::combine($env:ANDROID_HOME, "tools", "bin", "sdkmanager")
    $avdManagerExecutable = [io.path]::combine($env:ANDROID_HOME, "tools", "bin", "avdmanager")
    
    # Setup Default Emulator
    $installEmulatorAnswer = ''
    Do {
        $installEmulatorAnswer = (Read-Host "Do you want to install Android emulator? (Y)es/(N)o").ToLower()
    }
    While ($installEmulatorAnswer -ne 'y' -and $installEmulatorAnswer -ne 'n')

    if ($installEmulatorAnswer -eq 'y') {
        if ((Read-Host "Do you want to install HAXM (Hardware accelerated Android emulator)?") -eq 'y') {
            Write-Host "Setting up Android SDK system-images;android-25;google_apis;x86..."
            echo y | cmd /c "$androidExecutable" "system-images;android-25;google_apis;x86"

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
                "-n","Emulator-Api25-Default-haxm",
                "-k",'"system-images;android-25;google_apis;x86"'
            )
        }
        else {
            Write-Host "Setting up Android SDK system-images;android-25;google_apis;armeabi-v7a..."
            echo y | cmd /c "$androidExecutable" "system-images;android-25;google_apis;armeabi-v7a"

            $cmdArgList = @(
                "create",
                "avd",
                "-n","Emulator-Api25-Default",
                "-k",'"system-images;android-25;google_apis;armeabi-v7a"'
            )
        }

        echo no | cmd /c $avdManagerExecutable $cmdArgList
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host -ForegroundColor Yellow "An error occurred while installing Android emulator."
        }else{
            Write-Host -ForegroundColor Green "Android emulator is successfully installed."
        }
    }
}