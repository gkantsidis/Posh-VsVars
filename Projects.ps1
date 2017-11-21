function Get-MSBuildBinaryDirectory
{
    [Object[]]$builds = Get-ChildItem 'C:\Program Files (x86)\MSBuild' -Recurse -Include "Microsoft.Build.dll"
    if ($builds -ne $null) {
        [Object[]]$builds64 = $builds | Where-Object -FilterScript { $_.FullName.Contains("amd64") }
        if ($builds64 -ne $null) {
            $builds = $builds64
        }
    }

    if ($builds -eq $null) { return $null }

    [Object[]]$builds = $builds | Sort-Object -Property @{ Expression={ $_.VersionInfo.ProductVersion }; Ascending = $false }
    if ($builds.Count -eq 0) {
        return $null
    }

    return $builds[0].Directory
}

$msbuildbin = Get-MSBuildBinaryDirectory

if (($msbuildbin -ne $null) -and (Test-Path -Path $msbuildbin -PathType Container)) {
    if ("Microsoft.Build.Evaluation.Project" -as [type]) {
        Write-Verbose -Message "MSBuild Binaries already loaded"
    } else {
        Write-Verbose -Message "Loading binaries"
        $build = Join-Path -Path $msbuildbin.FullName -ChildPath "Microsoft.Build.dll"
        Import-Module -Name $build
    }
} else {
    Write-Error -Message "Did not find msbuild path"
}

function Get-ProjectInformation {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]$Path,

        [ValidateSet("2.0", "3.5", "4.0", "12.0", "14.0")]
        [string]$Toolchain = "14.0"
    )

    $project =  [Microsoft.Build.Evaluation.Project]::new($Path, $null, $Toolchain)

    return $project
}