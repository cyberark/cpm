[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$VaultAdminUser,
  [Parameter(Mandatory=$true)][string]$SSMAdminPassParameterID
)

. "$PSScriptRoot\Common.ps1"

$LogFile = "C:\CyberArk\Deployment\Logs\CPMRegistration.log"

try{
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Getting Admin password from ssm"
  $AdminPassword = (Get-SSMParameterValue -Name "$SSMAdminPassParameterID" -WithDecryption $true).Parameters.Value
  $ScriptPath = $PSScriptRoot
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Setting path location for registration"
  Set-Location "C:\Cyberark\CPM\InstallationAutomation\Registration"
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Convert Admin password to secure string for registration PS"
  $secStrObj = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
  $Action = .\CPMRegisterCommponent.ps1 -spwdObj $secStrObj
  $Action | Out-File -FilePath "cpm_registration_log.log"
  $Result = Get-Content "cpm_registration_log.log" -Raw | ConvertFrom-Json
  if ($Result.isSucceeded -eq 0) {
      exit 0
  } else {
      exit 1
  }
}
catch{
  WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log $_.Exception.Message
  exit 1
}