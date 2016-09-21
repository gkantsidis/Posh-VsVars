# adapted from
# http://www.tavaresstudios.com/Blog/post/The-last-vsvars32ps1-Ill-ever-need.aspx
$script:rootVsKey = if ([IntPtr]::size -eq 8)
  { "HKLM:SOFTWARE\Wow6432Node\Microsoft\VisualStudio" }
else
  { "HKLM:SOFTWARE\Microsoft\VisualStudio" }

function Get-Batchfile ($file)
{
  if (!(Test-Path $file))
  {
    throw "Could not find batch file $file"
  }

  Write-Verbose "Executing batch file $file in separate shell"
  $cmd = "`"$file`" & set"
  $environment = @{}
  cmd /c $cmd | % {
    $p, $v = $_.split('=')
    $environment.$p = $v
  }

  return $environment
}

function Get-BatchfileWithArchitecture ($file, $architecture)
{
  if (!(Test-Path $file))
  {
    throw "Could not find batch file $file"
  }

  Write-Verbose "Executing batch file $file with architecture $args in separate shell"
  $cmd = "`"$file`" $architecture & set"
  $environment = @{}
  . $Env:ComSpec /c $cmd | % {
    $p, $v = $_.split('=')
    $environment.$p = $v
  }

  return $environment
}

function FilterDuplicatePaths
{
  [CmdletBinding()]
  param(
    [string]
    $Path
  )

  # with PATH, order is important, so can't use Get-Unique
  $uniquePaths = @{}

  $filtered = $Path -split ';' |
    ? {
      if (!$uniquePaths.ContainsKey($_))
      {
        $uniquePaths.Add($_, '')
        return $true
      }

      return $false
    }

  return $filtered -join ';'
}

function Get-LatestVsVersion
{
  # TODO: Remove the Where-Object below when Visual Studio 15.0 stabilizes
  Write-Warning -Message "Ignoring Visual Studio 15.0, even if it exists"

  $version = Get-ChildItem $script:rootVsKey |
    ? { $_.PSChildName -match '^\d+\.\d+$' } |
    Sort-Object -Property @{ Expression = { $_.PSChildName -as [int] } } |
    Where-Object -Property Name -NotMatch "15.0$" |
    Select -ExpandProperty PSChildName -Last 1

  if (!$version)
  {
    throw "Could not find a Visual Studio version based on registry keys..."
  }

  Write-Verbose "Found latest Visual Studio Version $Version"

  return $version
}

function Get-VsVars
{
<#
.Synopsis
  Will find and load the vsvars32.bat file for the given Visual Studio
  version, extrapolating it's environment information into a Hash.
.Description
  Will examine the registry to find the location of Visual Studio on
  disk, and will in turn find the location of the batch file that should
  be run to setup the local environment for command line build and
  tooling support.
.Parameter Version
  A Visual Studio version id string such as:

   8.0      Visual Studio 2005
   9.0      Visual Studio 2008
  10.0      Visual Studio 2010
  11.0      Visual Studio 2012
  12.0      Visual Studio 2013
  14.0      Visual Studio 2015
  15.0      Visual Studio 15 beta
  latest    Finds the latest version installed automatically (default)
.Outputs
  Returns a [Hashtable]
.Example
  Get-VsVars -Version '10.0'

  Description
  -----------
  Will find the batch file for Visual Studio 10.0, execute it in a
  subshell, and return the environment settings in a hash.

  If the Visual Studio version specified is not found, will throw an
  error.
.Example
  Get-VsVars

  Description
  -----------
  Will find the batch file for the latest Visual Studio, execute it in
  a subshell, and return the environment settings in a hash.

  If no Visual Studio version is found, will throw an error.
#>
  [CmdletBinding()]
  param(
    [string]
    [ValidateSet('7.1', '8.0', '9.0', '10.0', '11.0', '12.0', '14.0', '15.0', 'latest')]
    $Version = 'latest'
  )

  if ($version -eq 'latest') { $version = Get-LatestVsVersion }

  Write-Verbose "Reading VSVars for $version"

  $VsKey = Get-ItemProperty "$script:rootVsKey\$version" -ErrorAction SilentlyContinue
  if (!$VsKey -or !$VsKey.InstallDir)
  {
    Write-Warning "Could not find Visual Studio $version in registry"
    return
  }

  $VsRootDir = Split-Path $VsKey.InstallDir
  $BatchFile = Join-Path (Join-Path $VsRootDir 'Tools') 'vsvars32.bat'
  if (!(Test-Path $BatchFile))
  {
    if ($version -eq '15.0') {
        # TODO: Figure out a stable way to detect installation directory for Visual Studio 15 Preview 4 and higher
        # The problem is that the InstallDir property does not seem to work correctly.
        $VsKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\VSIP\15.0"
        if ($VsKey -and $VsKey.InstallDir) {
            $VsRootDir = Split-Path $VsKey.InstallDir
            $BatchFile = Join-Path -Path $VsRootDir -ChildPath Common7 | `
                         Join-Path -ChildPath IDE | `
                         Join-Path -ChildPath VC | `
                         Join-Path -ChildPath 'vcvarsall.bat'

            if (Test-Path $VsRootDir) {
                # TODO: Checks for a fix to vsvars32.bat. In VS 15 Preview 4 it points to the wrong location for vcvarsall.bat.
                return (Get-BatchfileWithArchitecture -File $BatchFile x86)
            }
        }
    }

    Write-Warning "Could not find Visual Studio $version batch file $BatchFile"
    return
  }
  return Get-Batchfile $BatchFile
}

function Set-VsVars
{
<#
.Synopsis
  Will find and load the vsvars32.bat file for the given Visual Studio
  version, and extract it's environment into the current shell, for
  command line build and tooling support.
.Description
  This function uses Get-VsVars to return the environment for the
  given Visual Studio version, then copies it into the current shell
  session.

  Use the -Verbose switch to see which current environment variables
  are overwritten and which are added.

  NOTE:

  - The PROMPT environment variable is excluded from being overwritten
  - A global variable in the current session ensures that the same
  environment variables haven't been loaded multiple times.
  - PATH has duplicate entries removed in an effort to prevent it from
  exceeding the length allowed by the shell (generally 2048 characters)
.Parameter Version
  A Visual Studio version id string such as:

   8.0      Visual Studio 2005
   9.0      Visual Studio 2008
  10.0      Visual Studio 2010
  11.0      Visual Studio 2012
  12.0      Visual Studio 2013
  14.0      Visual Studio 2015
  15.0      Visual Studio 15 Beta
  latest    Will find the latest version installed automatically (default)
.Example
  Set-VsVars -Version '10.0'

  Description
  -----------
  Will find the batch file for Visual Studio 10.0, execute it in a
  subshell, and import environment settings into the current shell.

  If the Visual Studio version specified is not found, will throw an
  error.
.Example
  Set-VsVars

  Description
  -----------
  Will find the batch file for the latest Visual Studio, execute it in
  a subshell, and import environment settings into the current shell.

  If no Visual Studio version is found, will throw an error.
#>
  [CmdletBinding()]
  param(
    [string]
    [ValidateSet('8.0', '9.0', '10.0', '11.0', '12.0', '14.0', '15.0', 'latest')]
    $Version = 'latest'
  )

  $name = "Posh-VsVars-Set-$Version"
  if ($Version -eq 'latest') { $name = "Posh-VsVars-Set-$(Get-LatestVsVersion)" }

  #continually jamming stuff into PATH is *not* cool ;0
  $setVersion = Get-Variable -Scope Global -Name $name `
    -ErrorAction SilentlyContinue

  if ($setVersion) { return }

  $variables = Get-VsVars -Version $Version
  if ($variables -eq $null) {
    return
  }

  $variables.GetEnumerator() |
    ? { $_.Key -ne 'PROMPT' } |
    % {
      $name = $_.Key
      $path = "Env:$name"
      if (Test-Path -Path $path)
      {
        $existing = Get-Item -Path $path | Select -ExpandProperty Value
        if ($existing -ne $_.Value)
        {
          # Treat PATH specially to prevent duplicates
          if ($name -eq 'PATH')
          {
            $_.Value = FilterDuplicatePaths -Path $_.Value
          }

          Write-Verbose "Overwriting $name with $($_.Value)`n      was:`n$existing`n`n"
          Set-Item -Path $path -Value $_.Value
        }
      }
      else
      {
        Write-Verbose "Setting $name to $($_.Value)`n`n"
        Set-Item -Path $path -Value $_.Value
      }
    }

  Set-Variable -Scope Global -Name $name -Value $true

  if (!(Test-Path 'Env:\VSToolsPath'))
  {
    $progFiles = $Env:ProgramFiles
    if (${env:ProgramFiles(x86)}) { $progFiles = ${env:ProgramFiles(x86)} }
    if (!$progFiles -and ${Env:CommonProgramFiles(x86)}) { 
        $progFiles = Split-Path ${Env:CommonProgramFiles(x86)}
    }

    if ($progFiles) {
        $tools = Join-Path $progFiles "MSBuild\Microsoft\VisualStudio\v$Version"
        $ENV:VSToolsPath = $tools

        Write-Verbose "SDK (non-VS) install found - setting VSToolsPath to $tools`n`n"
    } else {
        Write-Error "Cannot find Program Files (x86) directory"
    }
  }
}

Export-ModuleMember -Function Get-VsVars, Set-VsVars
