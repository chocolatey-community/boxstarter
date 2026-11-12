function Set-BoxstarterTaskbarOptions {
<#
.SYNOPSIS
Sets options for the Windows Task Bar.

.PARAMETER Lock
Locks the taskbar.

.PARAMETER UnLock
Unlocks the taskbar.

.PARAMETER AutoHide
Autohides the taskbar.

.PARAMETER NoAutoHide
No autohiding on the taskbar.

.PARAMETER Size
Changes the size of the taskbar icons.  Valid inputs are Small and Large.

.PARAMETER Dock
Changes the location in which the taskbar is docked. Valid inputs are Top, Left, Bottom and Right.

.PARAMETER Combine
Changes the taskbar icon combination style. Valid inputs are Always, Full, and Never.

.PARAMETER AlwaysShowIconsOn
Turn on always show all icons in the notification area.

.PARAMETER AlwaysShowIconsOff
Turn off always show all icons in the notification area.

.PARAMETER MultiMonitorOn
Turn on Show taskbar on all displays.

.PARAMETER MultiMonitorOff
Turn off Show taskbar on all displays.

.PARAMETER MultiMonitorMode
Changes the behavior of the taskbar when using multiple displays. Valid inputs are All, MainAndOpen, and Open.
Only applied when MultiMonitorOn is also set.

.PARAMETER MultiMonitorCombine
Changes the taskbar icon combination style for non-primary displays. Valid inputs are Always, Full, and Never.
Only applied when MultiMonitorOn is also set.

.PARAMETER EnableSearchBox
Shows the search box on the taskbar.

.PARAMETER DisableSearchBox
Hides the search box on the taskbar.

.PARAMETER NewsIcons
Changes how the 'News and Interests' icons are displayed. Valid inputs are IconsText, Icons, and Never.

.EXAMPLE
Set-BoxstarterTaskbarOptions -Lock -AutoHide -AlwaysShowIconsOff -MultiMonitorOff

Locks the taskbar, enabled auto-hiding of the taskbar, turns off showing icons
in the notification area and turns off showing the taskbar on multiple monitors.
.EXAMPLE
Set-BoxstarterTaskbarOptions -Unlock -AlwaysShowIconsOn -Size Large -MultiMonitorOn -MultiMonitorCombine Always

Unlocks the taskbar and always shows large notification icons. Sets
multi-monitor support and always combine icons on non-primary monitors.
#>
    [CmdletBinding(PositionalBinding=$false)]
    param(
        [switch]
        $Lock,

        [switch]
        $UnLock,

        [switch]
        $AutoHide,

        [switch]
        $NoAutoHide,

        [switch]
        $AlwaysShowIconsOn,

        [switch]
        $AlwaysShowIconsOff,

        [ValidateSet('Small','Large')]
        [String]
        $Size,

        [ValidateSet('Top','Left','Bottom','Right')]
        [String]
        $Dock,

        [ValidateSet('Always','Full','Never')]
        [String]
        $Combine,

        [switch]
        $MultiMonitorOff,

        [switch]
        $MultiMonitorOn,

        [ValidateSet('All', 'MainAndOpen', 'Open')]
        [String]
        $MultiMonitorMode,

        [ValidateSet('Always','Full','Never')]
        [String]
        $MultiMonitorCombine,

        [switch]
        $DisableSearchBox,

        [switch]
        $EnableSearchBox,

        [ValidateSet('IconsText', 'Icons', 'Never')]
        [String]
        $NewsIcons
    )

    $mutuallyExclusive = @(
        @('Lock', 'UnLock'),
        @('AutoHide', 'NoAutoHide'),
        @('AlwaysShowIconsOn', 'AlwaysShowIconsOff'),
        @('MultiMonitorOn', 'MultiMonitorOff'),
        @('EnableSearchBox', 'DisableSearchBox')
    )
    foreach ($pair in $mutuallyExclusive) {
        if ($PSBoundParameters[$pair[0]] -and $PSBoundParameters[$pair[1]]) {
            throw New-Object -TypeName ArgumentException "You may not set both $($pair[0]) and $($pair[1]). You can only set one."
        }
    }

    $baseKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion'
    $explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $settingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2'

    if (-not (Test-Path -Path $settingKey)) {
        $settingKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    }

    if (Test-Path -Path $key) {
        if ($Lock) {
            Set-ItemProperty -Path $key -Name TaskbarSizeMove -Value 0
        }

        if ($UnLock) {
            Set-ItemProperty -Path $key -Name TaskbarSizeMove -Value 1
        }

        switch ($Size) {
            "Small" {
                Set-ItemProperty -Path $key -Name TaskbarSmallIcons -Value 1
            }

            "Large" {
                Set-ItemProperty -Path $key -Name TaskbarSmallIcons -Value 0
            }
        }

        switch ($Combine) {
            "Always" {
                Set-ItemProperty -Path $key -Name TaskbarGlomLevel -Value 0
            }

            "Full" {
                Set-ItemProperty -Path $key -Name TaskbarGlomLevel -Value 1
            }

            "Never" {
                Set-ItemProperty -Path $key -Name TaskbarGlomLevel -Value 2
            }
        }

        if ($MultiMonitorOn) {
            Set-ItemProperty -Path $key -Name MMTaskbarEnabled -Value 1

            switch ($MultiMonitorMode) {
                "All" {
                    Set-ItemProperty -Path $key -Name MMTaskbarMode -Value 0
                }

                "MainAndOpen" {
                    Set-ItemProperty -Path $key -Name MMTaskbarMode -Value 1
                }

                "Open" {
                    Set-ItemProperty -Path $key -Name MMTaskbarMode -Value 2
                }
            }

            switch ($MultiMonitorCombine) {
                "Always" {
                    Set-ItemProperty -Path $key -Name MMTaskbarGlomLevel -Value 0
                }

                "Full" {
                    Set-ItemProperty -Path $key -Name MMTaskbarGlomLevel -Value 1
                }

                "Never" {
                    Set-ItemProperty -Path $key -Name MMTaskbarGlomLevel -Value 2
                }
            }
        }

        if ($MultiMonitorOff) {
            Set-ItemProperty -Path $key -Name MMTaskbarEnabled -Value 0
        }
    }

    if (Test-Path -Path $settingKey) {
        $settings = (Get-ItemProperty -Path $settingKey -Name Settings).Settings

        switch ($Dock) {
            "Top" {
                $settings[12] = 0x01
            }

            "Left" {
                $settings[12] = 0x00
            }

            "Bottom" {
                $settings[12] = 0x03
            }

            "Right" {
                $settings[12] = 0x02
            }
        }

        if ($AutoHide) {
            $settings[8] = $settings[8] -bor 1
        }

        if ($NoAutoHide) {
            $settings[8] = $settings[8] -band 0xFE
        }

        Set-ItemProperty -Path $settingKey -Name Settings -Value $settings
    }

    if (Test-Path -Path $explorerKey) {
        if ($AlwaysShowIconsOn) {
            Set-ItemProperty -Path $explorerKey -Name 'EnableAutoTray' -Value 0
        }

        if ($alwaysShowIconsOff) {
            Set-ItemProperty -Path $explorerKey -Name 'EnableAutoTray' -Value 1
        }
    }

    if ($EnableSearchBox.IsPresent) {
        # this will create the path if it doesn't exist
        Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Search') -Name 'SearchBoxTaskbarMode' -Value 2 -Type DWord -Force
    }
    elseif ($DisableSearchBox.IsPresent) {
        # this will create the path if it does not exist
        Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Search') -Name 'SearchBoxTaskbarMode' -Value 0 -Type DWord -Force
    }

    switch ($NewsIcons) {
        "IconsText" {
            Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Feeds') -Name ShellFeedsTaskbarViewMode -Value 0
            Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Feeds') -Name ShellFeedsTaskbarPreviousViewMode -Value 2
        }

        "Icons" {
            Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Feeds') -Name ShellFeedsTaskbarViewMode -Value 1
            Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Feeds') -Name ShellFeedsTaskbarPreviousViewMode -Value 0
        }

        "Never" {
            Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Feeds') -Name ShellFeedsTaskbarViewMode -Value 2
            Set-ItemProperty -Path (Join-Path -Path $baseKey -ChildPath 'Feeds') -Name ShellFeedsTaskbarPreviousViewMode -Value 0
        }
    }

    Restart-Explorer
}

New-Alias -Name Set-TaskbarOptions -Value Set-BoxstarterTaskbarOptions