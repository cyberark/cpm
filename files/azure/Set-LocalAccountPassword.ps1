[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$Username,
  [Parameter(Mandatory=$true)][string]$Password
)
$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$existing = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $Username }
if ($existing -eq $null) {
    Write-Error "User $Username does not exist"
    return
}
$existing.SetPassword($Password)