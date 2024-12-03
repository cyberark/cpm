[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]  [string]$Region,
    [Parameter(Mandatory = $true)]  [string]$LogGroup,
    [Parameter(Mandatory = $true)]  [string]$UserDataLogStream,
    [Parameter(Mandatory = $true)]  [string]$CPMConfigurationLogStream,
    [Parameter(Mandatory = $true)]  [string]$CPMRegistrationLogStream,
    [Parameter(Mandatory = $true)]  [string]$CPMSetLocalServiceLogStream,
    [Parameter(Mandatory = $true)]  [string]$VaultAdminUser,
    [Parameter(Mandatory = $false)] [string]$SSMAdminPassParameterID,
    [Parameter(Mandatory = $false)] [string]$VaultPrivateIP,
    [Parameter(Mandatory = $true)]  [string]$ComponentHostname,
    [Parameter(Mandatory = $false)] [string]$StackName
)

# Configure logging
. "$PSScriptRoot\Common.ps1"
$LogFile = "C:\CyberArk\Deployment\Logs\UserData.log"

# Ensure AmazonSSMAgent is enabled and running
try {
    Set-Service AmazonSSMAgent -StartupType Automatic
    Start-Service AmazonSSMAgent
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "AmazonSSMAgent state verified successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to start AmazonSSMAgent: $_"
    exit 1
}

# Execute configCW commands
try {
    & $PSScriptRoot\CloudWatch.ps1 -LogGroup $LogGroup `
        -UserDataLogStream $UserDataLogStream `
        -CPMConfigurationLogStream $CPMConfigurationLogStream `
        -CPMRegistrationLogStream $CPMRegistrationLogStream `
        -CPMSetLocalServiceLogStream $CPMSetLocalServiceLogStream `
        -Region $Region
    ChildScriptErrorHandler -ScriptName "CloudWatch"
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "CloudWatch configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to configure CloudWatch: $_"
    exit 1
}

# Execute CPMConfiguration commands
try {
    & $PSScriptRoot\CPMConfiguration.ps1 -VaultIpAddress $VaultPrivateIP `
                                        -VaultAdminUser $VaultAdminUser `
                                        -VaultPort 1858
    ChildScriptErrorHandler -ScriptName "CPMConfiguration"
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "CPMConfiguration configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to execute CPMConfiguration configuration: $_"
    exit 1
}

# Execute CPMRegistration commands
try {
    & $PSScriptRoot\CPMRegistration.ps1 -VaultAdminUser $VaultAdminUser -SSMAdminPassParameterID $SSMAdminPassParameterID
    ChildScriptErrorHandler -ScriptName "CPMRegistration"
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "CPMRegistration configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to execute CPMRegistration configuration: $_"
    exit 1
}

# Execute LocalServiceConfig commands for CPM Scanner
try {
    & $PSScriptRoot\Set-LocalService.ps1 -Username "PasswordManagerUser" -Services "CyberArk Central Policy Manager Scanner"
    ChildScriptErrorHandler -ScriptName "Set-LocalService"
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "LocalService (CPM Scanner) configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to execute LocalService (CPM Scanner) configuration: $_"
    exit 1
}

# Execute LocalServiceConfig commands for Password Manager
try {
    & $PSScriptRoot\Set-LocalService.ps1 -Username "PasswordManagerUser" -Services "CyberArk Password Manager"
    ChildScriptErrorHandler -ScriptName "Set-LocalService"
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "LocalService (Password Manager) configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to execute LocalService (Password Manager) configuration: $_"
    exit 1
}

# Execute LocalServiceAutoStart commands
try {
    & sc.exe config "CyberArk Password Manager" start=auto
    & sc.exe config "CyberArk Central Policy Manager Scanner" start=auto
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "LocalServiceAutoStart configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to execute LocalServiceAutoStart configuration: $_"
    exit 1
}

# Execute configHostname commands
try {
    Rename-Computer -NewName $ComponentHostname -Force
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Hostname configuration completed successfully"
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to configure hostname: $_"
    exit 1
}

# Configure a completion signal scheduled task
$ResourceName = "CPMMachine"
$scriptBlock = @"
    # Configure logging
    . "$PSScriptRoot\Common.ps1"
    # Signal completion to CloudFormation
    if ("$StackName" -ne "") {
        `$cfn_signal_output = cfn-signal.exe --stack $StackName --success true --resource $ResourceName --region $Region 2>&1
        if (`$LastExitCode -ne 0) {
            WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to signal CloudFormation: `$cfn_signal_output"
            Unregister-ScheduledTask -TaskName "SignalSuccess" -Confirm:`$false
            exit 1
        }
        WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Signaled CloudFormation completion successfully"
    }
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "$ResourceName deployment process completed successfully"
    Unregister-ScheduledTask -TaskName "SignalSuccess" -Confirm:`$false
"@
# Convert script block to a Base64 encoded string to pass it to the scheduled task
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptBlock))
# Creating the scheduled task
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-EncodedCommand $encodedCommand"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -User "NT AUTHORITY\SYSTEM" `
    -RunLevel "Highest" `
    -TaskName "SignalSuccess" `
    -Description "Signal completion after reboot"

# Reboot to apply hostname change
try {
    WriteLog -LogFile $LogFile -LogLevel "INFO" -Log "Host will now be restarted to apply hostname change"
    Restart-Computer -Force
} catch {
    WriteLog -LogFile $LogFile -LogLevel "ERROR" -Log "Failed to restart computer: $_"
    exit 1
}