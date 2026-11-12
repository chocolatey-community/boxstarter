function Install-BoxstarterPackage {
<#
.SYNOPSIS
Installs a Boxstarter package

.DESCRIPTION
This function wraps a Chocolatey Install and provides these additional features
 - Installs Chocolatey if it is not already installed
 - Installs the .net 4.5 framework if it is not installed which is a Chocolatey requirement
 - Disables windows update service during installation to prevent installation conflicts and minimize the need for reboots
 - Imports the Boxstarter.WinConfig module that provides functions for customizing windows
 - Detects pending reboots and restarts the machine when necessary to avoid installation failures
 - Provides Reboot Resiliency by ensuring the package installation is immediately restarted up on reboot if there is a reboot during the installation.
 - Ensures Installation runs under administrator permissions
 - Supports remote installations allowing packages to be installed on a remote machine

 The .nupkg file for the provided package name is searched in the following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The Chocolatey community feed / OR NugetSources in Boxstarter.config when the 'DelegateChocoSources' switch is used
 This can be configured by editing $($Boxstarter.BaseDir)\Boxstarter.config

 If the package name provided is a URL or resolves to a file, then
 it is assumed that this contains the Chocolatey install script and
 a .nupkg file will be created using the script.

 Boxstarter can install packages onto a remote machine. To accomplish this,
 use either the ComputerName, Session or ConnectionURI parameters. Boxstarter uses
 PowerShell remoting to establish an interactive session on the remote computer.
 Boxstarter configures all the necessary client side remoting settings necessary if
 they are not already configured. Boxstarter will prompt the user to verify that
 this is OK. Using the -Force switch will suppress the prompt. Boxstarter also ensures
 that CredSSP authentication is enabled so that any network calls made by a package will
 forward the users credentials.

 PowerShell Remoting must be enabled on the target machine in order to establish a connection.
 If that machine's WMI ports are accessible, Boxstarter can enable PowerShell remoting
 on the remote machine on its own. Otherwise, it can be manually enabled by entering

 Enable-PSRemoting -Force

 In an administrative PowerShell console on the remote machine.

 .PARAMETER ComputerName
 If provided, Boxstarter will install the specified package name on all computers.
 Boxstarter will create a Remote Session on each computer using the Credentials
 given in the Credential parameter.

 .PARAMETER ConnectionURI
 Specifies one or more Uniform Resource Identifiers (URI) that Boxstarter will use
 to establish a connection with the remote computers upon which the package should
 be installed. Use this parameter if you need to use a non default PORT or SSL.

 .PARAMETER Session
 If provided, Boxstarter will install the specified package in all given Windows
 PowerShell sessions. Note that these sessions may be closed by the time
 Install-BoxstarterPackage finishes. If Boxstarter needs to restart the remote
 computer, the session will be discarded and a new session will be created using
 the ConnectionURI of the original session.

 .PARAMETER BoxstarterConnectionConfig
 If provided, Boxstarter will install the specified package name on all computers
 included in the BoxstarterConnectionConfig. This object contains a ConnectionURI
 a PSCredential, and an optional PSSessionOption. Use this object if you need to
 pass different computers requiring different credentials.

 .PARAMETER PackageName
 The names of one or more NuGet Packages to be installed or URIs or
 file paths pointing to a Chocolatey script. If using package names,
 the .nupkg file for the provided package names are searched in the
 following locations and order:
 - .\BuildPackages relative to the parent directory of the module file
 - The Chocolatey community feed
 - NugetSources in Boxstarter.config when the 'DelegateChocoSources' switch is used

.PARAMETER DisableReboots
If set, reboots are suppressed.

.PARAMETER Credential
The credentials to use for auto logins after reboots. If installing on
a remote machine, this credential will also be used to establish the
connection to the remote machine and also for any scheduled task that
Boxstarter needs to create and run under a local context. Note that auto
login does not work when running from 32-bit PowerShell on a 64-bit
Operating System.

.PARAMETER KeepWindowOpen
Enabling this switch will prevent the command window from closing and
prompt the user to pres the Enter key before the window closes. This
is ideal when not invoking Boxstarter from a console.

.Parameter LocalRepo
This is the path to the local Boxstarter repository where Boxstarter
should look for .nupkg files to install. By default this is located
in the BuildPackages directory just under the root Boxstarter
directory but can be changed with Set-BoxstarterConfig.

.PARAMETER DelegateChocoSources
This enables remote Chocolatey installs to use the same NugetSources
as the local Boxstarter install.

.PARAMETER StopOnPackageFailure
This will stop execution immediately after a Chocolatey package fails to
install.

.PARAMETER RebootTimeout
Only applies to remote installations. The maximum number of seconds
Boxstarter waits for a remote computer to finish rebooting and accept
PowerShell remoting again. Defaults to 1800 seconds (half an hour).

.NOTES
If specifying only one package, Boxstarter calls Chocolatey with the
-force argument and deletes the previously installed package directory.
This means that regardless of whether or not the package had been
installed previously, Boxstarter will attempt to download and reinstall it.
This only holds true for the outer package. If the package contains calls
to choco install for additional packages, those installs will not reinstall if
previously installed.

If an array of package names are passed to Install-BoxstarterPackage,
Boxstarter will NOT apply the above reinstall logic and will skip the
install for any package that had been previously installed.

When establishing a remote connection, Boxstarter uses CredSSP
authentication so that the session can access any network resources
normally accessible to the Credential. If necessary, Boxstarter
configures CredSSP authentication on both the local and remote
machines as well as the necessary Group Policy and WSMan settings
for credential delegation. When the installation completes,
Boxstarter rolls back all settings that it changed to their original
state.

If Boxstarter is not running in an elevated console, it will not attempt
to enable CredSSP locally if it is not already enabled. It will also not
try to enable PowerShell remoting if not running as administrator.

When using a Windows PowerShell session instead of ComputerName or
ConnectionURI, Boxstarter will use the authentication mechanism of the
existing session and will not configure CredSSP if the session provided
is not using CredSSP. If the session is not using CredSSP, it may be
denied access to network resources normally accessible to the Credential
being used. If you do need to access network resources external to the
session, you should use CredSSP when establishing the connection.

Auto login will not work when running Boxstarter from a 32-bit PowerShell
console on a 64-bit Operating System.

.INPUTS
ComputerName, ConnrectionURI and Session may all be specified on the
pipeline.

.OUTPUTS
Returns a PSObject for each session, ComputerName or ConnectionURI or a
single PSObject for local installations. The PSObject has the following
properties:

ComputerName: The name of the computer where the package was installed

StartTime: The time that the installation began

FinishTime: The time that Boxstarter finished the installation

Completed: True or False indicating if Boxstarter was able to complete
the installation without a terminating exception interrupting the install.
Even if this value is True, it does not mean that all components installed
in the package succeeded. Boxstarter will not terminate an installation if
individual Chocolatey packages fail. Use the Errors property to discover
errors that were raised throughout the installation.

Errors: An array of all errors encountered during the duration of the
installation.

.EXAMPLE
Invoke-ChocolateyBoxstarter "example1","example2"

This installs the example1 and example2 .nupkg files. If pending
reboots are detected, Boxstarter will restart the machine. Boxstarter
will not perform automatic logins after restart since no Credential
was given.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -Package https://gist.github.com/mwrock/6771863/raw/b579aa269c791a53ee1481ad01711b60090db1e2/gistfile1.txt `
   -Credential $cred

This installs the script uploaded to the github gist. The credentials
of the user mwrock are used to automatically login the user if
Boxstarter needs to reboot the machine.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ComputerName MyOtherComputer.mydomain.com -Package MyPackage -Credential $cred

This installs the MyPackage package on MyOtherComputer.mydomain.com.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ComputerName MyOtherComputer.mydomain.com -Package MyPackage -Credential $cred -DelegateChocoSources

This installs the MyPackage package on MyOtherComputer.mydomain.com, using the Chocolatey feeds configured in Boxstarter.config

.EXAMPLE
$cred=Get-Credential mwrock
$session=New-PSSession SomeComputer -Credential $cred
Install-BoxstarterPackage -Session $session -Package MyPackage -Credential $cred

This installs the MyPackage package on an existing session established with
SomeComputer. A Credential is still passed to Boxstarter even though it is
also used to establish the session because Boxstarter will need it for logons
and creating Scheduled Tasks on SomeComputer. If Boxstarter does need to
reboot SomeComputer, it will need to create a new session after SomeComputer
has rebooted and then $session will no longer be in an Available state when
Install-BoxstarterPackage completes.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ConnectionURI http://RemoteComputer:59876/wsman -Package MyPackage -Credential $cred

This installs the MyPackage package on RemoteComputer which does not
listen on the default wsman port but has been configured to listen
on port 59876.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage -ComputerName MyOtherComputer.mydomain.com -Package MyPackage -Credential $cred -Force

This installs the MyPackage package on MyOtherComputer.mydomain.com.
Because the -Force parameter is used, Boxstarter will not prompt the
user to confirm that it is OK to enable PowerShell remoting if it is
not already enabled. It will attempt to enable it without prompts.

.EXAMPLE
$cred=Get-Credential mwrock
"computer1","computer2" | Install-BoxstarterPackage -Package MyPackage -Credential $cred -Force

This installs the MyPackage package on computer1 and computer2
Because the -Force parameter is used, Boxstarter will not prompt the
user to confirm that it is OK to enable PowerShell remoting if it is
not already enabled. It will attempt to enable it without prompts.

Using -Force is especially advisable when installing packages on multiple
computers because otherwise, if one computer is not accessible, the command
will prompt the user if it is OK to try and configure the computer before
proceeding to the other computers.

.EXAMPLE
$cred1=Get-Credential mwrock
$cred2=Get-Credential domain\mwrock
(New-Object -TypeName BoxstarterConnectionConfig -ArgumentList "http://computer1:5985/wsman",$cred1,$null), `
(New-Object -TypeName BoxstarterConnectionConfig -ArgumentList "http://computer2:5985/wsman",$cred2,$null) |
Install-BoxstarterPackage -Package MyPackage

This installs the MyPackage package on computer1 and computer2 and uses
different credentials for each computer.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage script.ps1 -Credential $cred

This installs the script located at script.ps1
in the command line's current directory.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage \\server\share\script.ps1 -Credential $cred

This invokes Boxstarter and installs the script located at the
specified share.

.EXAMPLE
$cred=Get-Credential mwrock
Install-BoxstarterPackage win8Install -LocalRepo \\server\share\boxstarter -Credential $cred

This installs the Win8Install .nupkg. Boxstarter will look
for the Win8Install .nupkg file in the \\serer\share\boxstarter
directory.


.LINK
https://boxstarter.org
about_boxstarter_chocolatey
#>
    [CmdletBinding(DefaultParameterSetName="Package")]
	param(
        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="BoxstarterConnectionConfig")]
        [BoxstarterConnectionConfig[]]$BoxstarterConnectionConfig,

        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="ComputerName")]
        [string[]]$ComputerName,

        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="ConnectionUri")]
        [Uri[]]$ConnectionUri,

        [parameter(Mandatory=$true, Position=0, ValueFromPipeline=$True, ParameterSetName="Session")]
        [System.Management.Automation.Runspaces.PSSession[]]$Session,

        [parameter(Mandatory=$true, Position=0, ParameterSetName="Package")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="ComputerName")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="ConnectionUri")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="Session")]
        [parameter(Mandatory=$true, Position=1, ParameterSetName="BoxstarterConnectionConfig")]
        [string[]]$PackageName,

        [Management.Automation.PsCredential]$Credential,

        [switch]$Force,

        [switch]$DisableReboots,

        [parameter(ParameterSetName="Package")]
        [switch]$KeepWindowOpen,

        [string]$LocalRepo,

        [switch]$DisableRestart,

        [switch]$DelegateChocoSources,

        [switch]$StopOnPackageFailure,

        [parameter(ParameterSetName="ComputerName")]
        [parameter(ParameterSetName="ConnectionUri")]
        [parameter(ParameterSetName="Session")]
        [parameter(ParameterSetName="BoxstarterConnectionConfig")]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$RebootTimeout = 1800
    )
    $CurrentVerbosity=$global:VerbosePreference
    try {

        if($PSBoundParameters["Verbose"] -eq $true) {
            $global:VerbosePreference="Continue"
        }

        #If no PSRemoting based param's are present, we just run locally
        if($PsCmdlet.ParameterSetName -eq "Package"){
            Invoke-Locally @PSBoundParameters
            return
        }

        #me me me!
        Write-BoxstarterLogo

        #Convert pipeline to array
        $list=@($input)
        if($list.Count){
            Set-Variable -Name $PsCmdlet.ParameterSetName -Value $list
        }

        $sessionArgs=@{}
        if($Credential){
            $sessionArgs.Credential=$Credential
        }

        $delegateSources = if ($DelegateChocoSources) { $true} else { $false }

        #If $sessions are being provided we assume remoting is setup on both ends
        #and don't need to test, configure and tear down
        if($Session -ne $null){
            Process-Sessions $Session $sessionArgs $delegateSources $RebootTimeout
            return
        }

        #We need the computer names to configure remoting
        if(!$ComputerName){
            if($BoxstarterConnectionConfig){
                $uris = $BoxstarterConnectionConfig | % { $_.ConnectionURI }
            }
            else{
                $uris = $ConnectionUri
            }
            $ComputerName = Get-ComputerNames $uris
        }

        try{
            #Enable remoting settings if necessary on client
            $ClientRemotingStatus=Enable-BoxstarterClientRemoting $ComputerName

            #If unable to enable remoting on the client, abort
            if(!$ClientRemotingStatus.Success){return}

            $CredSSPStatus=Enable-BoxstarterCredSSP $ComputerName

            if($ConnectionURI){
                $ConnectionUri | %{
                    $sessionArgs.ConnectionURI = $_
                    Write-BoxstarterMessage "Installing $packageName on $($_.ToString())"
                    Install-BoxstarterPackageOnComputer $_.Host $sessionArgs $PackageName $DisableReboots $CredSSPStatus $delegateSources $RebootTimeout
                }
            }
            elseif($BoxstarterConnectionConfig) {
                $BoxstarterConnectionConfig | %{
                    $sessionArgs.ConnectionURI = $_.ConnectionURI
                    if($_.Credential){
                        $sessionArgs.Credential = $_.Credential
                    }
                    if($_.PSSessionOption){
                        $sessionArgs.SessionOption = $_.PSSessionOption
                    }
                    Install-BoxstarterPackageOnComputer $_.ConnectionURI.Host $sessionArgs $PackageName $DisableReboots $CredSSPStatus $delegateSources $RebootTimeout
                }
            }
            else {
                $ComputerName | %{
                    $sessionArgs.ComputerName = $_
                    Install-BoxstarterPackageOnComputer $_ $sessionArgs $PackageName $DisableReboots $CredSSPStatus $delegateSources $RebootTimeout
                }
            }
        }
        finally{
            #Client settings should be as they were when we started
            Rollback-ClientRemoting $ClientRemotingStatus $CredSSPStatus
        }
    }
    finally{
        $global:VerbosePreference=$CurrentVerbosity
    }
}

function Get-ComputerNames([URI[]]$ConnectionUris) {
    $computerNames = @()

    Write-BoxstarterMessage "resolving URIs to computer names..." -Verbose
    $ConnectionUris | %{
        if($_ -eq $null) {
            Write-BoxstarterMessage "Tried to resolve Null URI" -Verbose
        }
        else {
            Write-BoxstarterMessage "$($_ -is [uri]) found $($_.Host) for $($_.ToString())" -Verbose
            $computerNames+=$_.Host
        }
    }
    return $computerNames
}

function Process-Sessions($sessions, $sessionArgs, $delegateSources, $RebootTimeout){
    $Sessions | %{
        Write-BoxstarterMessage "Processing Session..." -Verbose
        Set-SessionArgs $_ $sessionArgs
        $record = Start-Record $_.ComputerName
        try {
            if(-not (Install-BoxstarterPackageForSession $_ $PackageName $DisableReboots $sessionArgs $delegateSources -RebootTimeout $RebootTimeout)){
                $record.Completed=$false
            }
        }
        catch {
            $record.Completed=$false
        }
        finally{
            Finish-Record $record
        }
    }
}

function Start-Record($computerName) {
    $global:error.Clear()
    $props = @{
        StartTime = Get-Date
        Completed = $true
        ComputerName = $computerName
        Errors = @()
        FinishTime = $null
    }
    return (New-Object PSObject -Prop $props)
}

function Finish-Record($obj) {
    Write-BoxstarterMessage "Composing record for pipeline..." -Verbose
    $obj.FinishTime = Get-Date
    $global:error | %{
        if($_.CategoryInfo -ne $null -and $_.CategoryInfo.Category -eq "OperationStopped"){
            Log-BoxstarterMessage $_
        }
        else {
            $obj.Errors += $_
        }
    }
    Write-BoxstarterMessage "writing object..." -Verbose
    Write-Output $obj
    Write-BoxstarterMessage "object written..." -Verbose
}

function Install-BoxstarterPackageOnComputer ($ComputerName, $sessionArgs, $PackageName, $DisableReboots, $CredSSPStatus, $delegateSources, $RebootTimeout){
    $record = Start-Record $ComputerName
    try {
        if(!(Enable-RemotingOnRemote $sessionArgs $ComputerName)){
            Write-Error "Unable to access remote computer via PowerShell Remoting or WMI. You can enable it by running: Enable-PSRemoting -Force from an Administrator PowerShell console on the remote computer."
            $record.Completed=$false
            return
        }

        if($CredSSPStatus.Success){
            $enableCredSSP = Should-EnableCredSSP $sessionArgs $computerName
        }

        Write-BoxstarterMessage "Creating a new session with $computerName..." -Verbose
        $session = New-PSSession @sessionArgs -Name Boxstarter

        if(-not (Install-BoxstarterPackageForSession $session $PackageName $DisableReboots $sessionArgs $enableCredSSP $delegateSources $RebootTimeout)){
            $record.Completed=$false
        }
    }
    catch {
        $record.Completed=$false
        Write-Error $_
    }
    finally{
        Finish-Record $record
    }
}

function Install-BoxstarterPackageForSession($session, $PackageName, $DisableReboots, $sessionArgs, $enableCredSSP, $delegateSources, $RebootTimeout) {
    try{
        if($session.Availability -ne "Available"){
            Write-Error (New-Object -TypeName ArgumentException -ArgumentList "The Session is not Available")
            return $false
        }

        for($count = 1; $count -le 5; $count++) {
            try {
                Write-BoxstarterMessage "Attempt #$count to copy Boxstarter modules to $($session.ComputerName)" -Verbose
                Invoke-SetupBoxstarterModuleAndLocalRepo $session $delegateSources
                break
            }
            catch {
                if($global:Error.Count -gt 0){$global:Error.RemoveAt(0)}
                if($count -eq 5) { throw $_ }
            }
        }

        if($enableCredSSP){
            $credSSPSession = Enable-RemoteCredSSP $sessionArgs
            if($session -ne $null -and $credSSPSession -ne $null){
                Write-BoxstarterMessage "CredSSP session succeeded. Replacing sessions..."
                Remove-PSSession $session -ErrorAction SilentlyContinue
                $session=$credSSPSession
            }
        }

        Invoke-Remotely ([ref]$session) $PackageName $DisableReboots $sessionArgs $RebootTimeout
        return $true
    }
    finally {
        Write-BoxstarterMessage "checking if session should be removed..." -Verbose
        if($session -ne $null -and $session.Name -eq "Boxstarter") {
            Write-BoxstarterMessage "Removing session $($session.id)..." -Verbose
            Remove-PSSession $Session
            Write-BoxstarterMessage "Session removed..." -Verbose
            $Session = $null
        }

        if($sessionArgs.Authentication){
            $sessionArgs.Remove("Authentication")
        }
        if($enableCredSSP){
            Disable-RemoteCredSSP $sessionArgs
        }
    }
}

function Invoke-Locally {
    param(
        [string[]]$PackageName,

        [Management.Automation.PsCredential]$Credential,

        [switch]$Force,

        [switch]$DisableReboots,

        [switch]$KeepWindowOpen,

        [switch]$DisableRestart,

        [string]$LocalRepo,

        [switch]$StopOnPackageFailure
    )
    if($PSBoundParameters.ContainsKey("Credential")){
        if($Credential -ne $null) {
            $PSBoundParameters.Add("Password",$PSBoundParameters["Credential"].Password)
        }
        $PSBoundParameters.Remove("Credential") | Out-Null
    }
    else {
        $PSBoundParameters.Add("NoPassword",$True)
    }
    if($PSBoundParameters.ContainsKey("Force")){
        $PSBoundParameters.Remove("Force") | Out-Null
    }
    $PSBoundParameters.Add("BootstrapPackage", $PSBoundParameters.PackageName)
    $PSBoundParameters.Remove("PackageName") | Out-Null

    $record = Start-Record 'localhost'
    try {
        Invoke-ChocolateyBoxstarter @PSBoundParameters
    }
    catch {
        $record.Completed=$false
        throw
    }
    finally{
        Finish-Record $record
    }
}

function Enable-RemotingOnRemote ($sessionArgs, $ComputerName){
    Write-BoxstarterMessage "Testing remoting access on $ComputerName..."
    try {
        $remotingTest = Invoke-Command @sessionArgs { Get-WmiObject Win32_ComputerSystem } -ErrorAction Stop
    }
    catch {
        Write-BoxstarterMessage $_.ToString() -Verbose
        $sessionArgs.Keys | % {
            Write-BoxstarterMessage "session arg key: $_ has value $($sessionArgs[$_])" -Verbose
        }
        Write-BoxstarterMessage "using credential username $($sessionArgs.Credential.UserName)" -Verbose
        $global:error.RemoveAt(0)
    }
    if($remotingTest -eq $null){
        Write-BoxstarterMessage "PowerShell Remoting is not enabled or accessible on $ComputerName" -Verbose
        if(Test-Admin) {
            $wmiTest=Invoke-WmiMethod -ComputerName $ComputerName -Credential $sessionArgs.Credential Win32_Process Create -Args "cmd.exe" -ErrorAction SilentlyContinue
        }
        if($wmiTest -eq $null){
            if($global:Error.Count -gt 0){ $global:Error.RemoveAt(0) }
            return $false
        }
        if($Force -or (Confirm-Choice "PowerShell Remoting is not enabled on Remote computer. Should Boxstarter enable PowerShell remoting? This will also change the Network Location type on the remote machine to PRIVATE if it is currently PUBLIC.")){
            Write-BoxstarterMessage "Enabling PowerShell Remoting on $ComputerName"
            Enable-RemotePSRemoting $ComputerName $sessionArgs.Credential
        }
        else {
            Write-BoxstarterMessage "Not enabling local PowerShell Remoting on $ComputerName. Aborting package install"
            return $False
        }
    }
    else {
        Write-BoxstarterMessage "Remoting is accessible on $ComputerName"
    }
    return $True
}

function Invoke-SetupBoxstarterModuleAndLocalRepo($Session, $delegateSources) {
    if ($LocalRepo) { $Boxstarter.LocalRepo = $LocalRepo }

    Write-BoxstarterMessage "Copying Boxstarter Modules and LocalRepo packages at $($Boxstarter.BaseDir) to `$env:temp\Boxstarter on $($Session.ComputerName)..."
    Invoke-Command -Session $Session { mkdir $env:temp\Boxstarter\BuildPackages -Force | Out-Null }
    Send-File "$($Boxstarter.BaseDir)\Boxstarter.Chocolatey\Boxstarter.zip" "Boxstarter\Boxstarter.zip" $Session
    Get-ChildItem "$($Boxstarter.LocalRepo)\*.nupkg" | ForEach-Object {
        Write-BoxstarterMessage "Copying $($_.Name) to $($Session.ComputerName)" -Verbose
        Send-File "$($_.FullName)" "Boxstarter\BuildPackages\$($_.Name)" $Session
    }
    Write-BoxstarterMessage "Expanding modules on $($Session.ComputerName)" -Verbose
    Invoke-Command -Session $Session {
        Set-ExecutionPolicy Bypass -Force

        function Expand-ZipFile($ZipFilePath, $DestinationFolder) {
            if ($PSVersionTable.PSVersion.Major -ge 4) {
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipFilePath)
        
                    foreach ($entry in $archive.Entries) {
                        $entryTargetFilePath = [System.IO.Path]::Combine($DestinationFolder, $entry.FullName)
                        $entryDir = [System.IO.Path]::GetDirectoryName($entryTargetFilePath)
        
                        if (!(Test-Path $entryDir)) {
                            New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
                        }
        
                        if (!$entryTargetFilePath.EndsWith("/")) {
                            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $true);
                        }
                    }
                }
                catch {
                    throw $_
                }
            }
            else {
                #original method
                $shellApplication = new-object -com shell.application
                $zipPackage = $shellApplication.NameSpace($ZipFilePath)
                $DestinationF = $shellApplication.NameSpace($DestinationFolder)
                $DestinationF.CopyHere($zipPackage.Items(), 0x10)
            }
        }

        Expand-ZipFile -ZipFilePath "$($env:temp)\Boxstarter\Boxstarter.zip" -DestinationFolder "$($env:temp)\Boxstarter"
        
        [xml]$configXml = Get-Content (Join-Path $env:temp\Boxstarter Boxstarter.config)
        if ($null -ne $configXml.config.LocalRepo) {
            $configXml.config.RemoveChild(($configXml.config.ChildNodes | Where-Object { $_.Name -eq "LocalRepo" }))
            $configXml.Save((Join-Path $env:temp\Boxstarter Boxstarter.config))
        }
    }
    if ($delegateSources) {
        Write-BoxstarterMessage "Delegating Boxstarter NugetSources to remote host..."
        $localCfg = (Join-Path $($Boxstarter.BaseDir) Boxstarter.config)
        [xml]$configXml = Get-Content $localCfg
        [string]$theSources = $($configXml.config.NugetSources)
        Write-BoxstarterMessage "$localCfg - NugetSources: '$theSources'" -Verbose
        Invoke-Command -Session $Session {
            param([string]$theSources)
            Set-ExecutionPolicy Bypass -Force
            $cfgPath = (Join-Path $env:temp\Boxstarter Boxstarter.config)
            [xml]$configXml = Get-Content $cfgPath
            $configXml.config.NugetSources = $theSources
            $configXml.Save($cfgPath)
        } -ArgumentList $theSources
    }

    # ensure Chocolatey is present on remote host ...
    Invoke-Command -Session $Session {
        Set-ExecutionPolicy Bypass -Force
        # we don't want to install chocolatey if it's alredy present!
        if ($env:ChocolateyInstall) {
            if (Test-Path $env:ChocolateyInstall) {
                Write-Host "$env:ChocolateyInstall is already present on remote host!"
                return
            }
        }
        $defaultChocoBase = 'C:\ProgramData\chocolatey\'
        # in case $env:ChocolateyInstall is not known in the remote session but choco is on the host,
        # we want to ensure we do not re-install the bundled version of choco
        # NOTE: there _are_ edge-cases where this won't work
        if (Test-Path "${defaultChocoBase}choco.exe") {
            Write-Host 'choco.exe is already present at remote host (default location)'
            if (-Not $env:ChocolateyInstall) {
                Write-Host 'NOTE: env:ChocolateyInstall manually set in this session.'
                $env:ChocolateyInstall = $defaultChocoBase
            }
            return
        }
        # choco is not present on remote host, we do have to install it!
        Write-Host "installing Chocolatey on remote host..."
        $chocoNupkg = Get-Item "$($env:temp)\Boxstarter\Boxstarter.Chocolatey\chocolatey\*.nupkg" | Select-Object -First 1

        function Expand-ZipFile($ZipFilePath, $DestinationFolder) {
            if ($PSVersionTable.PSVersion.Major -ge 4) {
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipFilePath)

                    foreach ($entry in $archive.Entries) {
                        $entryTargetFilePath = [System.IO.Path]::Combine($DestinationFolder, $entry.FullName)
                        $entryDir = [System.IO.Path]::GetDirectoryName($entryTargetFilePath)

                        if (!(Test-Path $entryDir)) {
                            New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
                        }

                        if (!$entryTargetFilePath.EndsWith("/")) {
                            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryTargetFilePath, $true);
                        }
                    }
                }
                catch {
                    throw $_
                }
            }
            else {
                #original method
                $shellApplication = new-object -com shell.application
                $zipPackage = $shellApplication.NameSpace($ZipFilePath)
                $DestinationF = $shellApplication.NameSpace($DestinationFolder)
                $DestinationF.CopyHere($zipPackage.Items(), 0x10)
            }
        }

        Expand-ZipFile -ZipFilePath $chocoNupkg.FullName -DestinationFolder "$($env:temp)\boxstarter_chocolatey"
        Import-Module "$($env:temp)\boxstarter_chocolatey\tools\chocolateysetup.psm1" -DisableNameChecking
        Initialize-Chocolatey
    }
    
}

function Invoke-RemoteBoxstarter($Package, $Credential, $DisableReboots, $session) {
    Write-BoxstarterMessage "Running remote install..."
    $remoteResult = Invoke-Command -session $session {
        param($SuppressLogging,$pkg,$Credential,$DisableReboots, $verbosity, $ProgressArgs, $debug)
        $global:VerbosePreference=$verbosity
        $global:DebugPreference=$debug
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        if($Credential -eq $null){
            $currentUser = Get-CurrentUser
            $credential = (New-Object Management.Automation.PsCredential ("$($currentUser.Domain)\$($currentUser.Name)", (New-Object System.Security.SecureString)))
        }
        Create-BoxstarterTask $Credential
        Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
        $Boxstarter.SuppressLogging=$SuppressLogging
        $global:Boxstarter.ProgressArgs=$ProgressArgs
        $result=$null
        try {
            $resultToReturn = @{}
            $result = Invoke-ChocolateyBoxstarter $pkg -Password $Credential.password -DisableReboots:$DisableReboots
            if($Boxstarter.IsRebooting){
                $resultToReturn.Result="Rebooting"
            }
            elseif($result -eq $true){
                $resultToReturn.Result="Completed"
            }
            $resultToReturn.Errors = $Global:Error
            return $resultToReturn
        }
        catch{
            throw $_
        }
    } -ArgumentList $Boxstarter.SuppressLogging, $Package, $Credential, $DisableReboots, $global:VerbosePreference, $global:Boxstarter.ProgressArgs, $global:DebugPreference
    if($remoteResult.Errors -ne $null) {
        $global:Error.AddRange($remoteResult.Errors)
    }
    Write-BoxstarterMessage "Result from Remote Boxstarter: $($remoteResult.Result)" -Verbose
    return $remoteResult
}

function Test-RebootingOrDisconnected($RemoteResult) {
    if($remoteResult -eq $null -or $remoteResult.Result -eq $null -or $remoteResult.Result -eq "Rebooting") {
        return $true
    }
    else {
        return $false
    }
}

function Wait-ForSessionToClose($session, $timeoutSeconds = 120) {
    Write-BoxstarterMessage "Waiting for $($session.ComputerName) to sever remote session..."
    $timeout=0
    while($session.State -eq "Opened" -and $timeout -lt $timeoutSeconds){
        $timeout += 2
        start-sleep -seconds 2
    }
    if($session.State -eq "Opened") {
        Write-BoxstarterMessage "$($session.ComputerName) did not sever the remote session within $timeoutSeconds seconds. The restart may be delayed. Waiting for it to complete..." -Color Yellow
    }
}

function Get-RemoteBootTime($Session) {
    try {
        return Invoke-Command -Session $Session {
            $os = Get-WmiObject Win32_OperatingSystem
            [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime).ToUniversalTime()
        } -ErrorAction Stop
    }
    catch {
        Write-BoxstarterMessage "Failed to read boot time : $($global:Error[0])" -Verbose
        $global:Error.RemoveAt(0)
    }
}

function Test-RemoteRebooted($Session, $BootTimeBefore) {
    if ($BootTimeBefore -eq $null) {
        Write-BoxstarterMessage "Boot time before install is unknown. Relying on pending reboot checks only." -Verbose
        return $true
    }
    $bootTimeNow = Get-RemoteBootTime $Session
    Write-BoxstarterMessage "Boot time before install: $BootTimeBefore, boot time now: $bootTimeNow" -Verbose
    # LastBootUpTime can drift by a few seconds (i.e. ntp-sync) - add grace period
    return ($bootTimeNow -ne $null -and ($bootTimeNow - $BootTimeBefore).TotalSeconds -gt 10)
}

function Test-ShutDownInProgress($Session) {
    $response=Invoke-Command -Session $Session {
        try {
        $systemMetrics = Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SystemMetrics
{
    private const int SM_SHUTTINGDOWN = 0x2000;

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int smIndex);

    public static bool IsShuttingdown()
    {
        return (GetSystemMetrics(SM_SHUTTINGDOWN) != 0);
    }

}
"@ -PassThru
        } catch {}
        if ($systemMetrics){
            return $systemMetrics::IsShuttingdown()
        }
    }

    if($response -eq $false) {
        Write-BoxstarterMessage "System Shutdown not in progress" -Verbose
    }
    else {
        Write-BoxstarterMessage "System Shutdown in progress" -Verbose
    }

    return $response
}

function Test-Reconnection($Session, $sessionPID) {
    $reconnected = $false

    #If there is a pending reboot then session is in the middle of a restart
    try{
        $response=Invoke-Command -Session $session {
            Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
            return Test-PendingReboot
        } -ErrorAction Stop
    } catch {
        Write-BoxstarterMessage "Failed to test pending reboot : $($global:Error[0])" -Verbose
        $global:Error.RemoveAt(0)
    }
    Write-BoxstarterMessage "Reboot check returned $response" -Verbose


    if($response -ne $null -and $response -eq $false){
        #Check for a system shutdown in progress
        $response = Test-ShutDownInProgress $session

        if($response -eq $false) {
            $reconnected = $true #Session is connectible
            try{
                #In case previous session's task is still alive kill it so it does not lock anything
                Write-BoxstarterMessage "Killing $sessionPID" -Verbose
                Invoke-Command -Session $session {
                    param($p)
                    if(Get-Process -Id $p -ErrorAction SilentlyContinue){
                        KILL $p -ErrorAction Stop -Force
                    }
                    else {
                        $global:Error.RemoveAt(0)
                    }
                } -ArgumentList $sessionPID
            } catch{
                Write-BoxstarterMessage "Failed to kill $sessionPID : $($global:Error[0])" -Verbose
                $global:Error.RemoveAt(0)
            }
        }
    }
    #if the session is pending a reboot but not in the middle of a system shutdown,
    #try to invoke a reboot to prevent us from hanging while waiting
    elseif($response -eq $true -and !(Test-ShutDownInProgress $session)){
        Write-BoxstarterMessage "Attempting to restart $($session.ComputerName)" -Verbose
        Invoke-Command -Session $session {
            Import-Module $env:temp\Boxstarter\Boxstarter.Chocolatey\Boxstarter.Chocolatey.psd1
            $Boxstarter.RebootOK=$true
            if(Test-PendingReboot){restart-Computer -Force }
        } -ErrorAction SilentlyContinue
    }

    return $reconnected
}

function Invoke-Remotely([ref]$session, $Package, $DisableReboots, $sessionArgs, $RebootTimeout=1800){
    Write-BoxstarterMessage "Invoking remote install" -verbose
    while($session.value.Availability -eq "Available") {
        $sessionPID = try { Invoke-Command -Session $session.value { return $PID } } catch { $global:Error.RemoveAt(0) }
        Write-BoxstarterMessage "Session's process ID is $sessionPID" -verbose
        if($sessionPID -ne $null) {
            $bootTimeBefore = Get-RemoteBootTime $session.value
            $remoteResult = Invoke-RemoteBoxstarter $Package $sessionArgs.Credential $DisableReboots $session.value
        }

        if(Test-RebootingOrDisconnected $remoteResult) {
            $computerName = $session.value.ComputerName
            $deadline = (Get-Date).AddSeconds($RebootTimeout)
            Wait-ForSessionToClose $session.value ([math]::Min(120, $RebootTimeout))

            $reconnected=$false
            Write-BoxstarterMessage "Waiting for $($session.value.ComputerName) to respond to remoting..."
            Do{
                if($session.value -ne $null){
                    Write-BoxstarterMessage "removing session..." -verbose
                    try { Remove-PSSession $session.value } catch { $global:Error.RemoveAt(0) }
                    $session.value = $null
                    Write-BoxstarterMessage "session removed..." -verbose
                }
                $response=$null
                start-sleep -seconds 2
                Write-BoxstarterMessage "attempting to recreate session..." -verbose
                $session.value = New-PSSession @sessionArgs -Name Boxstarter -ErrorAction SilentlyContinue
                if($session.value -eq $null) {
                    Write-BoxstarterMessage "New session is null..." -verbose
                    $global:Error.RemoveAt(0)
                }
                elseif($session.value -ne $null -and $Session.value.Availability -eq "Available"){
                    if($remoteResult.Result -eq "Rebooting" -and !(Test-RemoteRebooted $session.value $bootTimeBefore)) {
                        Write-BoxstarterMessage "$computerName accepts remoting but has not restarted yet..." -verbose
                    }
                    else {
                        Write-BoxstarterMessage "testing new session..." -verbose
                        if($remoteResult.Result -eq "Rebooting"){$sessionPID=-1}
                        $reconnected = Test-Reconnection $session.value $sessionPID
                    }
                }
                else {
                    Write-BoxstarterMessage "new session is not available..." -verbose
                }

                if(!$reconnected -and (Get-Date) -gt $deadline) {
                    $message = "Timed out after $RebootTimeout seconds waiting for $computerName to restart. Use 'RebootTimeout' parameter to wait longer."
                    throw New-Object -TypeName TimeoutException $message
                }
            }
            Until($reconnected -eq $true)
        }
        else {
            break
        }
    }
}

function Set-SessionArgs($session, $sessionArgs) {
    $uri = try { Invoke-Command $session {return $PSSenderInfo.ConnectionString} -ErrorAction SilentlyContinue } catch{}
    if($uri){
        $sessionArgs.ConnectionURI=$uri
    }
    else{
        $sessionArgs.ComputerName=$session.ComputerName
    }
}

function Should-EnableCredSSP($sessionArgs, $computerName) {
    Write-BoxstarterMessage "Testing remote CredSSP..." -Verbose
    if($sessionArgs.Credential){
        $uriArgs=@{}
        if($sessionArgs.ConnectionURI){
            $uri = [URI]$sessionArgs.ConnectionURI
            $uriArgs = @{Port=$uri.port;UseSSL=($uri.scheme -eq "https")}
        }
        try {
            $credsspEnabled = Test-WsMan -ComputerName $ComputerName @uriArgs -Credential $SessionArgs.Credential -Authentication CredSSP -ErrorAction SilentlyContinue
        }
        catch {
            Write-BoxstarterMessage "Exception from testing WSMan for CredSSP access" -Verbose
            try { $xml=[xml]$_ } catch { $global:Error.RemoveAt(0) }
            if($xml -ne $null) {
                Write-BoxstarterMessage "WSMan Fault Found" -Verbose
                Write-BoxstarterMessage "$($xml.OuterXml)" -Verbose
            }
            else {
                Write-BoxstarterMessage $_ -Verbose
            }
        }
        if($credsspEnabled -eq $null){
            Write-BoxstarterMessage "Need to enable CredSSP on server" -Verbose
            if($global:Error.Count -gt 0){ $global:Error.RemoveAt(0) }
            return $True
        }
        else{
            Write-BoxstarterMessage "CredSSP test response:" -Verbose
            [System.Xml.XmlElement]$xml=$credsspEnabled
            if($xml -ne $null) {
                Write-BoxstarterMessage "WSMan XML Found..." -Verbose
                Write-BoxstarterMessage "$($xml.OuterXml)" -Verbose
            }
            $sessionArgs.Authentication="CredSSP"
        }
    }
    Write-BoxstarterMessage "Do not need to enable CredSSP on server" -Verbose
    return $false
}

function Enable-RemoteCredSSP($sessionArgs) {
    Write-BoxstarterMessage "Creating a scheduled task to enable CredSSP Authentication on $ComputerName..."
    $n=Invoke-RetriableScript {
        $splat=$args[0]
        Invoke-Command @splat {
            param($Credential, $verbosity)
            $VerbosePreference = $verbosity
            Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
            Create-BoxstarterTask $Credential
            Invoke-FromTask "Enable-WSManCredSSP -Role Server -Force | Out-Null"
            Remove-BoxstarterTask
        } -ArgumentList @($args[0].Credential, $VerbosePreference)
    } $sessionArgs
    $sessionArgs.Authentication="CredSSP"
    Write-BoxstarterMessage "Creating New session with CredSSP Authentication..." -Verbose
    try {
        $session = Invoke-RetriableScript {
            $splat=$args[0]
            $s = New-PSSession @splat -Name Boxstarter -ErrorAction Stop
            return $s
        } $sessionArgs
    }
    catch {
        $sessionArgs.Remove("Authentication")
        $session=$null
        Write-BoxstarterMessage "Unable to create CredSSP session. Error was: $($_.ToString())" -Verbose
        $global:error.RemoveAt(0)
    }
    return $session
}

function Disable-RemoteCredSSP ($sessionArgs){
    Write-BoxstarterMessage "Disabling CredSSP Authentication on $ComputerName" -Verbose
    Invoke-Command @sessionArgs {
        param($Credential, $verbosity)
        $Global:VerbosePreference = $verbosity
        Import-Module $env:temp\Boxstarter\Boxstarter.Common\Boxstarter.Common.psd1 -DisableNameChecking
        Create-BoxstarterTask $Credential
        $taskResult = Invoke-FromTask "Disable-WSManCredSSP -Role Server"
        Write-BoxstarterMessage "result from disabling CredSSP is: $taskResult" -Verbose
        Remove-BoxstarterTask
    } -ArgumentList $sessionArgs.Credential, $Global:VerbosePreference
    Write-BoxstarterMessage "Finished disabling CredSSP Authentication on $ComputerName" -Verbose
}

function Rollback-ClientRemoting($ClientRemotingStatus, $CredSSPStatus) {
    Write-BoxstarterMessage "Rolling back remoting settings changed by Boxstarter..."
    if($ClientRemotingStatus.PreviousTrustedHosts -ne $null){
        $currentHosts=Get-Item "wsman:\localhost\client\trustedhosts"
        if($currentHosts.Value -ne $ClientRemotingStatus.PreviousTrustedHosts) {
            Write-BoxstarterMessage "Reseting wsman Trusted Hosts to $($ClientRemotingStatus.PreviousTrustedHosts)" -Verbose
            Set-Item "wsman:\localhost\client\trustedhosts" -Value "$($ClientRemotingStatus.PreviousTrustedHosts)" -Force
        }
    }
    if($CredSSPStatus -ne $null -and $CredSSPStatus.Success){
        try {Disable-WSManCredSSP -Role Client -ErrorAction SilentlyContinue } catch{ Write-BoxstarterMessage "Unable to disable CredSSP locally" }
        if($CredSSPStatus.PreviousCSSPTrustedHosts -ne $null){
            try{
                Write-BoxstarterMessage "Reseting CredSSP Trusted Hosts to $($CredSSPStatus.PreviousCSSPTrustedHosts.Replace('wsman/',''))" -Verbose
                Enable-WSManCredSSP -DelegateComputer ($CredSSPStatus.PreviousCSSPTrustedHosts.Replace("wsman/","").split(",") | Get-Unique) -Role Client -force | Out-Null
            }
            catch{}
        }
        Write-BoxstarterMessage "Reseting GroupPolicy for Credentials Delegation" -Verbose
        if(Test-Path "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly") {
            (Get-Item "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly").Property | % {
                if([int]$_ -gt $CredSSPStatus["PreviousFreshNTLMCredDelegationHostCount"]) {
                    Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly" -Name $_
                }
            }
        }

        if(Test-Path "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials") {
            (Get-Item "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials").Property | % {
                if([int]$_ -gt $CredSSPStatus["PreviousFreshCredDelegationHostCount"]) {
                    Remove-ItemProperty "$(Get-CredentialDelegationKey)\CredentialsDelegation\AllowFreshCredentials" -Name $_
                }
            }
        }
    }
}

<# Support for expanding Boxstarter modules on Server Core by (C) 2017 United Parcel Service of America, Inc. #>
