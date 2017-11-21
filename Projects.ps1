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

class MSBuildProject
{
    [Object]$Project
    [System.Collections.Generic.Dictionary[string, Object]]$Items
    [Object[]]$ItemsIgnoringCondition
    [Object[]]$ItemTypes
    [Object[]]$ItemDefinitions
    [Object[]]$RawProperties
    [System.Collections.Generic.Dictionary[string, Object]]$Properties
    [Object[]]$RawEvaluatedProperties
    [System.Collections.Generic.Dictionary[string, Object]]$EvaluatedProperties

    MSBuildProject($project)
    {
        $this.Project =$project

        $this.Items = New-Object -TypeName 'system.collections.generic.dictionary[string,Object]'
        $tmpitems = [System.Collections.Generic.List[System.Object]]::new($this.Project.Items).ToArray() | Group-Object -Property ItemType
        foreach($item in $tmpitems) {
            $this.Items.Add($item.Name, $item.Group)
        }

        $this.ItemsIgnoringCondition = [System.Collections.Generic.List[System.Object]]::new($this.Project.ItemsIgnoringCondition).ToArray()
        $this.ItemTypes = [System.Collections.Generic.List[System.Object]]::new($this.Project.ItemTypes).ToArray()
        $this.ItemDefinitions = [System.Collections.Generic.List[System.Object]]::new($this.Project.ItemDefinitions).ToArray()
        $this.Properties = New-Object -TypeName 'system.collections.generic.dictionary[string,Object]'
        $this.EvaluatedProperties = New-Object -TypeName 'system.collections.generic.dictionary[string,Object]'

        $this.RawProperties = [System.Collections.Generic.List[System.Object]]::new($this.Project.Properties).ToArray()
        foreach($property in $this.RawProperties) {
            $this.Properties.Add($property.Name, $property)
        }

        $this.RawEvaluatedProperties = [System.Collections.Generic.List[System.Object]]::new($this.Project.AllEvaluatedProperties).ToArray()
        $rep = $this.RawEvaluatedProperties | Group-Object -Property Name
        foreach($property in $rep) {
            $this.EvaluatedProperties.Add($property.Name, $property.Group)
        }
    }

    [string[]] GetUndefinedProperties() {
        return ( $this.Properties.Values | `
                 Where-Object { ($_.IsEnvironmentProperty -eq $false) -and ($_.UnevaluatedValue -eq "*Undefined*") } | `
                 Select-Object -ExpandProperty Name
               )
    }
}

function Get-MSBProjectInformation {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]$Path,

        [System.Collections.Generic.IDictionary[string,string]]$Properties = $null,

        [ValidateSet("2.0", "3.5", "4.0", "12.0", "14.0")]
        [string]$Toolchain = "14.0"
    )

    $project = [Microsoft.Build.Evaluation.Project]::new($Path, $Properties, $Toolchain)
    if ($project -eq $null) {
        Write-Error -Message "Failed to parse: $Path"
        return $null
    } else {
        return [MSBuildProject]::new($project)
    }
}

function Unregister-MSBProject {
    [CmdletBinding(DefaultParameterSetName='ByProject')]
    param(
        [Parameter(ParameterSetName="ByProject")]
        [ValidateNotNull()]
        [MSBuildProject]$Project,

        [Parameter(ParameterSetName="All")]
        [switch]$All
    )

    switch ($PsCmdlet.ParameterSetName) {
        "ByProject" { [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.UnloadProject($Project) }
        "All" { [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.UnloadAllProjects() }
    }
}