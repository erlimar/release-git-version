# Copyright (c) Erliimar Silva Campos. All rights reserved.
# Licensed under the Apache License, Version 2.0. More license information in LICENSE.txt.

#Requires -Version 2

<#
release-git-version -Repository https://github.com/erlimar/teste.git -Version 2.0.0 -CommitterName "Erlimar Silva Campos" -CommitterEmail erlimar@gmail.com -WorkFileCsv sample-input.csv 
#>

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
    Default: release/<Version>rc
    Name of temporary branch to prepare version
.PARAMETER CommitterName
    Default: $null
    Name of the Git user committer 
.PARAMETER CommitterEmail
    Default: $null
    E-mail of the Git user commiter
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
    Default: $null
    Name of file version on repository root
.PARAMETER RemoteName
    Default: origin
    Name of git remote
.PARAMETER PrefixTag
    Default: v
    Prefix of the version tag to generate
.PARAMETER Locale
    Default: en-US
    Locale name (en-US, pt-BR)
.PARAMETER WorkFileCsv
    CSV file path to work list
.PARAMETER Verbose
    Show log on output
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
    [string] $FileVersion = $null,
    [string] $RemoteName = "origin",
    [string] $PrefixTag = "v",
    [string] $Locale = "en-US",
    [string] $WorkFileCsv = $null,
    [switch] $Verbose = $false
)

$_localeDefault = "en-US"
$_localeUser = $host.CurrentCulture.Name
$_localeFilePath = [io.path]::Combine($PSScriptRoot, "locale.${Locale}.ps1")

if(!(Test-Path $_localeFilePath)) {
    $_localeFilePath = [io.path]::Combine($PSScriptRoot, "locale.${_localeUser}.ps1")
}
if(!(Test-Path $_localeFilePath)) {
    $_localeFilePath = [io.path]::Combine($PSScriptRoot, "locale.${_localeDefault}.ps1")
}

iex "& $_localeFilePath"

<#
.SYNOPSIS
    Show error message and write log
.PARAMETER Message
    Message to show
#>
Function Show-Error([string]$Message) {
    $_message = ($env:MSG_ERROR_TEMPLATE.Replace("{0}", $Message))
    $_message | Write-Host -BackgroundColor Red -ForegroundColor Yellow
    Write-Log -Message $_message -NoVerbose
}

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

    while([string]::IsNullOrWhiteSpace($output)){
        $output = Read-Host -Prompt $Prompt
    }

    return $output
}

<#
.SYNOPSIS
    Show user prompt to insert a object pair to merge on the version
#>
Function Get-ObjectToMerge() {
    $work = ""
    $log = ""

    $output = Read-Host -Prompt $env:MSG_PROMPT_ADD_WORK
    Write-Log -Message $env:MSG_PROMPT_ADD_WORK -NoVerbose

    if(![string]::IsNullOrWhiteSpace($output)){
        $work = $output
        Write-Log -Message $env:MSG_PROMPT_INFORMED_VALUE.Replace("{0}", $output) -NoVerbose

        $output = Read-Host -Prompt $env:MSG_PROMPT_ADD_LOG
        Write-Log -Message $env:MSG_PROMPT_ADD_LOG -NoVerbose
        
        if(![string]::IsNullOrWhiteSpace($output)){
            $log = $output
            Write-Log -Message $env:MSG_PROMPT_INFORMED_VALUE.Replace("{0}", $output) -NoVerbose
        }
    }

    if([string]::IsNullOrWhiteSpace($work)){
        return $null
    } else {
        return @{"Work" = $work; "Log" = $log}
    }
}

<#
.SYNOPSIS
    Generate a temporary folder name
.PARAMETER Prefix
    Prefix file name
.PARAMETER Sufix
    Sufix file name
#>
Function Get-TemporaryFolderName([string]$Prefix=$null, [string]$Sufix=$null) {
    $userTempPath = [io.path]::GetTempPath()
    $folderName = [guid]::NewGuid()
    $folderName = "${Prefix}${folderName}${Sufix}"

    return (Join-Path $userTempPath $folderName)
}

<#
.SYNOPSIS
    Generate a temporary file name
.PARAMETER Prefix
    Prefix file name
.PARAMETER Sufix
    Sufix file name
#>
Function Get-TemporaryFileName([string]$Prefix=$null, [string]$Sufix=$null) {
    $fileName = [io.path]::GetRandomFileName()
    $fileName = "${fileName}".Replace(".",$null)

    if(! [string]::IsNullOrWhiteSpace($Sufix)){
        $fileName = "${Prefix}${fileName}${Sufix}"
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
        if(Get-Command $Cmd){
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

$_tempFolder = $null
$_repositoryFolder = $null

$_executionLog = $null
$_executionLogPath = $null

$_execStdOutPath = $null
$_execStdErrPath = $null

$_changelogMerge = $null
$_changelogMergePath = $null

$_changelogStage = $null
$_changelogStagePath = $null

# Only TRUE if finish without errors
$_success = $false

<#
.SYNOPSIS
    Test if work item is duplicated
.PARAMETER List
    Work list
.PARAMETER Item
    Object Item
#>
Function Test-Duplicate($List, $Item) {
    foreach ($i in $List){
        if($i -eq $Item) {
            continue
        }
        if($i.Work -eq $Item.Work){
            return $true
        }
    }
    return $false
}

<#
.SYNOPSIS
    Clear temporary data
.PARAMETER FullClear
    Clear all files and directorys
#>
Function Clear-TempData($FullClear) {
    if($FullClear -eq $true -and (Test-Path $_tempFolder)){
        Remove-Item  -Force -Recurse $_tempFolder
        return
    }

    if(Test-Path $_changelogMerge){
        Remove-Item -Force $_changelogMerge
    }

    if(Test-Path $_changelogStage){
        Remove-Item -Force $_changelogStage
    }

    if(Test-Path $_execStdErrPath){
        Remove-Item -Force $_execStdErrPath
    }

    if(Test-Path $_execStdOutPath){
        Remove-Item -Force $_execStdOutPath
    }
}

<#
.SYNOPSIS
    Write message on then log file
.PARAMETER Message
    Text message
.PARAMETER NoVerbose
    Disable verbose mode
.PARAMETER OnlyMessage
    No print DateTime
#>
Function Write-Log([string]$Message, [switch]$NoVerbose, [switch]$OnlyMessage=$false) {
    if($OnlyMessage){
        $dateTime = ""
    }else{
        $dateTime = Get-Date -Format $env:LOG_DATETIME_FORMAT
        $dateTime += ": "
    }

    if($Verbose -and !$NoVerbose){
        "log: ${Message}" | Write-Host -ForegroundColor Yellow
    }

    "${dateTime}${Message}" >> $_executionLogPath
}

<#
.SYNOPSIS
    Git clone repository
.PARAMETER Url
    Remote repository URL 
.PARAMETER Path
    Local repository path 
#>
Function Git-Clone([string]$Url, [string]$Path) {
    # git clone ${Url} ${Path}
    return ((start -FilePath "git" -ArgumentList @("clone", "${Url}", ".") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
}

<#
.SYNOPSIS
    Git check if reference exists on local list
.PARAMETER Path
    Local repository path 
.PARAMETER RefName
    Reference name 
#>
Function Git-LocalRefExists([string]$Path, [string]$RefName) {
    # git show-ref refs/heads/${RefName}
    $exists = ((start -FilePath "git" -ArgumentList @("show-ref", "refs/heads/${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
    if($exists) {
        return $exists
    }else{
        return ((start -FilePath "git" -ArgumentList @("show-ref", "refs/tags/${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
    }
}

<#
.SYNOPSIS
    Git check if reference exists on remote list
.PARAMETER Url
    Remote repository URL
.PARAMETER Path
    Local repository path 
.PARAMETER RefName
    Reference name 
#>
Function Git-RemoteRefExists([string]$Url, [string]$Path, [string]$RefName) {
    # git ls-remote --exit-code ${Url} ${RefName}
    return ((start -FilePath "git" -ArgumentList @("ls-remote", "--exit-code", "${Url}" ,"${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
}

<#
.SYNOPSIS
    Get a last commit HASH from branch/tag
.PARAMETER Url
    Remote repository URL
.PARAMETER Path
    Local repository path 
.PARAMETER RefName
    Reference name 
#>
Function Git-GetLastCommit([string]$Url, [string]$Path, [string]$RefName) {
    # git ls-remote --exit-code ${Url} ${RefName}
    $result = ((start -FilePath "git" -ArgumentList @("ls-remote", "--exit-code", "${Url}" ,"${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)

    if($result){
        foreach($line in (Get-Content "${_execStdOutPath}")){
            $line -match '^(.+)\s+(.+)$' | Out-Null
            if(![string]::IsNullOrWhiteSpace($Matches[1])){
                return $Matches[1]
            }
        }
    }
}

<#
.SYNOPSIS
    Get a commit log text
.PARAMETER Path
    Local repository path 
.PARAMETER Hash
    Commit hash 
#>
Function Git-GetLogText([string]$Path, [string]$Hash) {
    # git show -s --format=%B ${Hash}
    $result = ((start -FilePath "git" -ArgumentList @("show", "-s", "--format=%B" ,"${Hash}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)

    if(!$result){
        throw $env:MSG_ERROR_LOG_COMMIT_NOT_FOUND.Replace("{0}", $Hash)
    }

    return (Get-Content "${_execStdOutPath}")
}

<#
.SYNOPSIS
    Set repository Git config
.PARAMETER Path
    Local repository path 
.PARAMETER Key
    Config Key
.PARAMETER Value
    Config Value
#>
Function Git-SetConfig([string]$Path, [string]$Key, [string]$Value) {
    # git config --local ${Key} ${Value}
    return ((start -FilePath "git" -ArgumentList @("config", "--local", "`"${Key}`"", "`"${Value}`"") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
}

<#
.SYNOPSIS
    Git checkout
.PARAMETER Path
    Local repository path 
.PARAMETER RefName
    Reference name
.PARAMETER IsNew
    If ${IsNew}, use "-b" parameter on git 
#>
Function Git-Checkout([string]$Path, [string]$RefName, [switch]$IsNew) {
    # git checkout [-b] ${RefName}
    if($IsNew){
        return ((start -FilePath "git" -ArgumentList @("checkout", "-b", "${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
    }else{
        return ((start -FilePath "git" -ArgumentList @("checkout", "${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
    }
}

<#
.SYNOPSIS
    Git checkout
.PARAMETER Url
    Remote repository URL
.PARAMETER Path
    Local repository path 
.PARAMETER RefName
    Reference name 
#>
Function Git-Merge([string]$Url, [string]$Path, [string]$RefName) {
    # git remote --verbose
    #
    # $OUTPUT
    # >> origin  <URL> (fetch)
    # >> origin  <URL> (push)
    $remote = $null

    if(!(start -FilePath "git" -ArgumentList @("remote", "--verbose") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0){
        throw $env:MSG_ERROR_EXEC_GIT_COMMAND.Replace("{0}", "git remote --verbose")
    }
    foreach($line in (Get-Content "${_execStdOutPath}")){
        $line -match '^(.+)\s+(.+)\s+(\(fetch\)|\(push\))$' | Out-Null
        if($Matches[2] -eq $Url){
            $remote = $Matches[1]
            break
        }
    }
    if(!$remote){
        throw $env:MSG_ERROR_FAILED_DETECT_GIT_REMOTE.Replace("{0}", "${Url}")
    }

    # git merge --stat ${remote}/${RefName}
    $result = ((start -FilePath "git" -ArgumentList @("merge", "--stat", "${remote}/${RefName}") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdOutPath}" -RedirectStandardError "${_execStdErrPath}" -NoNewWindow -PassThru -Wait).ExitCode -eq 0)
    if(!$result){
        # git diff >> "${_execStdErrPath}"
        (start -FilePath "git" -ArgumentList @("diff") -WorkingDirectory "${Path}" -RedirectStandardOutput "${_execStdErrPath}" -NoNewWindow -PassThru -Wait) | Out-Null
        return $false 
    }

    return $true
}

try {
    # Git is requires
    if(! (Test-Command -Cmd "git")){
        throw $env:MSG_ERROR_INSTALL_GIT
    }

    $RepositoryURL = Get-EnsureString -Value $RepositoryURL -Prompt $env:MSG_ENTER_REPOSITORY_URL
    $Version = Get-EnsureString -Value $Version -Prompt $env:MSG_ENTER_VERSION_NUMBER

    if([string]::IsNullOrWhiteSpace($BranchVersion)){
        $BranchVersion = "release/${Version}rc"
    }

    $BranchVersion = Get-EnsureString -Value $BranchVersion -Prompt $env:MSG_ENTER_VERSION_BRANCH
    $CommitterName = Get-EnsureString -Value $CommitterName -Prompt $env:MSG_ENTER_COMMITTER_NAME
    $CommitterEmail = Get-EnsureString -Value $CommitterEmail -Prompt $env:MSG_ENTER_COMMITTER_EMAIL

    $_tagName = "${PrefixTag}${Version}"
    $_tempFolder = Get-TemporaryFolderName -Prefix "e5rtmp_"
    $_repositoryFolder = [io.path]::Combine($_tempFolder, "repository")

    $_executionLog = "release-git-version_" + (Get-Date -Format "yyyy-MM-dd-HHmmss") + ".log"
    $_executionLogPath = [io.path]::Combine($PWD, $_executionLog)

    $_execStdOutPath = [io.path]::Combine($_tempFolder, "release-git-version.stdout")
    $_execStdErrPath = [io.path]::Combine($_tempFolder, "release-git-version.stderr")

    $_changelogMerge = Get-TemporaryFileName -Sufix "_${FileChangelog}"
    $_changelogMergePath = [io.path]::Combine($_tempFolder, $_changelogMerge)

    $_changelogStage = Get-TemporaryFileName -Sufix "_${FileChangelog}"
    $_changelogStagePath = [io.path]::Combine($_tempFolder, $_changelogStage)

    $_mergeList = @()
    
    # Create temporary file structure
    if(Test-Path $_tempFolder){
        throw $env:MSG_ERROR_TEMPDIR_EXISTS
    }

    New-Item -ItemType Directory -Force $_tempFolder > $null
    New-Item -ItemType Directory -Force $_repositoryFolder > $null
    New-Item -ItemType File -Force $_executionLogPath > $null
    New-Item -ItemType File -Force $_changelogMergePath > $null
    New-Item -ItemType File -Force $_changelogStagePath > $null
    New-Item -ItemType File -Force $_execStdOutPath > $null
    New-Item -ItemType File -Force $_execStdErrPath > $null

    $env:LOG_STARTED.Replace("{0}", $Version) | Write-Host
    Write-Log -Message $env:LOG_STARTED.Replace("{0}", $Version) -NoVerbose

    Write-Log -Message "  RepositoryURL: ${RepositoryURL}"
    Write-Log -Message "  Version: ${Version}"
    Write-Log -Message "  BranchVersion: ${BranchVersion}"
    Write-Log -Message "  BranchProduction: ${BranchProduction}"
    Write-Log -Message "  BranchDevelopment: ${BranchDevelopment}"
    Write-Log -Message "  FileChangelog: ${FileChangelog}"
    Write-Log -Message "  FileVersion: ${FileVersion}"
    Write-Log -Message "  RemoteName: ${RemoteName}"
    Write-Log -Message "  PrefixTag: ${PrefixTag}"
    Write-Log -Message "  UserName: ${CommitterName}"
    Write-Log -Message "  UserEmail: ${CommitterEmail}"
    Write-Log -Message "  _tagName: ${_tagName}"
    Write-Log -Message "  _tempFolder: ${_tempFolder}"
    Write-Log -Message "  _repositoryFolder: ${_repositoryFolder}"
    Write-Log -Message "  _executionLog: ${_executionLog}"
    Write-Log -Message "  _executionLogPath: ${_executionLogPath}"
    Write-Log -Message "  _execStdOutPath: ${_execStdOutPath}"
    Write-Log -Message "  _execStdErrPath: ${_execStdErrPath}"
    Write-Log -Message "  _changelogMerge: ${_changelogMerge}"
    Write-Log -Message "  _changelogMergePath: ${_changelogMergePath}"
    Write-Log -Message "  _changelogStage: ${_changelogStage}"
    Write-Log -Message "  _changelogStagePath: ${_changelogStagePath}"
    
    # Make a merge list
    if([string]::IsNullOrWhiteSpace($WorkFileCsv)){
        $env:MSG_PROMPT_ADD_WORK_TITLE | Write-Host
        Write-Log -Message $env:MSG_PROMPT_ADD_WORK_TITLE -NoVerbose

        $env:MSG_PROMPT_ADD_WORK_LINE | Write-Host
        Write-Log -Message $env:MSG_PROMPT_ADD_WORK_LINE -NoVerbose

        $objectMerge = Get-ObjectToMerge

        while($objectMerge -ne $null){
            $_mergeList += $objectMerge
            $objectMerge = Get-ObjectToMerge
        }
    }else{
        Write-Log -Message $env:LOG_WORKFILE_CSV.Replace("{0}", [io.path]::GetFullPath($WorkFileCsv)) -NoVerbose
        $_mergeList = Import-Csv $WorkFileCsv
    }

    # At least one work (branch/commit) must be informed.
    if($_mergeList.Count -eq 0){
        throw $env:MSG_ERROR_EMPTY_MERGE_BRANCH
    }

    # Check work merge list
    Write-Log -Message $env:LOG_CHECK_MERGE_LIST
    $_mergeListString = @()
    foreach ($m in $_mergeList){
        if($m.Work -eq $BranchProduction){
            throw $env:MSG_ERROR_BRANCH_EQUAL_PRODUCTION.Replace("{0}", $m.Work)
        }
        if($m.Work -eq $BranchDevelopment){
            throw $env:MSG_ERROR_BRANCH_EQUAL_DEVELOPMENT.Replace("{0}", $m.Work)
        }
        if($m.Work -eq $BranchVersion){
            throw $env:MSG_ERROR_BRANCH_EQUAL_VERSION.Replace("{0}", $m.Work)
        }
        if(Test-Duplicate -List $_mergeList -Item $m){
            throw $env:MSG_ERROR_BRANCH_DUPLICATED.Replace("{0}", $m.Work)
        }
        $_mergeListString += $m.Work
    }
    Write-Log -Message $env:LOG_CHECK_MERGE_LIST_OK.Replace("{0}", [string]:: $_mergeListString)

    # Cloning repository
    $env:LOG_REPOSITORY_CLONE.Replace("{0}", "${RepositoryURL}") | Write-Host
    Write-Log -Message $env:LOG_REPOSITORY_CLONE.Replace("{0}", "${RepositoryURL}") -NoVerbose

    if(!(Git-Clone -Url "${RepositoryURL}" -Path "${_repositoryFolder}")){
        throw $env:MSG_ERROR_REPOSITORY_CLONE.Replace("{0}", "${RepositoryURL}")
    }

    # Branch checking
    $env:LOG_CHECKING_BRANCHES | Write-Host
    Write-Log -Message $env:LOG_CHECKING_BRANCHES -NoVerbose

    # Version branch should not exist.
    if(Git-LocalRefExists -Path $_repositoryFolder -RefName "${BranchVersion}"){
        throw $env:MSG_ERROR_VERSIONBRANCH_EXISTS.Replace("{0}", "${BranchVersion}")
    }

    # Version tag should not exist.
    if(Git-RemoteRefExists -Url $RepositoryURL -Path $_repositoryFolder -RefName "${_tagName}"){
        throw $env:MSG_ERROR_VERSIONTAG_EXISTS.Replace("{0}", "${_tagName}")
    }

    # Production branch must exist.
    if(!(Git-RemoteRefExists -Url $RepositoryURL -Path $_repositoryFolder -RefName "${BranchProduction}")){
        throw $env:MSG_ERROR_PRODBRANCH_NOT_EXISTS.Replace("{0}", "${BranchProduction}")
    }

    # Development branch must exist.
    if(!(Git-RemoteRefExists -Url $RepositoryURL -Path $_repositoryFolder -RefName "${BranchDevelopment}")){
        throw $env:MSG_ERROR_DEVBRANCH_NOT_EXISTS.Replace("{0}", "${BranchDevelopment}")
    }

    # Work branch must exist.
    foreach ($m in $_mergeList){
        $mergeName = $m.Work
        if(!(Git-RemoteRefExists -Url $RepositoryURL -Path $_repositoryFolder -RefName "${mergeName}")){
            throw $env:MSG_ERROR_WORK_BRANCH_NOT_EXISTS.Replace("{0}", "${mergeName}")
        }
        if(!$m.Log){
            $m.Log = Git-GetLastCommit -Url $RepositoryURL -Path $_repositoryFolder -RefName "${mergeName}" 
        }
    }
    Write-Log -Message $env:LOG_CHECK_BRANCHES_OK

    # Configure user data (name and e-mail)
    $env:LOG_CONFIGURING_USER_DATA | Write-Host
    Write-Log -Message $env:LOG_CONFIGURING_USER_DATA -NoVerbose
    Write-Log -Message $env:LOG_CONFIGURING_USER_DATA_DETAILS.Replace("{0}", $CommitterName).Replace("{1}", $CommitterEmail)

    if(!(Git-SetConfig -Path $_repositoryFolder -Key "user.name" -Value "${CommitterName}")){
        throw $env:MSG_ERROR_SET_GIT_USER_NAME.Replace("{0}", $CommitterName)
    }

    if(!(Git-SetConfig -Path $_repositoryFolder -Key "user.email" -Value "${CommitterEmail}")){
        throw $env:MSG_ERROR_SET_GIT_USER_EMAIL.Replace("{0}", $CommitterEmail)
    }
    Write-Log -Message $env:LOG_CONFIGURING_USER_OK

    # Change to development branch
    $env:LOG_CHANGE_TO_DEVELOPMENT_BRANCH.Replace("{0}", "${BranchDevelopment}") | Write-Host
    Write-Log -Message $env:LOG_CHANGE_TO_DEVELOPMENT_BRANCH.Replace("{0}", "${BranchDevelopment}") -NoVerbose
    
    if(!(Git-Checkout -Path $_repositoryFolder -RefName $BranchDevelopment)){
        throw $env:MSG_ERROR_CHECKOUT_DEVELOPMENT.Replace("{0}", $BranchDevelopment)
    } 

    # Creating version branch
    $env:LOG_CREATING_VERSION_BRANCH.Replace("{0}", "${BranchVersion}") | Write-Host
    Write-Log -Message $env:LOG_CREATING_VERSION_BRANCH.Replace("{0}", "${BranchVersion}") -NoVerbose
    
    if(!(Git-Checkout -Path $_repositoryFolder -RefName $BranchVersion -IsNew)){
        throw $env:MSG_ERROR_CREATE_RELEASE_BRANCH.Replace("{0}", $BranchVersion)
    }

    # Integrating branches
    $env:LOG_INTEGRATING_BRANCHES_VERSION | Write-Host
    Write-Log -Message $env:LOG_INTEGRATING_BRANCHES_VERSION -NoVerbose
    foreach ($m in $_mergeList){
        $mergeName = $m.Work
        if(!(Git-Merge -Url $RepositoryURL  -Path $_repositoryFolder -RefName "${mergeName}")){
            Write-Log -Message $env:MSG_ERROR_FAILED_INTEGRATE_BRANCH.Replace("{0}", $m.Work).Replace("{1}", $BranchVersion) -NoVerbose

            # TODO: Move string to locale file
            Write-Log -Message "------------------MERGE SUMMARY--------------------" -OnlyMessage -NoVerbose
            Get-Content $_execStdOutPath | foreach{
                Write-Log -Message $_ -OnlyMessage -NoVerbose
            }
            Write-Log -Message "" -OnlyMessage -NoVerbose
            # TODO: Move string to locale file
            Write-Log -Message "------------------MERGE DIFF-----------------------" -OnlyMessage -NoVerbose
            Get-Content $_execStdErrPath | foreach{
                Write-Log -Message $_ -OnlyMessage -NoVerbose
            }
            throw $env:MSG_ERROR_FAILED_INTEGRATE_BRANCH.Replace("{0}", $m.Work).Replace("{1}", $BranchVersion)
        }
    }

    # Writing version file
    $env:LOG_WRITING_VERSION_FILE | Write-Host
    Write-Log -Message $env:LOG_WRITING_VERSION_FILE -NoVerbose
    if($FileVersion){
        $_fileVersionPath = [io.path]::Combine($_repositoryFolder, $FileVersion)
        New-Item -ItemType File -Force $_fileVersionPath > $null
        "${Version}" > $_fileVersionPath
    }

    <#
    13. Escreve CHANGELOG
        $ Grava "2.0.0" > "tmpname_stage_{CHANGELOG}"
        $ Grava "=====" >> "tmpname_stage_{CHANGELOG}"
        $ Grava "[tmpname_{CHANGELOG}]" >> "tmpname_stage_{CHANGELOG}"
        $ Grava "" >> "tmpname_stage_{CHANGELOG}"
        $ Grava "[ChangeLog.txt]" >> "tmpname_stage_{CHANGELOG}"
        $ Grava "[tmpname_stage_{CHANGELOG}]" > "[ChangeLog.txt]"

        git show -s --format=%B <commit hash>
    #>
    foreach ($m in $_mergeList){
        $mergeName = $m.Work
        $mergeLog = $m.Log
        "***( $mergeName, $mergeLog )***" | Write-Host -BackgroundColor Yellow -ForegroundColor Black
        "------------------"| Write-Host -BackgroundColor Yellow -ForegroundColor Black
        Git-GetLogText -Path $_repositoryFolder -Hash $m.Log | Write-Host -BackgroundColor Yellow -ForegroundColor Black
        "" | Write-Host
    }

    "================== CHANGE LOG MERGE ==================" | Write-Host -BackgroundColor DarkGreen -ForegroundColor White
    Get-Content $_changelogMergePath | Write-Host -BackgroundColor DarkGreen -ForegroundColor White
    
    "" | Write-Host
    
    "================== CHANGE LOG STAGE ==================" | Write-Host -BackgroundColor Gray -ForegroundColor Black
    Get-Content $_changelogStagePath | Write-Host -BackgroundColor Gray -ForegroundColor Black

    <#
    14. Comita as alterações em "versao.txt" e "ChangeLog.txt"
        $ git add --force "versao.txt"
        $ git add --force "ChangeLog.txt"
        $ git commit -m "Dados da versão [2.0.0] atualizados em 'versao.txt' e 'ChangeLog.txt'"
    #>


    # Actions:::::::::::::::::::::::::::::::::::::::::::::::::::::
    # ============================================================
    #   - PublishProduction
    #       > Merge Version on Master
    #       > Generate TAG from Master
    #       > Merge TAG on Develop
    #       > Push Master
    #       > Push Develop
    #       > Push TAG
    #
    #   - PublishVersion
    #       > Push Version branch
    #
    #   - CopyRepository
    #       > Copy repository folder to -OutputRepositoryPath
    # ============================================================

    <#
    15. Merge em MASTER
        $ git checkout master
        $ git merge release/x.y.z
    #>

    <#
    16. Gerar TAG de versão
        $ git tag "v2.0.0"
    #>

    <#
    17. Merge de TAG em DEVELOP
        $ git checkout "develop"
        $ git merge "v2.0.0"
    17.1. Se falhar, ERRO;
        Grava "Erro: Não foi possível fazer merge de {v2.0.0} para {develop}" >> "tmpname_v2.0.0.log"
    #>

    <#
    18. Exibir mensagem de sucesso, apresentar caminho do arquivo de LOG e caminho da pasta temporária do repositório
    #>

    <#
        -AutoPush # Faz o push automaticamente ao final (se sucesso)
        -NoPush   # Não faz o push automaticamente, nem pergunta se quer fazê-lo

    19. Deseja enviar versão para servidor remoto agora?
        Se sim:
            $ git push -u {remoto} {master}:{master}
            $ git push -u {remoto} {develop}:{develop}
            $ git push -u {remoto} {v2.0.0}:{v2.0.0}
        Se não:
            Imprimir necessidade de fazer push de {master, develop, v2.0.0} para {origin}
            $ explorer {pasta_tmp}/repository
    #>

    # TODO: -OutputRepositoryPath # Se informado este campo, ao final do processo com sucesso o
    #                               tmp/repository é copiado para este local. Para permitir a
    #                               análise do trabalho executado.

    $env:LOG_FINISHED.Replace("{0}", $Version) | Write-Host
    Write-Log -Message $env:LOG_FINISHED.Replace("{0}", $Version) -NoVerbose
}
catch {
    Show-Error -Message $_
    $LastExitCode = 1
}
finally {
    Clear-TempData -FullClear (!$_success)
}

exit($LastExitCode)
