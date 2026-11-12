param(
    [parameter(Position = 0, Mandatory = $false)][boolean]$ExportCommands = $false
)
if (!$Global:Boxstarter) { $Global:Boxstarter = @{} }
if (!$Boxstarter.ContainsKey('RebootOk')) { $Boxstarter.RebootOk = $true }

$unNormalized = (Get-Item "$PSScriptRoot\..\Boxstarter.Bootstrapper\Boxstarter.Bootstrapper.psd1")
Import-Module $unNormalized.FullName -Global -DisableNameChecking


# Resolve-Path $PSScriptRoot\*.ps1 | % { . $_.ProviderPath }
# we're not doing dot-sourcing anymore - "INCLUDE" all required files into this module during build

# --- INCLUDE *.ps1

if ($ExportCommands) {
    Import-BoxstarterVars
    # Define the wrappers as global functions (still bound to this module) instead of calling
    # Export-ModuleMember, which would replace the manifest's export list and export nothing.
    foreach ($name in 'cinst', 'cup', 'choco') {
        Set-Item -Path "function:global:$name" -Value (Get-Item "function:$name").ScriptBlock
    }
}

