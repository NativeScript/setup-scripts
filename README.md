# NativeScript Setup Scripts
This repository holds the setup scripts needed for installing NativeScript. The purpose of the setup scripts is to provide an automated way to prepare your machine for working with the NativeScript tools. There are detailed step by step guides for how to achieve this manually [for Windows](http://docs.nativescript.org/start/ns-setup-win) and [for macOS](http://docs.nativescript.org/start/ns-setup-os-x).

## Usage ##

To run the setup scripts you can use the following commands: 

 - for Windows: `@powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((new-object net.webclient).DownloadString('https://www.nativescript.org/setup/win'))"`
 
 - for macOS: `ruby -e "$(curl -fsSL https://www.nativescript.org/setup/mac)"`. 
 
   In order to pass options use: `ruby -e "$(curl -fsSL https://www.nativescript.org/setup/mac)" -- [options]` 
   
   For example: `ruby -e "$(curl -fsSL https://www.nativescript.org/setup/mac)" -- --silentMode`

## Options ##

This scripts provide the following options:

 - `--silentMode`: this option will bypass all questions asked during the execution of the setup script and proceed with default settings. This is useful for automated setup of build machines for example.
