
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][string]$Region,
    [Parameter(Mandatory=$true)][string]$LogGroup,
    [Parameter(Mandatory=$true)][string]$UserDataLogStream,
    [Parameter(Mandatory=$true)][string]$CPMConfigurationLogStream,
    [Parameter(Mandatory=$true)][string]$CPMSetLocalServiceLogStream,
    [Parameter(Mandatory=$true)][string]$CPMRegistrationLogStream
)

try {
    $configPath = "C:\Program Files\Amazon\SSM\Plugins\awsCloudWatch\AWS.EC2.Windows.CloudWatch.json"
    $cwLogPath = "C:\ProgramData\Amazon\SSM\Logs\amazon-ssm-cloudwatch.log"
    $configContent = Get-Content -Path $configPath -Raw

    $updatedContent = $configContent `
        -replace 'false','true' `
        -replace 'AWS_REGION_PH',$Region `
        -replace 'LOG_GROUP_PH',$LogGroup `
        -replace 'USERDATA_LOG_PH',$UserDataLogStream `
        -Replace 'CPM_CONF_LOG_PH',$CPMConfigurationLogStream `
        -Replace 'CPM_LOCALSERVICE_LOG_PH',$CPMSetLocalServiceLogStream `
        -Replace 'CPMREGISTRATION_LOG_PH',$CPMRegistrationLogStream

    $updatedContent | Out-File -FilePath $configPath -Force -Encoding ASCII
    while($true){
        Get-Content $cwLogPath -Wait | Select-String "CloudWatch execution started." | % {break}
    }
    Write-Output "CloudWatch Configuration file updated successfully."
} catch {
    Write-Error "Error updating CloudWatch configuration: $_"
    exit 1
}