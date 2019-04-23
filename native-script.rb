# coding: utf-8

# A script to setup developer's workstation for developing with NativeScript
# To run it against PRODUCTION branch (only one supported with self-elevation) use
# sudo ruby -e "$(curl -fsSL https://www.nativescript.org/setup/mac)"

# Only the user can manually download and install Xcode from App Store
unless Process.uid == 0
  # Execute as root
  puts "These scripts require sudo permissions"
  exec('sudo ruby -e "$(curl -fsSL https://www.nativescript.org/setup/mac)"')
end

$silentMode = false
$answer = ""
ARGV.each do|a|
  if a == "--silentMode"
    $silentMode = true
    $answer = "a"
  end
end

if !$silentMode
  puts "NativeScript requires Xcode."
  puts "If you do not have Xcode installed, download and install it from App Store and run it once to complete its setup."
  puts "Do you have Xcode installed? (y/n)"

  xcode = gets.chomp

  if xcode.downcase == "n"
    exit
  end

  if !(`xcodebuild -version`.include? "version")
    puts "Xcode is not installed or not configured properly. Download, install, set it up and run this script again."
    exit
  end

  puts "You need to accept the Xcode license agreement to be able to use the Xcode command-line tools."
  system('xcodebuild -license')
end

$tasks = ["Homebrew", "Google Chrome", "Open JDK 8", "Android SDK", "Android emulator system image", "HAXM (Hardware accelerated Android emulator)", "Android emulator", "CocoaPods", "CocoaPods setup", "pip", "six", "xcodeproj"]
$count = 1
puts "This setup script will request to install the following on your machine:"
$tasks.each_with_index do |st, index|
    puts "#{index + 1}. #{st}"
end

# Help with installing other dependencies


def execute(script, warning_message, run_as_root = false)
  if run_as_root
    result = system(script)
  else
    result = system("sudo su " + ENV['SUDO_USER'] + " -c '" + script + "'")
  end

  if result.nil?
    STDERR.puts "ERROR: " + script + " execution FAILED"
    exit 1
  end

  unless result
    STDERR.puts "WARNING: " + warning_message
  end

  return result
end

def install(program_name, message, script, run_as_root = false, show_all_option = true)
  puts "Step #{$count} of #{$tasks.length}:"
  $count += 1
  
  if $answer != "a"
    puts "Allow the script to install " + program_name + "?"
    if show_all_option
      puts "Note that if you type all you won't be prompted for subsequent installations"
    end

    loop do
      puts show_all_option ? "(Y)es/(N)o/(A)ll" : "(Y)es/(N)o"
      $answer = gets.chomp.downcase
      is_answer_yn = $answer == "y" || $answer == "n"
      break if show_all_option ? is_answer_yn || $answer == "a" : is_answer_yn
    end

    if $answer == "n"
      puts "You have chosen not to install " + program_name + ". Some features of NativeScript may not work correctly if you haven't already installed it"
      return
    end
  end

  puts message
  execute(script, program_name + " not installed", run_as_root)
end

def install_environment_variable(name, value)
  ENV[name] = value.to_s

  execute("echo \"export #{name}=#{value}\" >> ~/.bash_profile", "Unable to set #{name}")

  if File.exist?(File.expand_path("~/.zshrc"))
    execute("echo \"export #{name}=#{value}\" >> ~/.zprofile", "Unable to set #{name}")
  end
end

# Actually installing all other dependencies
if $silentMode
  install("Homebrew", "Installing Homebrew...", 'ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" > /dev/null 2>&1 </dev/null', false, false)
else
  install("Homebrew", "Installing Homebrew...", 'ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"</dev/null', false, false)
end

if !(execute("brew --version", "Homebrew is not installed or not configured properly. Download it from http://brew.sh/, install, set it up and run this script again."))
  exit
end

# Allow brew to lookup versions
execute("brew tap caskroom/versions", "", false)

# Install Google Chrome
install("Google Chrome", "Installing Google Chrome (required to debug NativeScript apps)", "brew cask install google-chrome", false, false);

# Install Open JDK 8
install("Open JDK 8", "Installing Open JDK 8 ... This might take some time, please, be patient.", 'brew cask install adoptopenjdk8', false, false)
unless ENV["JAVA_HOME"]
  java_home = "$(/usr/libexec/java_home -v 1.8)"
  puts "Set JAVA_HOME=#{java_home}"
  install_environment_variable("JAVA_HOME", java_home)
end

# Install Android SDK
install("Android SDK", "Installing Android SDK", 'brew tap caskroom/cask; brew cask install android-sdk', false)
unless ENV["ANDROID_HOME"]
  android_home = "/usr/local/share/android-sdk"
  puts "Set ANDROID_HOME=#{android_home}"
  install_environment_variable("ANDROID_HOME", android_home)
  puts "Set ANDROID_SDK_ROOT=#{android_home}"
  install_environment_variable("ANDROID_SDK_ROOT", android_home)
end

puts "Configuring your system for Android development... This might take some time, please, be patient."
# Note that multiple license acceptances may be required, hence the multiple commands
# the android tool will introduce a --accept-license option in subsequent releases
def install_android_package(name)
  error_msg = "There seem to be some problems with the Android configuration"
  sdk_manager = File.join(ENV["ANDROID_HOME"], "tools", "bin", "sdkmanager")
  if $silentMode
    execute("echo y | #{sdk_manager} \"#{name}\" | grep -v = || true", error_msg)
  else
    execute("echo y | #{sdk_manager} \"#{name}\"", error_msg)
  end
end

sdk_manager = File.join(ENV["ANDROID_HOME"], "tools", "bin", "sdkmanager")
install_android_package("tools")
install_android_package("build-tools;28.0.3")
install_android_package("platform-tools")
install_android_package("platforms;android-28")
install_android_package("extras;android;m2repository")
install_android_package("extras;google;m2repository")

puts "Step #{$count} of #{$tasks.length}:"
$count += 1
puts "Do you want to install Android emulator system image? (y/n)"
if $silentMode || gets.chomp.downcase == "y"
  puts "Step #{$count} of #{$tasks.length}:"
  $count += 1
  puts "Do you want to install HAXM (Hardware accelerated Android emulator)? (y/n)"
  if $silentMode || gets.chomp.downcase == "y"
    execute("echo y | #{sdk_manager} \"extras;intel;Hardware_Accelerated_Execution_Manager\" | grep -v = || true", "Failed to download Intel HAXM.")
    haxm_silent_installer = File.join(ENV["ANDROID_HOME"], "extras", "intel", "Hardware_Accelerated_Execution_Manager", "silent_install.sh")
    execute("sudo #{haxm_silent_installer}", "Failed to install Intel HAXM.")
    execute("echo y | #{sdk_manager} \"system-images;android-28;google_apis;x86\" | grep -v = || true", "Failed to download Android emulator system image.")
  end
end

puts "Step #{$count} of #{$tasks.length}:"
$count += 1
puts "Do you want to create Android emulator? (y/n)"
if $silentMode || gets.chomp.downcase == "y"
  error_msg = "Failed to create Android emulator."
  avd_manager = File.join(ENV["ANDROID_HOME"], "tools", "bin", "avdmanager")
  # Create command ask for custom config, we pass "no" because we want defaults
  execute("echo no | #{avd_manager} create avd -n Emulator-Api28-Google -k  \"system-images;android-28;google_apis;x86\" -b google_apis/x86 -c 265M -f", error_msg)
end

# the -p flag is set in order to ensure zero status code even if the directory exists
execute("mkdir -p ~/.cocoapods", "There was a problem in creating ~/.cocoapods directory")
# CocoaPods already has a dependency to xcodeproj and also has a dependency to a lower version of activesupport
# which works with Ruby 2.0 that comes as the macOS default, so these two installations should be in this order.
# For more information see: https://github.com/CocoaPods/Xcodeproj/pull/393#issuecomment-231055159
install("CocoaPods", "Installing CocoaPods... This might take some time, please, be patient.", 'gem install cocoapods', true)
install("CocoaPods", "Setup CocoaPods... This might take some time, please, be patient.", 'pod setup', false)
install("pip", "Installing pip... This might take some time, please, be patient.", 'easy_install pip', true)
install("six", "Installing 'six' python package... This might take some time, please, be patient.", 'pip install six', false)
install("xcodeproj", "Installing xcodeproj... This might take some time, please, be patient.", 'gem install xcodeproj', true)

puts "The ANDROID_HOME and JAVA_HOME environment variables have been added to your .bash_profile/.zprofile"
puts "Restart the terminal or run `source ~/.bash_profile` to use them."
