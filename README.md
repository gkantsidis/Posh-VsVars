# Posh-VsVars

![logo_256.png](logo_256.png)

Powershell cmdlets to help import Visual Studios `vcvarsall.bat` into the current
shell session for use with. The code was based on [Posh-VsVars](https://github.com/Iristyle/Posh-VsVars),
but it has been rewritten to work with VS15 (Visual Studio 2017). It also favors x64 by default.
I have not tested with versions prior to VS14 (Visual Studio 2015), and in settings with multiple VS15 installations.

## Compatibility

* This is written for Powershell v5.
* It requires the `VSSetup` module to be installed.

## Installation

### Source from GitHub

One approach is to clone into your modules directory:

```powershell
git clone https://github.com/gkantsidis/Posh-VsVars
```

You may also consider cloning the following repo:
```
git clone https://github.com/gkantsidis/WindowsPowerShell
```

and then follow the instructions therein.

## Supported Commands

### Set-VsVars

Will find and load the `vcvarsall.bat` file for the latest Visual Studio version
installed on the given system, and will extract the environment information
into the current shell session.

```powershell
Set-VsVars
```

The same as above, except will only look for Visual Studio 2012.

```powershell
Set-VsVars -Version '11.0'
```

### Get-VsVars

Will find and load the `vcvarsall.bat` file for the latest Visual Studio version
installed on the given system, and returns a list of the changes that the script will make.

```powershell
Get-VsVars
```

The same as above, except will only look for Visual Studio 2012.

```powershell
Get-VsVars -Version '11.0'
```

### Remove-VsVars

Will remove all settings imported by the Visual Studio script.

```powershell
Remove-VsVars
```


## Credits

* Original concept is derived from Chris Tavares ([@gzortch][]) - [The last vsvars32 I'll ever need][]
* Icon is from Scott Hanselman ([@shanselman][]) - courtesy of his [blog posting][]

[@gzortch]: https://github.com/gzortch
[The last vsvars32 I'll ever need]: http://www.tavaresstudios.com/Blog/post/The-last-vsvars32ps1-Ill-ever-need.aspx
[@shanselman]: https://github.com/shanselman
[blog posting]: http://www.hanselman.com/blog/AwesomeVisualStudioCommandPromptAndPowerShellIconsWithOverlays.aspx
