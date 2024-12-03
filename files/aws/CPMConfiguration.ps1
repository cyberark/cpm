[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$VaultIpAddress,
  [Parameter(Mandatory=$true)][string]$VaultAdminUser,
  [Parameter(Mandatory=$true)][string]$VaultPort
)

. "$PSScriptRoot\Common.ps1"

$LogFile = "C:\CyberArk\Deployment\Logs\CPMConfigurations.log"

try{
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Get content of CPMRegisterComponentConfig.xml"
  $ScriptPath = $PSScriptRoot
  $FilePath = "C:\CyberArk\CPM\InstallationAutomation\Registration\CPMRegisterComponentConfig.xml"
  $xml = [xml](Get-Content $filePath)

  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Get vault IP"
  $step1 = $xml.SelectSingleNode("//Parameter[@Name = 'vaultip']")
  $step1.Value = $VaultIpAddress
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Get vault port"
  $step2 = $xml.SelectSingleNode("//Parameter[@Name = 'vaultPort']")
  $step2.Value = $VaultPort
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Get vault user"
  $step3 = $xml.SelectSingleNode("//Parameter[@Name = 'vaultUser']")
  $step3.Value = $VaultAdminUser
  
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Save xml"
  $xml.Save($filePath)
  WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Step completed successfully"
}
catch{
  WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log $_.Exception.Message
  exit 1
}