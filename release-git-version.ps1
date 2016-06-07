# Copyright (c) Erliimar Silva Campos. All rights reserved.
# Licensed under the Apache License, Version 2.0. More license information in LICENSE.txt.

#Requires -Version 2

<#
.SYNOPSIS
    Tool to automate the release versions with Git. 
.PARAMETER RepositoryURL
    Default: $null
    Git repository URL
.PARAMETER Version
    Default: $null
    Number of version to generate
.PARAMETER BranchVersion
    Default: <Version>rc
    Name of temporary branch to prepare version
.PARAMETER BranchProduction
    Default: master
    Name of production branch
.PARAMETER BranchDevelopment
    Default: develop
    Name of development branch
.PARAMETER FileChangelog
    Default: CHANGELOG.txt
    Name of changelog file on repository root
.PARAMETER FileVersion
    Default: version.txt
    Name of file version on repository root
.PARAMETER RemoteName
    Default: origin
    Name of git remote
.PARAMETER PrefixTag
    Default: v
    Prefix of the version tag to generate
.PARAMETER CommitterName
    Default: $null
    Name of the Git user committer 
.PARAMETER CommitterEmail
    Default: $null
    E-mail of the Git user commiter
#>

param (
    [string] $RepositoryURL = $null,
    [string] $Version = $null,
    [string] $BranchVersion = $null,
    [string] $CommitterName = $null,
    [string] $CommitterEmail = $null,
    [string] $BranchProduction = "master",
    [string] $BranchDevelopment = "develop",
    [string] $FileChangelog = "CHANGELOG.txt",
    [string] $FileVersion = "version.txt",
    [string] $RemoteName = "origin",
    [string] $PrefixTag = "v"
)

<#
.SYNOPSIS
    Show user prompt to insert a valid string if <Value> is null or white space
.PARAMETER Value
    Initial value for string
.PARAMETER Prompt
    The user prompt text
#>
Function Get-EnsureString([string]$Value, [string]$Prompt) {
    $output = $Value

    While([String]::IsNullOrWhiteSpace($output)) {
        $output = Read-Host -Prompt $Prompt
    }

    return $output
}

<#
.SYNOPSIS
    Generate a temporary folder name
#>
Function Get-TemporaryFolderName() {
    $userTempPath = [System.IO.Path]::GetTempPath()
    $folderName = [System.Guid]::NewGuid()

    return (Join-Path $userTempPath $folderName)
}

<#
.SYNOPSIS
    Generate a temporary file name
.PARAMETER Sufix
    Sufix file name
#>
Function Get-TemporaryFileName([string]$Sufix=$null) {
    $fileName = [System.IO.Path]::GetRandomFileName()
    $fileName = "${fileName}".Replace(".",$null)

    if(! [String]::IsNullOrWhiteSpace($Sufix)) {
        $fileName = "${fileName}_${Sufix}"
    }

    return $fileName
}

<#
.SYNOPSIS
    Test if command exists
#>
Function Test-Command([string]$Cmd) {
    $_preference = $ErrorActionPreference
    $_exists = $null

    $ErrorActionPreference = "stop"

    try {
        if(Get-Command $Cmd) {
            $_exists = $true
        }
    }
    catch {
        $_exists = $false
    }
    finally {
        $ErrorActionPreference = $_preference
    }

    return $_exists
}

<#
.SYNOPSIS
    Clear temporary data
#>
Function Clear-TempData() {
    # TODO: Implements
}

try {
    # Git is requires
    if(! (Test-Command -Cmd "git")) {
        throw "Git is required. Install Git tool from https://git-scm.com"
    }

    $RepositoryURL = Get-EnsureString -Value $RepositoryURL -Prompt "Enter a repository URL"
    $Version = Get-EnsureString -Value $Version -Prompt "Enter a version number"

    if([String]::IsNullOrWhiteSpace($BranchVersion)) {
        $BranchVersion = "release/${Version}rc"
    }

    $BranchVersion = Get-EnsureString -Value $BranchVersion -Prompt "Enter a version branch name"
    $CommitterName = Get-EnsureString -Value $CommitterName -Prompt "Enter a Git commiter name"
    $CommitterEmail = Get-EnsureString -Value $CommitterEmail -Prompt "Enter a Git commiter e-mail"

    $_tagName = "${PrefixTag}${Version}"
    $_tempFolder = Get-TemporaryFolderName
    $_changelogMerge = Get-TemporaryFileName -Sufix $FileChangelog
    $_changelogStage = Get-TemporaryFileName -Sufix $FileChangelog

    "RepositoryURL: ${RepositoryURL}" | Write-Host
    "Version: ${Version}" | Write-Host
    "BranchVersion: ${BranchVersion}" | Write-Host
    "BranchProduction: ${BranchProduction}" | Write-Host
    "BranchDevelopment: ${BranchDevelopment}" | Write-Host
    "FileChangelog: ${FileChangelog}" | Write-Host
    "FileVersion: ${FileVersion}" | Write-Host
    "RemoteName: ${RemoteName}" | Write-Host
    "PrefixTag: ${PrefixTag}" | Write-Host
    "UserName: ${CommitterName}" | Write-Host
    "UserEmail: ${CommitterEmail}" | Write-Host
    "" | Write-Host

    "_tagName: ${_tagName}" | Write-Host
    "_tempFolder: ${_tempFolder}" | Write-Host
    "_changelogMerge: ${_changelogMerge}" | Write-Host
    "_changelogStage: ${_changelogStage}" | Write-Host
}
catch {
    $LastExitCode = 1
}
finally {
    Clear-TempData    
}

exit($LastExitCode)
