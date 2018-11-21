# Script Name: CPMHardening.ps1
# Description: Initiating hardening proccess of CPM. If success, returns OK

$ErrorActionPreference = "SilentlyContinue"

New-Item "C:\Program Files (x86)\CyberArk\Password Manager\Vault\user.ini" -ItemType file
Set-Location "C:\CyberArk\Ansible\CPM\Central Policy Manager\InstallationAutomation"
$Action = .\CPM_Hardening.ps1
$Action | Out-File -FilePath "C:\CyberArk\Ansible\cpm_hardening_result.txt"
$Result = Get-Content "C:\CyberArk\Ansible\cpm_hardening_result.txt" | ConvertFrom-Json
if ($Result.isSucceeded -eq 2) {
    exit 1
} else {
    exit 0
}