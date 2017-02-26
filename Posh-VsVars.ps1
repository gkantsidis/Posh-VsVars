
<#PSScriptInfo

.VERSION 1.0

.GUID 64f3bda3-3838-41a9-b29f-0da7faf0d904

.AUTHOR Christos Gkantsidis

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Sets environmental variables for Visual Studio 

#>
function Set-VsVars {
    [CmdletBinding()]
    param(
        [string]
        [ValidateSet('7.1', '8.0', '9.0', '10.0', '11.0', '12.0', '14.0', '15.0', 'latest')]
        $Version = 'latest',

        [string]
        [ValidateSet('x86', 'x86_amd64', 'x86_arm', 'amd64', 'amd64_x86', 'amd64_arm')]
        $Architecture = "amd64"
    )

    $script = Get-VsVarsScript -Version $Version
    Set-EnvironmentVariables -Script $script -Parameters $Architecture
}

function Get-VsVars {
    [CmdletBinding()]
    param(
        [string]
        [ValidateSet('7.1', '8.0', '9.0', '10.0', '11.0', '12.0', '14.0', '15.0', 'latest')]
        $Version = 'latest',

        [string]
        [ValidateSet('x86', 'x86_amd64', 'x86_arm', 'amd64', 'amd64_x86', 'amd64_arm')]
        $Architecture = "amd64"
    )

    $script = Get-VsVarsScript -Version $Version
    Get-ChangesInEnvironmentVariables -Script $script -Parameters $Architecture    
}

function Remove-VsVars {
    [CmdletBinding()]
    param(
    )

    Remove-EnvironmentSettings    
}