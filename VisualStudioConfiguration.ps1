#Require -Version 5

function Get-VisualStudioInstance {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Version = "15",

        [ValidateNotNullOrEmpty()]
        [string]
        $Executable = "Microsoft.VisualStudio.Setup.Configuration.Console.exe"
    )

    $command = Get-Command  Microsoft.VisualStudio.Setup.Configuration.Console.exe -ErrorAction SilentlyContinue
    if ($command -eq $null) {
        Write-Verbose -Message "Will try to find detector of VS Studio configuration utility"
        [string[]] $detector = Get-ChildItem $PSScriptRoot -Include Microsoft.VisualStudio.Setup.Configuration.Console.exe -Recurse
        if ($detector -eq $null) {
            Write-Verbose -Message "Configuration detector does not seem to appear; will try to download"
            $nuget = Get-Command -Name nuget -ErrorAction SilentlyContinue
            if ($nuget -eq $null) {
                Write-Verbose -Message "Cannot find nuget utility; please install, e.g. choco install NuGet.CommandLine"
                throw "Cannot detect Visual Studio configuration"
            }

            Write-Verbose -Message "Installing Visual Studio configuration utility"
            $targetpath = Join-Path -Path $PSScriptRoot -ChildPath packages
            nuget install Microsoft.VisualStudio.Setup.Configuration.Native -Prerelease -OutputDirectory packages -Source nuget.org
            [string[]] $detector = Get-ChildItem $PSScriptRoot -Include Microsoft.VisualStudio.Setup.Configuration.Console.exe -Recurse
            if ($detector -eq $null) {
                throw "Error in installing configuration package"
            }
        }
        if ($detector.Length -gt 1) {
            [string[]] $xdetector = $detector | Where-Object -FilterScript { $_.Contains("\x64\") }
            if (($xdetector -eq $null) -or ($xdetector.Length -gt 1)) {
                Write-Verbose -Message "Found multiple detectors; will pick one"
            }
            $detector = $xdetector[0]
        }
        $command = $detector
    } else {
        $command = $command.Definition
    }
    Write-Verbose -Message "Detecting VS configuration utility with $command"

    [string]$vs = Invoke-Expression -Command "$command all -output json -nologo"
    if (($vs -eq $null) -or ($vs.Length -eq 0)) {
        throw "Did not read properly the output of the configuration command"
    }
    Write-Debug -Message "Configuration is $vs"
    $installations = ConvertFrom-Json -InputObject $vs
    $installations = $installations | Where-Object -FilterScript {
        $installation = $_
        $thisversion = $installation.InstallationVersion
        Write-Verbose -Message "Checking against version $version"
        $thisversion.StartsWith("$Version.")
    }

    if ($installation -eq $null) {
        throw "Cannot find Visual Studio version $Version"
    }
    
    $installations[0].InstallationPath
}

