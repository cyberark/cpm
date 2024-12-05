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

# Ensure userdata is running first time
if (Test-Path -Path $LogFile) {
    Write-Output "Userdata already ran, exiting."
    exit 0
}

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
# SIG # Begin signature block
# MIIpJQYJKoZIhvcNAQcCoIIpFjCCKRICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA4WKlbD+Lk3CJd
# tOBDv17JfYIxyEDZXkeRwuvNY6YEOqCCDpUwggboMIIE0KADAgECAhB3vQ4Ft1kL
# th1HYVMeP3XtMA0GCSqGSIb3DQEBCwUAMFMxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSkwJwYDVQQDEyBHbG9iYWxTaWduIENvZGUgU2ln
# bmluZyBSb290IFI0NTAeFw0yMDA3MjgwMDAwMDBaFw0zMDA3MjgwMDAwMDBaMFwx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTIwMAYDVQQD
# EylHbG9iYWxTaWduIEdDQyBSNDUgRVYgQ29kZVNpZ25pbmcgQ0EgMjAyMDCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMsg75ceuQEyQ6BbqYoj/SBerjgS
# i8os1P9B2BpV1BlTt/2jF+d6OVzA984Ro/ml7QH6tbqT76+T3PjisxlMg7BKRFAE
# eIQQaqTWlpCOgfh8qy+1o1cz0lh7lA5tD6WRJiqzg09ysYp7ZJLQ8LRVX5YLEeWa
# tSyyEc8lG31RK5gfSaNf+BOeNbgDAtqkEy+FSu/EL3AOwdTMMxLsvUCV0xHK5s2z
# BZzIU+tS13hMUQGSgt4T8weOdLqEgJ/SpBUO6K/r94n233Hw0b6nskEzIHXMsdXt
# HQcZxOsmd/KrbReTSam35sOQnMa47MzJe5pexcUkk2NvfhCLYc+YVaMkoog28vmf
# vpMusgafJsAMAVYS4bKKnw4e3JiLLs/a4ok0ph8moKiueG3soYgVPMLq7rfYrWGl
# r3A2onmO3A1zwPHkLKuU7FgGOTZI1jta6CLOdA6vLPEV2tG0leis1Ult5a/dm2tj
# IF2OfjuyQ9hiOpTlzbSYszcZJBJyc6sEsAnchebUIgTvQCodLm3HadNutwFsDeCX
# pxbmJouI9wNEhl9iZ0y1pzeoVdwDNoxuz202JvEOj7A9ccDhMqeC5LYyAjIwfLWT
# yCH9PIjmaWP47nXJi8Kr77o6/elev7YR8b7wPcoyPm593g9+m5XEEofnGrhO7izB
# 36Fl6CSDySrC/blTAgMBAAGjggGtMIIBqTAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUJZ3Q
# /FkJhmPF7POxEztXHAOSNhEwHwYDVR0jBBgwFoAUHwC/RoAK/Hg5t6W0Q9lWULvO
# ljswgZMGCCsGAQUFBwEBBIGGMIGDMDkGCCsGAQUFBzABhi1odHRwOi8vb2NzcC5n
# bG9iYWxzaWduLmNvbS9jb2Rlc2lnbmluZ3Jvb3RyNDUwRgYIKwYBBQUHMAKGOmh0
# dHA6Ly9zZWN1cmUuZ2xvYmFsc2lnbi5jb20vY2FjZXJ0L2NvZGVzaWduaW5ncm9v
# dHI0NS5jcnQwQQYDVR0fBDowODA2oDSgMoYwaHR0cDovL2NybC5nbG9iYWxzaWdu
# LmNvbS9jb2Rlc2lnbmluZ3Jvb3RyNDUuY3JsMFUGA1UdIAROMEwwQQYJKwYBBAGg
# MgECMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3Jl
# cG9zaXRvcnkvMAcGBWeBDAEDMA0GCSqGSIb3DQEBCwUAA4ICAQAldaAJyTm6t6E5
# iS8Yn6vW6x1L6JR8DQdomxyd73G2F2prAk+zP4ZFh8xlm0zjWAYCImbVYQLFY4/U
# ovG2XiULd5bpzXFAM4gp7O7zom28TbU+BkvJczPKCBQtPUzosLp1pnQtpFg6bBNJ
# +KUVChSWhbFqaDQlQq+WVvQQ+iR98StywRbha+vmqZjHPlr00Bid/XSXhndGKj0j
# fShziq7vKxuav2xTpxSePIdxwF6OyPvTKpIz6ldNXgdeysEYrIEtGiH6bs+XYXvf
# cXo6ymP31TBENzL+u0OF3Lr8psozGSt3bdvLBfB+X3Uuora/Nao2Y8nOZNm9/Lws
# 80lWAMgSK8YnuzevV+/Ezx4pxPTiLc4qYc9X7fUKQOL1GNYe6ZAvytOHX5OKSBoR
# HeU3hZ8uZmKaXoFOlaxVV0PcU4slfjxhD4oLuvU/pteO9wRWXiG7n9dqcYC/lt5y
# A9jYIivzJxZPOOhRQAyuku++PX33gMZMNleElaeEFUgwDlInCI2Oor0ixxnJpsoO
# qHo222q6YV8RJJWk4o5o7hmpSZle0LQ0vdb5QMcQlzFSOTUpEYck08T7qWPLd0jV
# +mL8JOAEek7Q5G7ezp44UCb0IXFl1wkl1MkHAHq4x/N36MXU4lXQ0x72f1LiSY25
# EXIMiEQmM2YBRN/kMw4h3mKJSAfa9TCCB6UwggWNoAMCAQICDAJZP4AHVQPEmDE5
# fjANBgkqhkiG9w0BAQsFADBcMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFs
# U2lnbiBudi1zYTEyMDAGA1UEAxMpR2xvYmFsU2lnbiBHQ0MgUjQ1IEVWIENvZGVT
# aWduaW5nIENBIDIwMjAwHhcNMjQwMzA0MTM1NzE4WhcNMjYwMzA1MTM1NzE4WjCB
# 6zEdMBsGA1UEDwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xEjAQBgNVBAUTCTUxMjI5
# MTY0MjETMBEGCysGAQQBgjc8AgEDEwJJTDELMAkGA1UEBhMCSUwxGTAXBgNVBAgT
# EENlbnRyYWwgRGlzdHJpY3QxFDASBgNVBAcTC1BldGFoIFRpa3ZhMR8wHQYDVQQK
# ExZDeWJlckFyayBTb2Z0d2FyZSBMdGQuMR8wHQYDVQQDExZDeWJlckFyayBTb2Z0
# d2FyZSBMdGQuMSEwHwYJKoZIhvcNAQkBFhJhZG1pbkBjeWJlcmFyay5jb20wggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCW/EphpbQKOtU69jouawb8wLcd
# 1OFl4mjU/IwWs/F50xD/XtpkocmEjb5eQmzWDLjFjyaQc4+9lKZVmh5BJiH5O/4K
# Zh07tYcD/zWw1+ASFu9M/46znESl0Wu9T743zWm/8MNI21Z7GiXocpk3ca81IOsp
# PNVU/qyMMgU67gK2l48ywRVLposh2oQcU2oGofzk3GvfQ1Ej4/HfUaT0U45V+uMj
# +XyNo6QZcfCYQiv9TLqwhVzD/PDvo2IMDk153Vt7y4/PKi4eimip0a/sWoNQV8aD
# +iOF6qgBKdQ34l7nPWeAic1EnkOiBMPlukrmBxOo6qX3OOpoxByG8iQKCt2ZsJE1
# Jfg6r/p+idbbFnRMd4jGxG4byA3cVxBWupE+qcZabqtcWcIjmWIFksvRqFCHZFZj
# 9KLy46c1I5jG6G99jr8jOJYxupmLBvWo4VwAxAm10rAn2473+axyExaKtqR5DP1H
# 8kjmUoEtto2v/l2XK0SpxIfNYEYvbp0uRw5d6SmWEyp4q5kvFxRsL7R3rJcgxtll
# lHiFBfo9M5s/aNqwbKyvf5c3QjLI9xADuDdaYIYc5HDolgnDdyjzpefSDEljmAmB
# BqRYwDe5/dhCDgn8yoZ0gOWbAxyGHj+BA35G6dge2sHsD3WHV4xNXtF4A2v6n8Y6
# dD0qufDn1Q8C/zZzuQIDAQABo4IB1TCCAdEwDgYDVR0PAQH/BAQDAgeAMIGfBggr
# BgEFBQcBAQSBkjCBjzBMBggrBgEFBQcwAoZAaHR0cDovL3NlY3VyZS5nbG9iYWxz
# aWduLmNvbS9jYWNlcnQvZ3NnY2NyNDVldmNvZGVzaWduY2EyMDIwLmNydDA/Bggr
# BgEFBQcwAYYzaHR0cDovL29jc3AuZ2xvYmFsc2lnbi5jb20vZ3NnY2NyNDVldmNv
# ZGVzaWduY2EyMDIwMFUGA1UdIAROMEwwQQYJKwYBBAGgMgECMDQwMgYIKwYBBQUH
# AgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMAcGBWeB
# DAEDMAkGA1UdEwQCMAAwRwYDVR0fBEAwPjA8oDqgOIY2aHR0cDovL2NybC5nbG9i
# YWxzaWduLmNvbS9nc2djY3I0NWV2Y29kZXNpZ25jYTIwMjAuY3JsMB0GA1UdEQQW
# MBSBEmFkbWluQGN5YmVyYXJrLmNvbTATBgNVHSUEDDAKBggrBgEFBQcDAzAfBgNV
# HSMEGDAWgBQlndD8WQmGY8Xs87ETO1ccA5I2ETAdBgNVHQ4EFgQUvfk3K3nY9zOK
# r24uYKcj/KTt+p8wDQYJKoZIhvcNAQELBQADggIBAB7REam0h5j/shCjeh87xdmt
# AvLf+bBp2STB6GVNs6nZixmLw4qjCWkFdeEBM5SG9HEpKQxCrmVAk9waH14pb7O7
# xrNeBcdsNMDZ3b3sjae63LodNC4kS+qPWGlIBG9giV3dbZjnTCW0zVI0WXWX6o5s
# vOs35FeLIAak8t8NsA3fJK0ngsBjOfO+2aJikZU4BaDy8Oj04TTAvLeLe2wtuzt/
# W+dddwIVNys7VFs4dppNCtrzPK0pYYWIq17KHPtQ0yPp5EtxWQqBgEnDjdu1mDss
# 0I93shcUYmst3AqGVliQRJZHnE6Hk665IiN7S6QJ+UVoyxprVGC6+k21pCPiMTTr
# BtwvfEP00JB/CGG3/Q+yIoetCMv1jkg6Cso7KOAGQkfeVAucRgq61AfDjp7f8LwO
# dqLJhQvL6pJ0fLiGSlh6y9Rr0kG0DRHKmsLUYofs67oRLUT9T/RqFwYSTzU4eKxU
# TJurkigpkCbn55bYw+C5T0+gX1QI16K97E51wEnJ9jp6u+YenUy/OgGDGnUWLiMn
# 4M6L60ZOgUx8Bndk5UxPPgdYwn6R6iPaJhYe0TAB2mTD9qPPD4+NBzBMDHC25tvP
# +Si4LmDAxO1H35ifRREyPZ1OD08iWQDsjcHqtS4vntaRa9SNtwNE/4KJtBE1C+vC
# c3epnQA75eTfm9t3CdYEMYIZ5jCCGeICAQEwbDBcMQswCQYDVQQGEwJCRTEZMBcG
# A1UEChMQR2xvYmFsU2lnbiBudi1zYTEyMDAGA1UEAxMpR2xvYmFsU2lnbiBHQ0Mg
# UjQ1IEVWIENvZGVTaWduaW5nIENBIDIwMjACDAJZP4AHVQPEmDE5fjANBglghkgB
# ZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEE
# AYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJ
# BDEiBCDF5I6y/vabZcWnUllrVhwaTZ/VTUKus5xfxSythzbdcDANBgkqhkiG9w0B
# AQEFAASCAgAQK6hszFYGJr5zwkRN+jJiYRgrU9t/QC0LtOqJsvJnXb/yTmtScKs4
# vfC9/f6XpLF3Z91RqlCpJwAnQh3NXtLbjfQZ+YvSFtnPOyo9WZz60faJ0MSabCyK
# h0reJmT2aoJn/0PmrbNZtyI1kpXe1FJaKzxWYrAN85+Q0/N4hv4VjnmdMYYfPu2A
# J6jPngyZNARCSpqUbwrNi1khPFMZF+ic0uQ0d+5pqZp8tJf6g+u3QflJSSPNeEdb
# OdEq2W2yYIazdpg3SOpXBSbTsf12h9tmliwg/nhiKwnnA9/PlNDHGKBt6vbt6ZLY
# YnozV/qg+og3ZhAaAZhC+gc/6uOM1O2+o6lJoeIfTCQpdMaG6jpijV9tOPDzvDao
# Vhxdhe/L0D28L9Cu/xW05M6pzxZKMPPeVlXnNIZc5vEIldfZa+mP1iBh9t2UNKr8
# jdQpTjPBarQLrmfEDal3W5jvhsP8pEHplTLLyESeB7m7oED4z3xAlhYWdJ/cjVS0
# bQvnVbRGLXrDT+1SMaxzXDn8/vIWAvUMg182HBCrggO02iLPjD3GjMVL4Bl+etbR
# jYPNRAUBZa7Cy1BonU+Uw5adedCu74L+SCT6Qsh034Mzv279va3R8Ju/bqun5SNs
# 0F9E5YBqUkBSmPMArUoRAghgk2QqXBemceEs1VYx63Xl5AcIxSbeAaGCFs0wghbJ
# BgorBgEEAYI3AwMBMYIWuTCCFrUGCSqGSIb3DQEHAqCCFqYwghaiAgEDMQ0wCwYJ
# YIZIAWUDBAIBMIHoBgsqhkiG9w0BCRABBKCB2ASB1TCB0gIBAQYLKwYBBAGgMgID
# AQIwMTANBglghkgBZQMEAgEFAAQgndaHAOUkDt//mRo0WCVPsa/2oF9JETDKxUUm
# rT9H3hACFGtwiff76dGbzt4xPzPGpkjb0hT/GA8yMDI0MTIwNTEwMjUzMlowAwIB
# AaBhpF8wXTELMAkGA1UEBhMCQkUxGTAXBgNVBAoMEEdsb2JhbFNpZ24gbnYtc2Ex
# MzAxBgNVBAMMKkdsb2JhbHNpZ24gVFNBIGZvciBDb2RlU2lnbjEgLSBSNiAtIDIw
# MjMxMaCCElQwggZsMIIEVKADAgECAhABm+reyE1rj/dsOp8uASQWMA0GCSqGSIb3
# DQEBCwUAMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNh
# MTEwLwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAt
# IEc0MB4XDTIzMTEwNzE3MTM0MFoXDTM0MTIwOTE3MTM0MFowXTELMAkGA1UEBhMC
# QkUxGTAXBgNVBAoMEEdsb2JhbFNpZ24gbnYtc2ExMzAxBgNVBAMMKkdsb2JhbHNp
# Z24gVFNBIGZvciBDb2RlU2lnbjEgLSBSNiAtIDIwMjMxMTCCAaIwDQYJKoZIhvcN
# AQEBBQADggGPADCCAYoCggGBAOqEN1BoPJWFtUhUcZfzhHLJnYDTCNxZu7/LTZBp
# R4nlLNjxqGp+YDdJc5u4mLMU4O+Mk3AgtfUr12YFdT96hFCpUg/g1udv1Bw1LuAv
# KSSjjnclJ+C4831kdQyaQuXGneLYh3OL76CNl34WoMSyRs9gxs8PgVCA3U/p5Eai
# NKc+GMdrtLb7vtqpVn5/nF02PWM0IUvI0qMTGj4vUWh1+X/8cIQRZTMSs0ZlKISg
# M8CSne24H4lj0B57LFuwBPS9cmPOsDEhAQJqcrIiLO/rKjsQ1fGa9CaiLPxTAQR5
# I2lR012+c4TLm4OIbSDSIM6Bq2oiS3mQQuaCQq8D69TQ2oN6wy1I8c1FkbcRQd0X
# 70D8EqKywFmqVJdObcN63YaG1Ds3RzjoAzwxv0wze0Ps8ND/ZaafmD3SxrpZImwQ
# WBHFBMzoopiwHTPQ85Ud+O1xtAtB1WR5orxgLsN6yd5wNxIWPgKPXTgRsASJZ4ul
# LSDbuNb1nPUPvIi/JyzD+SCiwQIDAQABo4IBqDCCAaQwDgYDVR0PAQH/BAQDAgeA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBT5Tqu+uPhb/8LHA/RB
# 7pz41nR9PzBWBgNVHSAETzBNMAgGBmeBDAEEAjBBBgkrBgEEAaAyAR4wNDAyBggr
# BgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8w
# DAYDVR0TAQH/BAIwADCBkAYIKwYBBQUHAQEEgYMwgYAwOQYIKwYBBQUHMAGGLWh0
# dHA6Ly9vY3NwLmdsb2JhbHNpZ24uY29tL2NhL2dzdHNhY2FzaGEzODRnNDBDBggr
# BgEFBQcwAoY3aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNvbS9jYWNlcnQvZ3N0
# c2FjYXNoYTM4NGc0LmNydDAfBgNVHSMEGDAWgBTqFsZp5+PLV0U5M6TwQL7Qw71l
# ljBBBgNVHR8EOjA4MDagNKAyhjBodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2Nh
# L2dzdHNhY2FzaGEzODRnNC5jcmwwDQYJKoZIhvcNAQELBQADggIBAJX0Z8+TmkOS
# gxd21iBVvIn/5F+y5RUat5cRQC4AQb7FPySgG0cHMwRMtLRi/8bu0wzCNKCUXDeY
# 60T4X/gnCgK+HtEkHSPLLxyrJ3qzqcUvDOTlkPAVJB6jFRn474PoT7toniNvfT0N
# cXBhMnxGbvKP0ZzoQ036g+H/xOA+/t5X3wZr82oGgWirDHwq949C/8BzadscpxZP
# JhlYc+2UXuQaohCCBzI7yp6/3Tl11LyLVD9+UJU0n5I5JFMYg1DUWy9mtHv+Wynr
# HsUF/aM9+6Gw8yt5D7FLrMOj2aPcLJwrI5b2eiq7rcVXtoS2Y7NgmBHsxtZmbyKD
# HIpYA/SP7JxO0N/uzmEh07WVVEk7IVE9oSOFksJb8nqUhJgKjyRWIooE+rSaiUg1
# +G/rgYYRU8CTezq01DTMYtY1YY6mUPuIdB7XMTUhHhG/q6NkU45U4nNmpPtmY+E3
# ycRr+yszixHDdJCBg8hPhsrdSpfbfpBQJaFh7IabNlIHyz5iVewzpuW4GvrdJC4M
# +TKJMWo1lf720f8Xiq4jCSshrmLu9+4357DJsxXtdpq3/ef+4WjeRMEKdOGVyFf7
# FOseWt+WdcVlGff01Y0hr2O26/TiF0aft9cHbmqdK/7p0nFO0r5PYtNJ1mBfQON2
# mSBE2Epcs10a2eKqv01ZABeeYGc6RxKgMIIGWTCCBEGgAwIBAgINAewckkDe/S5A
# XXxHdDANBgkqhkiG9w0BAQwFADBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3Qg
# Q0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2ln
# bjAeFw0xODA2MjAwMDAwMDBaFw0zNDEyMTAwMDAwMDBaMFsxCzAJBgNVBAYTAkJF
# MRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWdu
# IFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0MIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA8ALiMCP64BvhmnSzr3WDX6lHUsdhOmN8OSN5bXT8MeR0
# EhmW+s4nYluuB4on7lejxDXtszTHrMMM64BmbdEoSsEsu7lw8nKujPeZWl12rr9E
# qHxBJI6PusVP/zZBq6ct/XhOQ4j+kxkX2e4xz7yKO25qxIjw7pf23PMYoEuZHA6H
# pybhiMmg5ZninvScTD9dW+y279Jlz0ULVD2xVFMHi5luuFSZiqgxkjvyen38Dljf
# gWrhsGweZYIq1CHHlP5CljvxC7F/f0aYDoc9emXr0VapLr37WD21hfpTmU1bdO1y
# S6INgjcZDNCr6lrB7w/Vmbk/9E818ZwP0zcTUtklNO2W7/hn6gi+j0l6/5Cx1Pcp
# Fdf5DV3Wh0MedMRwKLSAe70qm7uE4Q6sbw25tfZtVv6KHQk+JA5nJsf8sg2glLCy
# lMx75mf+pliy1NhBEsFV/W6RxbuxTAhLntRCBm8bGNU26mSuzv31BebiZtAOBSGs
# sREGIxnk+wU0ROoIrp1JZxGLguWtWoanZv0zAwHemSX5cW7pnF0CTGA8zwKPAf1y
# 7pLxpxLeQhJN7Kkm5XcCrA5XDAnRYZ4miPzIsk3bZPBFn7rBP1Sj2HYClWxqjcoi
# XPYMBOMp+kuwHNM3dITZHWarNHOPHn18XpbWPRmwl+qMUJFtr1eGfhA3HWsaFN8C
# AwEAAaOCASkwggElMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEA
# MB0GA1UdDgQWBBTqFsZp5+PLV0U5M6TwQL7Qw71lljAfBgNVHSMEGDAWgBSubAWj
# kxPioufi1xzWx/B/yGdToDA+BggrBgEFBQcBAQQyMDAwLgYIKwYBBQUHMAGGImh0
# dHA6Ly9vY3NwMi5nbG9iYWxzaWduLmNvbS9yb290cjYwNgYDVR0fBC8wLTAroCmg
# J4YlaHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS9yb290LXI2LmNybDBHBgNVHSAE
# QDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2ln
# bi5jb20vcmVwb3NpdG9yeS8wDQYJKoZIhvcNAQEMBQADggIBAH/iiNlXZytCX4Gn
# CQu6xLsoGFbWTL/bGwdwxvsLCa0AOmAzHznGFmsZQEklCB7km/fWpA2PHpbyhqIX
# 3kG/T+G8q83uwCOMxoX+SxUk+RhE7B/CpKzQss/swlZlHb1/9t6CyLefYdO1RkiY
# lwJnehaVSttixtCzAsw0SEVV3ezpSp9eFO1yEHF2cNIPlvPqN1eUkRiv3I2ZOBlY
# wqmhfqJuFSbqtPl/KufnSGRpL9KaoXL29yRLdFp9coY1swJXH4uc/LusTN763lNM
# g/0SsbZJVU91naxvSsguarnKiMMSME6yCHOfXqHWmc7pfUuWLMwWaxjN5Fk3hgks
# 4kXWss1ugnWl2o0et1sviC49ffHykTAFnM57fKDFrK9RBvARxx0wxVFWYOh8lT0i
# 49UKJFMnl4D6SIknLHniPOWbHuOqhIKJPsBK9SH+YhDtHTD89szqSCd8i3VCf2vL
# 86VrlR8EWDQKie2CUOTRe6jJ5r5IqitV2Y23JSAOG1Gg1GOqg+pscmFKyfpDxMZX
# xZ22PLCLsLkcMe+97xTYFEBsIB3CLegLxo1tjLZx7VIh/j72n585Gq6s0i96ILH0
# rKod4i0UnfqWah3GPMrz2Ry/U02kR1l8lcRDQfkl4iwQfoH5DZSnffK1CfXYYHJA
# UJUg1ENEvvqglecgWbZ4xqRqqiKbMIIFgzCCA2ugAwIBAgIORea7A4Mzw4VlSOb/
# RVEwDQYJKoZIhvcNAQEMBQAwTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENB
# IC0gUjYxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24w
# HhcNMTQxMjEwMDAwMDAwWhcNMzQxMjEwMDAwMDAwWjBMMSAwHgYDVQQLExdHbG9i
# YWxTaWduIFJvb3QgQ0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UE
# AxMKR2xvYmFsU2lnbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH
# 6HPKZvnsFMp7PPcNCPG0RQssgrRIxutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay
# /xTOURQh7ErdG1rG1ofuTToVBu1kZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025
# eShNUhqKGoC3GYEOfsSKvGRMIRxDaNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qj
# uL++gmNQ0PAYid/kD3n16qIfKtJwLnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0
# pPbzlUoSB239jLKJz9CgYXfIWHSw1CM69106yqLbnQneXUQtkPGBzVeS+n68UARj
# NN9rkxi+azayOeSsJDa38O+2HBNXk7besvjihbdzorg1qkXy4J02oW9UivFyVm4u
# iMVRQkQVlO6jxTiWm05OWgtH8wY2SXcwvHE35absIQh1/OZhFj931dmRl4QKbNQC
# TXTAFO39OfuD8l4UoQSwC+n+7o/hbguyCLNhZglqsQY6ZZZZwPA1/cnaKI0aEYdw
# gQqomnUdnjqGBQCe24DWJfncBZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQU
# LHpYT9NLCEnFlWQaYw55PfWzjMpYrZxCRXluDocZXFSxZba/jJvcE+kNb7gu3Gdu
# yYsRtYQUigAZcIN5kZeR1BonvzceMgfYFGM8KEyvAgMBAAGjYzBhMA4GA1UdDwEB
# /wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSubAWjkxPioufi1xzW
# x/B/yGdToDAfBgNVHSMEGDAWgBSubAWjkxPioufi1xzWx/B/yGdToDANBgkqhkiG
# 9w0BAQwFAAOCAgEAgyXt6NH9lVLNnsAEoJFp5lzQhN7craJP6Ed41mWYqVuoPId8
# AorRbrcWc+ZfwFSY1XS+wc3iEZGtIxg93eFyRJa0lV7Ae46ZeBZDE1ZXs6KzO7V3
# 3EByrKPrmzU+sQghoefEQzd5Mr6155wsTLxDKZmOMNOsIeDjHfrYBzN2VAAiKrlN
# IC5waNrlU/yDXNOd8v9EDERm8tLjvUYAGm0CuiVdjaExUd1URhxN25mW7xocBFym
# Fe944Hn+Xds+qkxV/ZoVqW/hpvvfcDDpw+5CRu3CkwWJ+n1jez/QcYF8AOiYrg54
# NMMl+68KnyBr3TsTjxKM4kEaSHpzoHdpx7Zcf4LIHv5YGygrqGytXm3ABdJ7t+uA
# /iU3/gKbaKxCXcPu9czc8FB10jZpnOZ7BN9uBmm23goJSFmH63sUYHpkqmlD75HH
# TOwY3WzvUy2MmeFe8nI+z1TIvWfspA9MRf/TuTAjB0yPEL+GltmZWrSZVxykzLsV
# iVO6LAUP5MSeGbEYNNVMnbrt9x+vJJUEeKgDu+6B5dpffItKoZB0JaezPkvILFa9
# x8jvOOJckvB595yEunQtYQEgfn7R8k8HWV+LLUNS60YMlOH1Zkd5d9VUWx+tJDfL
# RVpOoERIyNiwmcUVhAn21klJwGW45hpxbqCo8YLoRT5s1gLXCmeDBVrJpBAxggNJ
# MIIDRQIBATBvMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52
# LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4
# NCAtIEc0AhABm+reyE1rj/dsOp8uASQWMAsGCWCGSAFlAwQCAaCCAS0wGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMCsGCSqGSIb3DQEJNDEeMBwwCwYJYIZIAWUD
# BAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3DQEJBDEiBCAasNMF+mXDDltuMtwu
# pWwVWa0jFS6HxQLEazEE25Bx1TCBsAYLKoZIhvcNAQkQAi8xgaAwgZ0wgZowgZcE
# IDqIepUbXrkqXuFPbLt2gjelRdAQW/BFEb3iX4KpFtHoMHMwX6RdMFsxCzAJBgNV
# BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9i
# YWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhABm+reyE1rj/ds
# Op8uASQWMA0GCSqGSIb3DQEBCwUABIIBgA63T32LuIoszQ3u143pJ/sM2GIig9Ve
# nR6j3N5yNXJzUz83V+5ut5G7xHO49LabRyTPnADFNB7ZCXJda5UfwsSF258Vc/yW
# 5z5gaVGdkffp3ff/6ezSoOEa+AkIN+WmrBV95D1YOO1C86PvPakazPzeZWNN90KT
# So5aEXMkfvv1o/7XyNSYjONIQ4eOi9p4aqHHDDn/tYRj+Mf26urElWJ/HtWZiBea
# 12Ehf0n9aBTKUfHzU7YzcrzicY3XGS9IxF6jv6cWYJPcpOoMvImFKjfRCOKwxPar
# I3Zk6h9cMsFQgkdc6HhNZyn1ZIXd7H2utZXwQyM795OKdY3ctR1df3HPpZEWXlni
# kYjAVWngSeUSrYizC+mZRTAOilcFhTj+02PJUj/40EwemmMvkjm9xbDcYXpiGzSO
# NFiNrf6nP+S0CixPmEyZfmwD8eBf6EGtgeF5GhNga8rfULPahrTN1JxNGn6Tj7LH
# xtXi4fQPzZw2OkoQeg+hFtvr7tpgyHAO6w==
# SIG # End signature block
