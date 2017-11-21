#
# Includes all files that compose the module
#

. $PSScriptRoot\EnvironmentSettings.ps1
. $PSScriptRoot\VisualStudioDetector.ps1
. $PSScriptRoot\Posh-VsVars.ps1

if (Get-ChildItem 'C:\Program Files (x86)\MSBuild' -Recurse -Include "Microsoft.Build.dll") {
    . $PSScriptRoot\Projects.ps1
}