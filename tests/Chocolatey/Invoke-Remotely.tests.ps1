$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if(Get-Module Boxstarter.chocolatey){Remove-Module boxstarter.chocolatey}

Resolve-Path $here\..\..\boxstarter.common\*.ps1 | ForEach-Object { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.bootstrapper\*.ps1 | ForEach-Object { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.chocolatey\*.ps1 | ForEach-Object { . $_.ProviderPath }
$Boxstarter.SuppressLogging=$true

# The real cmdlets only bind a real PSSession; these untyped stubs let the tests use a fake session.
# Invoke-Command is only reached for the session PID lookup because everything else that uses it is mocked.
function Invoke-Command { return 1234 }
function Remove-PSSession {}

function New-FakeSession {
    New-Object PSObject -Property @{ Availability = "Available"; State = "Closed"; ComputerName = "target"; Name = "Boxstarter" }
}

Describe "Invoke-Remotely" {
    $global:ir_bootTime = [DateTime]::UtcNow.AddDays(-1)

    Mock New-PSSession { New-FakeSession }
    Mock Start-Sleep

    Context "When the remote computer is still waiting to restart after the install requested a reboot" {
        $global:ir_installCalls = 0
        Mock Invoke-RemoteBoxstarter {
            $global:ir_installCalls++
            if ($global:ir_installCalls -eq 1) { @{ Result = "Rebooting" } } else { @{ Result = "Completed" } }
        }
        # boot time is read before the install, then twice unchanged (restart delayed), then moved (restarted)
        $global:ir_bootTimeCalls = 0
        Mock Get-RemoteBootTime {
            $global:ir_bootTimeCalls++
            if ($global:ir_bootTimeCalls -le 3) { $global:ir_bootTime } else { [DateTime]::UtcNow }
        }
        Mock Test-Reconnection { return $true }

        $session = New-FakeSession
        Invoke-Remotely ([ref]$session) "pkg" $false @{ ComputerName = "target" } 3600

        It "will not test the reconnection until the boot time changed" {
            Assert-MockCalled Test-Reconnection -Times 1 -Exactly
        }
        It "will keep creating sessions while the computer has not restarted" {
            Assert-MockCalled New-PSSession -Times 3 -Exactly
        }
        It "will resume the install after the restart" {
            $global:ir_installCalls | Should Be 2
        }
    }

    Context "When the remote computer never restarts within the reboot timeout" {
        Mock Invoke-RemoteBoxstarter { @{ Result = "Rebooting" } }
        Mock Get-RemoteBootTime { $global:ir_bootTime }
        Mock Test-Reconnection { return $true }
        # let real time pass so the deadline is reached
        Mock Start-Sleep { [System.Threading.Thread]::Sleep(500) }

        $session = New-FakeSession
        $thrown = $null
        try {
            Invoke-Remotely ([ref]$session) "pkg" $false @{ ComputerName = "target" } 1
        }
        catch {
            $thrown = $_
        }

        It "will throw a timeout error" {
            $thrown.Exception.Message | Should Match "Timed out after 1 seconds waiting for target"
        }
        It "will never consider the computer reconnected" {
            Assert-MockCalled Test-Reconnection -Times 0 -Exactly
        }
    }

    Context "When the remote session drops without a reboot being requested" {
        $global:ir_installCalls = 0
        Mock Invoke-RemoteBoxstarter {
            $global:ir_installCalls++
            if ($global:ir_installCalls -eq 1) { $null } else { @{ Result = "Completed" } }
        }
        Mock Get-RemoteBootTime { $global:ir_bootTime }
        Mock Test-Reconnection { return $true }

        $session = New-FakeSession
        Invoke-Remotely ([ref]$session) "pkg" $false @{ ComputerName = "target" } 3600

        It "will reconnect without requiring a restart" {
            Assert-MockCalled Test-Reconnection -Times 1 -Exactly
        }
        It "will resume the install" {
            $global:ir_installCalls | Should Be 2
        }
    }

    Context "When the boot time of the remote computer cannot be read" {
        $global:ir_installCalls = 0
        Mock Invoke-RemoteBoxstarter {
            $global:ir_installCalls++
            if ($global:ir_installCalls -eq 1) { @{ Result = "Rebooting" } } else { @{ Result = "Completed" } }
        }
        Mock Get-RemoteBootTime { $null }
        Mock Test-Reconnection { return $true }

        $session = New-FakeSession
        Invoke-Remotely ([ref]$session) "pkg" $false @{ ComputerName = "target" } 3600

        It "will fall back to the pending reboot checks" {
            Assert-MockCalled Test-Reconnection -Times 1 -Exactly
        }
    }

    Remove-Variable ir_bootTime, ir_installCalls, ir_bootTimeCalls -Scope Global -ErrorAction SilentlyContinue
}
