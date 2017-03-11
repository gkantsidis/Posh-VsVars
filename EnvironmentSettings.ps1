
<#PSScriptInfo

.VERSION 1.0

.GUID 8a61af7e-a88d-4836-8a69-0d4ee402b53d

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

[string[]] $VariablesWithManyValues = @(
    '_NT_SOURCE_PATH',
    '_NT_SYMBOL_PATH',
    'LIB',
    'PATH',
    'PATHEXT',
    'PSMODULEPATH'    
)

<# 

.DESCRIPTION 
 Collects the environment variables after executing the script

#>
function Get-AllEnvironmentVariables {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]
        $Script,

        [string]
        $Parameters
    )
    
    $tempFile = [IO.Path]::GetTempFileName()

    ## Store the output of cmd.exe.  We also ask cmd.exe to output
    ## the environment table after the batch file completes

    $errorcode = cmd /c " `"$Script`" $Parameters && set > `"$tempFile`" "

    ## Go through the environment variables in the temp file.
    ## For each of them, set the variable in our local environment.
    $variables = @{}
    $ignore = Get-Content $tempFile | Foreach-Object {
        if (($_ -match "^(.*?)=(.*)$") -and (-not ($_.StartsWith("*"))))
        {
            $variables.Add($matches[1], $matches[2])
        }
    }

    if ($variables.Count -eq 0) {
        Write-Error -Message "Cannot access the environment variables"
    }

    return $variables
}

<# 

.DESCRIPTION 
 Collects the current environment variables

#> 

function Get-CurrentEnvironmentVariables {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    Param(
    )

    $variables = @{}
    $ignore = Get-ChildItem -Path Env: | Foreach-Object {
        $variables.Add($_.Name, $_.Value)
    }

    return $variables
}

<# 

.DESCRIPTION 
 Returns the changes between two sets of environment variables.

#>
function Get-VariableDifferenceFlat {
    [CmdletBinding()]
    param (
        [ValidateNotNull()]
        [Hashtable]
        $Before,

        [ValidateNotNull()]
        [Hashtable]
        $After
    )

    $added = $After.Keys | Where-Object -FilterScript { -not $Before.ContainsKey($_) }
    $removed = $Before.Keys | Where-Object -FilterScript { -not $After.ContainsKey($_) }
    $common = $After.Keys | Where-Object -FilterScript { $Before.ContainsKey($_) }

    $changed = $common | Where-Object -FilterScript { 
        [string]$beforeValue = $Before[$_]
        [string]$afterValue = $After[$_]

        if ($beforeValue.Equals($afterValue, [System.StringComparison]::InvariantCultureIgnoreCase)) {
            return $false
        } else {
            return $true
        }
    }

    [PSCustomObject]@{
        'Added'     = $added
        'Removed'   = $removed
        'Changed'   = $changed
    }
}

<# 

.DESCRIPTION 
 For those variables that contain a collection of values (e.g. separated by semicolor (';'), as in PATH),
 it returns the changes in the individual items.

#>
function Expand-ChangedVariable {
    [CmdletBinding()]
    param (
        [ValidateNotNull()]
        [string]
        $Before,

        [ValidateNotNull()]
        [string]
        $After,

        [char]
        $Separator = ';'
    )

    $beforeValues = $Before.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
    $afterValues = $After.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)

    $added = $afterValues | Where-Object { -not $beforeValues.Contains($_) }
    $removed = $beforeValues | Where-Object { -not $afterValues.Contains($_) }

    [PSCustomObject]@{
        'Added'     = $added
        'Removed'   = $removed
    }
}

<# 

.DESCRIPTION 
 Creates a signature of a script that will be used to cache the changes in the environment variables

#> 
function Get-ScriptSignature {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]
        $Script,

        [string]
        $Parameters
    )

    $Script = (Get-ChildItem -LiteralPath $Script).FullName
    $Parameters = $Parameters.Trim()

    [System.Tuple]::Create($Script, $Parameters)
}

class Variable {
    Apply()
    {
        throw "Must override method"
    }

    Remove()
    {
        throw "Must override method"
    }

}

class AdditionalVariable : Variable
{
    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $Name

    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $Value

    AdditionalVariable($name, $value)
    {
        $this.Name = $name
        $this.Value = $value
    }

    [string] ToString()
    {
        return ("Addition of variable {0} with value: {1}" -f $this.Name,$this.Value)
    }

    Apply()
    {
        Write-Debug -Message ("Adding variable {0} with value: {1}" -f $this.Name,$this.Value)
        [System.Environment]::SetEnvironmentVariable($this.Name, $this.Value, [System.EnvironmentVariableTarget]::Process)
    }

    Remove()
    {
        Write-Debug -Message ("Deleting variable {0}" -f $this.Name)
        [System.Environment]::SetEnvironmentVariable($this.Name, $null, [System.EnvironmentVariableTarget]::Process)
    }
}

class RemovedVariable : Variable
{
    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $Name

    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $Value

    RemovedVariable($name, $value)
    {
        $this.Name = $name
        $this.Value = $value
    }

    [string] ToString()
    {
        return ("Removal of variable {0} with value: {1}" -f $this.Name,$this.Value)
    }

    Apply()
    {
        Write-Debug -Message ("Removing variable {0} with value: {1}" -f $this.Name,$this.Value)
        [System.Environment]::SetEnvironmentVariable($this.Name, $null, [System.EnvironmentVariableTarget]::Process)
    }

    Remove()
    {
        Write-Debug -Message ("Adding variable {0}" -f $this.Name)
        [System.Environment]::SetEnvironmentVariable($this.Name, $this.Value, [System.EnvironmentVariableTarget]::Process)        
    }
}

class ChangedVariable : Variable
{
    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $Name

    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $Value

    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $OldValue

    ChangedVariable($name, $value, $old)
    {
        $this.Name = $name
        $this.Value = $value
        $this.OldValue = $old
    }

    [string] ToString()
    {
        return ("Change variable {0} with new value: {1}" -f $this.Name,$this.Value)
    }

    Apply()
    {
        Write-Debug -Message ("Adding variable {0} with value: {1}" -f $this.Name,$this.Value)
        [System.Environment]::SetEnvironmentVariable($this.Name, $this.Value, [System.EnvironmentVariableTarget]::Process)
    }

    Remove()
    {
        Write-Debug -Message ("Deleting variable {0}" -f $this.Name)
        [System.Environment]::SetEnvironmentVariable($this.Name, $this.OldValue, [System.EnvironmentVariableTarget]::Process)
    }
}

class CompositeVariable : Variable
{
    hidden
    [ValidateNotNullOrEmpty()]
    [string]
    $VariableName

    hidden
    [char]
    $Separator

    hidden
    [ValidateNotNullOrEmpty()]
    [string[]]
    $Additions

    hidden
    [string[]]
    $Removals

    CompositeVariable([string]$name, [string[]]$additions, [string[]]$removals) 
    {
        $this.VariableName = $name
        $this.Additions = $additions
        $this.Removals = $removals
        $this.Separator = ';'

        if ($this.Removals.Length -gt 0) {
            throw [System.NotImplementedException] "We do not handle removal of definitions from default"
        }
    }

    CompositeVariable([string]$name, [string[]]$additions) 
    {
        if (($null -eq $additions) -or ($additions.Length -eq 0)) {
            Write-Error -Message "Error in creating a composite variable for $name"
        }

        $this.VariableName = $name
        $this.Additions = $additions
        $this.Removals = @()
        $this.Separator = ';'

        if ($this.Removals.Length -gt 0) {
            throw [System.NotImplementedException] "We do not handle removal of definitions from default"
        }
    }

    [string] ToString()
    {
        $extra = [System.String]::Join($this.Separator, $this.Additions)
        return ("{0} is prepended with {1}" -f $this.VariableName,$extra)
    }

    Apply()
    {
        $extra = [System.String]::Join($this.Separator, $this.Additions)
        [string]$current = [System.Environment]::GetEnvironmentVariable($this.VariableName, [System.EnvironmentVariableTarget]::Process)

        $current = "{0};{1}" -f $extra,$current
        Write-Debug -Message ("Replacing {0} with {1}" -f $this.VariableName,$current)
        [System.Environment]::SetEnvironmentVariable($this.VariableName, $current, [System.EnvironmentVariableTarget]::Process)
    }

    Remove()
    {
        Write-Debug -Message ("Undoing variable {0}" -f $this.VariableName)

        [string]$current = [System.Environment]::GetEnvironmentVariable($this.VariableName, [System.EnvironmentVariableTarget]::Process)
        $this.Additions | ForEach-Object -Process {
            $addition = $_
            Write-Debug -Message "Removing entry $addition"
            $current = $current.Replace($addition, "")
        }

        $entries = $current.Split($this.Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
        $current = [System.String]::Join($this.Separator, $entries)
        if ([System.String]::IsNullOrWhiteSpace($current)) {
            [System.Environment]::SetEnvironmentVariable($this.VariableName, $null, [System.EnvironmentVariableTarget]::Process)
        } else {
            [System.Environment]::SetEnvironmentVariable($this.VariableName, $current, [System.EnvironmentVariableTarget]::Process)
        }
    }
}

$variable_cache = @{}

function Get-ChangesInEnvironmentVariables {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]
        $Script,

        [string]
        $Parameters,

        [switch]
        $Force
    )

    $scriptkey = Get-ScriptSignature -Script $Script -Parameters $Parameters

    if ((-not $variable_cache.ContainsKey($scriptkey) -or $Force)) {
        [Hashtable] $old = Get-CurrentEnvironmentVariables
        [Hashtable] $new = Get-AllEnvironmentVariables -Script $Script -Parameters $Parameters
        $changes = Get-VariableDifferenceFlat -Before $old -After $new

        $toremove = $changes.Removed | ForEach-Object -Process {
            $key = $_
            $keyi = $_.ToUpperInvariant()
            $value = $old[$key]

            if ($VariablesWithManyValues.Contains($keyi)) {
                Write-Error -Message ("Detected removal of {0} variable with value: {1}" -f $key,$value)
                throw [System.NotImplementedException]"Not handling removal of environment variables"
            } else {
                Write-Verbose -Message "Removing variable $key with value '$value'"
                [RemovedVariable]::new($key, $value)
            }
        }

        $toadd = $changes.Added | ForEach-Object -Process {
            $key = $_
            $keyi = $_.ToUpperInvariant()

            if ($VariablesWithManyValues.Contains($keyi)) {
                $e = Expand-ChangedVariable -Before "" -After ($new[$key])
                if ($e.Removed.Length -ne 0) {
                    throw "Internal error: values should not be deleted here"
                }
                if (($null -eq $e.Added) -or ($e.Added.Length -eq 0)) {
                    Write-Warning -Message "Trying to add a variable with no changes; variable: $key"
                } else {
                    [CompositeVariable]::new($key, $e.Added)
                }
            } else {
                [AdditionalVariable]::new($key, $new[$key])
            }
        }

        $tochange = $changes.Changed | ForEach-Object -Process {
            $key = $_
            $keyi = $_.ToUpperInvariant()

            if ($VariablesWithManyValues.Contains($keyi)) {
                $e = Expand-ChangedVariable -Before ($old[$key]) -After ($new[$key])
                if ($e.Removed.Length -ne 0) {
                    throw "Internal error: values should not be deleted here"
                }
                
                if (($null -eq $e.Added) -or ($e.Added.Length -eq 0)) {
                    # The script typically will just add the new values without checking whether they also existed.
                    # As a result the variable will appear to have changed, however, we will not detect any changes when
                    # computing the difference.
                    # TODO: Maybe we want to actually identify the new variables and do insert them as changes.
                    Write-Warning -Message "Trying to change a variable with no changes; variable: $key`nThis may happen if the variables already existed"
                    # Write-Warning -Message ("--Before: {0}`n--After :{1}" -f $old[$key],$new[$key])
                } else {
                    [CompositeVariable]::new($key, $e.Added)
                }
            } else {
                [ChangedVariable]::new($key, $new[$key], $old[$key])
            }        
        }

        $total = $toadd + $tochange + $toremove
        if ($variable_cache.ContainsKey($scriptkey)) {
            Write-Verbose -Message "Changing value in cache"
            $variable_cache[$scriptkey] = $total
        } else {
            Write-Verbose -Message "Writing new value to cache"
            $variable_cache.Add($scriptkey, $total)
        }

        return $total
    } else {
        Write-Verbose -Message "Reading value from cache"
        return ($variable_cache[$scriptkey])
    }
}

$script:current_settings = $null

function Set-EnvironmentVariables {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]
        $Script,

        [string]
        $Parameters
    )

    if ($script:current_settings -ne $null) {
        Write-Verbose -Message "Removing old settings"
        $script:current_settings | ForEach-Object -Process { $_.Remove() }
    }

    $settings = Get-ChangesInEnvironmentVariables -Script $Script -Parameters $Parameters
    $script:current_settings = $settings
    $settings | ForEach-Object -Process { $_.Apply() }
}

function Remove-EnvironmentSettings {
    [CmdletBinding()]
    param(        
    )

    if ($script:current_settings -ne $null) {
        Write-Verbose -Message "Removing old settings"
        $script:current_settings | ForEach-Object -Process { $_.Remove() }
    }

}