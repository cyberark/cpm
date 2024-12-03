[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$Service,
  [Parameter(Mandatory=$true)][string]$Password
)
$filter = 'Name=' + "'" + $Service + "'" + ''
$s = Get-WMIObject -class Win32_Service -Filter $filter
$s.Change($Null,$Null,$Null,$Null,$Null,$Null,$Null,$Password,$Null,$Null,$Null)