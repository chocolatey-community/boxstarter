$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Module boxstarter.*

Resolve-Path $here\..\..\boxstarter.WinConfig\*.ps1 | ForEach-Object { . $_.ProviderPath }
Resolve-Path $here\..\..\boxstarter.common\*.ps1 | ForEach-Object { . $_.ProviderPath }
$Boxstarter.SuppressLogging = $true

Describe "Set-BoxstarterTaskbarOptions" {

    Context "When combining options from different groups" {

        $testCases = @(
            @{ Name = '-Lock'; Params = @{ Lock = $true } }
            @{ Name = '-AutoHide'; Params = @{ AutoHide = $true } }
            @{ Name = '-AlwaysShowIconsOn -MultiMonitorOff'; Params = @{ AlwaysShowIconsOn = $true; MultiMonitorOff = $true } }
            @{ Name = '-Combine Never -AlwaysShowIconsOn -MultiMonitorOn -MultiMonitorMode All -MultiMonitorCombine Never'; Params = @{ Combine = 'Never'; AlwaysShowIconsOn = $true; MultiMonitorOn = $true; MultiMonitorMode = 'All'; MultiMonitorCombine = 'Never' } }
            @{ Name = '-Lock -AutoHide -AlwaysShowIconsOff -MultiMonitorOff'; Params = @{ Lock = $true; AutoHide = $true; AlwaysShowIconsOff = $true; MultiMonitorOff = $true } }
            @{ Name = '-UnLock -AlwaysShowIconsOn -Size Large -MultiMonitorOn -MultiMonitorCombine Always'; Params = @{ UnLock = $true; AlwaysShowIconsOn = $true; Size = 'Large'; MultiMonitorOn = $true; MultiMonitorCombine = 'Always' } }
            @{ Name = '-EnableSearchBox -Lock -AutoHide'; Params = @{ EnableSearchBox = $true; Lock = $true; AutoHide = $true } }
            @{ Name = '-Lock -UnLock:$false'; Params = @{ Lock = $true; UnLock = $false } }
        )

        It 'should accept <Name>' -TestCases $testCases {
            param ($Name, $Params)

            Mock Test-Path { $false }
            Mock Set-ItemProperty
            Mock Restart-Explorer

            { Set-BoxstarterTaskbarOptions @Params } | Should Not Throw
        }
    }

    Context "When setting options from several groups at once" {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        $explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'

        Mock Test-Path { $false }
        Mock Test-Path { $true } -ParameterFilter { $Path -eq $key -or $Path -eq $explorerKey }
        Mock Set-ItemProperty
        Mock Restart-Explorer

        Set-BoxstarterTaskbarOptions -Combine Never -AlwaysShowIconsOn -MultiMonitorOn -MultiMonitorMode All -MultiMonitorCombine Never

        It "should apply every requested option" {
            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Path -eq $key -and $Name -eq 'TaskbarGlomLevel' -and $Value -eq 2 } -Exactly 1
            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Path -eq $key -and $Name -eq 'MMTaskbarEnabled' -and $Value -eq 1 } -Exactly 1
            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Path -eq $key -and $Name -eq 'MMTaskbarMode' -and $Value -eq 0 } -Exactly 1
            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Path -eq $key -and $Name -eq 'MMTaskbarGlomLevel' -and $Value -eq 2 } -Exactly 1
            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Path -eq $explorerKey -and $Name -eq 'EnableAutoTray' -and $Value -eq 0 } -Exactly 1
        }
    }

    Context "When setting both options of a pair" {

        $testCases = @(
            @{ First = 'Lock'; Second = 'UnLock' }
            @{ First = 'AutoHide'; Second = 'NoAutoHide' }
            @{ First = 'AlwaysShowIconsOn'; Second = 'AlwaysShowIconsOff' }
            @{ First = 'MultiMonitorOn'; Second = 'MultiMonitorOff' }
            @{ First = 'EnableSearchBox'; Second = 'DisableSearchBox' }
        )

        It 'should throw for <First> and <Second> without changing anything' -TestCases $testCases {
            param ($First, $Second)

            Mock Test-Path { $true }
            Mock Set-ItemProperty
            Mock Restart-Explorer

            $params = @{ $First = $true; $Second = $true }
            $err = $null
            try { Set-BoxstarterTaskbarOptions @params } catch { $err = $_ }

            $err.Exception | Should BeOfType [ArgumentException]
            $err.Exception.Message | Should Match "$First.*$Second"
            Assert-MockCalled Set-ItemProperty -Exactly 0 -Scope It
            Assert-MockCalled Restart-Explorer -Exactly 0 -Scope It
        }
    }

    Context "When changing auto-hide" {
        $settingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

        # byte 8 holds the AppBar state flags: 0x01 = ABS_AUTOHIDE, 0x02 = ABS_ALWAYSONTOP
        $testCases = @(
            @{ Switch = 'AutoHide'; Start = 0x02; Expected = 0x03 }
            @{ Switch = 'AutoHide'; Start = 0x03; Expected = 0x03 }
            @{ Switch = 'NoAutoHide'; Start = 0x03; Expected = 0x02 }
            @{ Switch = 'NoAutoHide'; Start = 0x02; Expected = 0x02 }
        )

        It 'should turn byte 8 from <Start> into <Expected> for -<Switch>' -TestCases $testCases {
            param ($Switch, $Start, $Expected)

            $script:startSettings = New-Object byte[] 48
            $script:startSettings[8] = $Start
            $script:writtenSettings = @()

            Mock Test-Path { $false }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $settingKey }
            Mock Get-ItemProperty { [pscustomobject]@{ Settings = $script:startSettings } }
            Mock Set-ItemProperty { $script:writtenSettings += , $Value } -ParameterFilter { $Path -eq $settingKey }
            Mock Restart-Explorer

            $params = @{ $Switch = $true }
            Set-BoxstarterTaskbarOptions @params

            $script:writtenSettings.Count | Should Be 1
            $script:writtenSettings[0][8] | Should Be $Expected
        }
    }

    Context "When docking the taskbar" {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        $settingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

        # both use the ABE_* edge values: 0 = left, 1 = top, 2 = right, 3 = bottom
        $testCases = @(
            @{ Dock = 'Left'; Edge = 0 }
            @{ Dock = 'Top'; Edge = 1 }
            @{ Dock = 'Right'; Edge = 2 }
            @{ Dock = 'Bottom'; Edge = 3 }
        )

        It 'should set TaskbarLocation and the StuckRects3 position to <Edge> for -Dock <Dock>' -TestCases $testCases {
            param ($Dock, $Edge)

            $script:startSettings = New-Object byte[] 48
            $script:startSettings[12] = 0x03
            $script:writtenSettings = @()

            Mock Test-Path { $false }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $key -or $Path -eq $settingKey }
            Mock Get-ItemProperty { [pscustomobject]@{ Settings = $script:startSettings } }
            Mock Set-ItemProperty
            Mock Set-ItemProperty { $script:writtenSettings += , $Value } -ParameterFilter { $Path -eq $settingKey }
            Mock Restart-Explorer

            Set-BoxstarterTaskbarOptions -Dock $Dock

            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Path -eq $key -and $Name -eq 'TaskbarLocation' -and $Value -eq $Edge -and $Type -eq 'DWord' } -Exactly 1 -Scope It
            $script:writtenSettings.Count | Should Be 1
            $script:writtenSettings[0][12] | Should Be $Edge
        }

        It 'should not set TaskbarLocation without -Dock' {
            Mock Test-Path { $true }
            Mock Get-ItemProperty { [pscustomobject]@{ Settings = (New-Object byte[] 48) } }
            Mock Set-ItemProperty
            Mock Restart-Explorer

            Set-BoxstarterTaskbarOptions -Lock

            Assert-MockCalled Set-ItemProperty -ParameterFilter { $Name -eq 'TaskbarLocation' } -Exactly 0 -Scope It
        }
    }

    Context "When passing values without parameter names" {

        It "should not accept them" {
            { Set-BoxstarterTaskbarOptions Small } | Should Throw
        }
    }
}
