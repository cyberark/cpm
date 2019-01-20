# @FUNCTION@ ======================================================================================================================
# Name...........: Execute
# Description....: Enable TLS 1.2 protocol.
# Parameters.....: None
# Return Values..: None
# Function Group.: Main Hardening Functionality
# =================================================================================================================================
function Execute{
	 [CmdletBinding()]
	 Param(
		[Parameter(Mandatory=$false)]
		[array]$Args = $null
	 )

	 Process{

		$versionToEnable = "TLS 1.2"

		$clientPathFormat = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\Client"
		$serverPathFormat = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\{0}\Server"
		$DOT_NET_64bit_Path = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319"
		$DOT_NET_32bit_Path = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"
		$DOT_NET_Value_name = "SchUseStrongCrypto"

		$clientPathVersionToEnable = $clientPathFormat -f $versionToEnable
		$serverPathVersionToEnable = $serverPathFormat -f $versionToEnable

		$disabledByDefaultValueName = 'DisabledByDefault'
		$enabledValueName = 'Enabled'

		$type = 'DWord'

		# Enable TLS 1.2 client version
		Add-Edit-RegistryEntry $clientPathVersionToEnable $enabledValueName 1
		Add-Edit-RegistryEntry $clientPathVersionToEnable $disabledByDefaultValueName 0

		# Enable TLS 1.2 server version
		Add-Edit-RegistryEntry $serverPathVersionToEnable $enabledValueName 1
		Add-Edit-RegistryEntry $serverPathVersionToEnable $disabledByDefaultValueName 0

		# Enable .NET framework use TLS1.2
		Add-Edit-RegistryEntry $DOT_NET_64bit_Path $DOT_NET_Value_name 1
		Add-Edit-RegistryEntry $DOT_NET_32bit_Path $DOT_NET_Value_name 1

		$true
	}
	End{
	}
}

function Add-Edit-RegistryEntry{
[CmdletBinding()]
   param(
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regPath,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regName,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regValue,
   [parameter(Mandatory=$false)]
   [ValidateNotNullOrEmpty()]$regType = "DWord"
   )
	Process {

		if(Test-CARegistryEntryExist $regPath $regName){
			Set-CARegistryEntry $regPath $regName $regValue
		} else {
			Write-Host $regPath $regName $regValue $type
		}
	}
	End{
   }
}

# @FUNCTION@ ======================================================================================================================
# Name...........: Set-CARegistryEntry
# Description....: Changes a registry entry value using the registry path, property name and property value submitted.
# Parameters.....: $regPath - The full path of the registry key
#                  $regKey - The name of the registry item to be changed
#                  $regValue - The value that the registry item will be changed to
# Return Values..: None
# =================================================================================================================================
function Set-CARegistryEntry{
   [CmdletBinding()]
   param(
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regPath,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regKey,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regValue
   )

	Process {
		Try{

			Set-ItemProperty -Path $regPath -Name $regKey -Value $regValue

			Get-CARegistryEntryValue -regPath $regPath -regKey $regKey

		}Catch{
			Write-Host $_.Exception
		}
	}
	End{
   }
}

# @FUNCTION@ ======================================================================================================================
# Name...........: Add-CARegistryEntry
# Description....: Creates a new registry entry using the registry path, property name, property value and property type submitted
# Parameters.....: $regPath - The full path of the registry key that is being created
#                  $regKey - The name of the registry item be created
#                  $regValue - The value that the registry item will be set as
#                  $regProperty - The type of the registry property that will be created
# Return Values..: None
# =================================================================================================================================
function Add-CARegistryEntry{
	[CmdletBinding()]
   param(
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regPath,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regKey,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regValue,
   [parameter(Mandatory=$false)]
   [ValidateNotNullOrEmpty()]$regProperty
   )

	Process {
		Try{
			If(-not(Test-Path -Path $regPath)){
				Add-CALogAll "Attempting to create new registry path: $regPath"
				New-Item -Path $regPath -Force
			}

			New-ItemProperty -Path $regPath -Name $regKey -Value $regValue -PropertyType $regProperty

			Get-CARegistryEntryValue -regPath $regPath -regKey $regKey

		}Catch{
			Write-Host $_.Exception
		}
	}
	End{
   }
}

# @FUNCTION@ ======================================================================================================================
# Name...........: Test-CARegistryEntryExist
# Description....: Checks if a registry value exists from submitted path and value parameters and returns a boolean value
# Parameters.....: $regPath - Registry path
#                  $regKey - Registry key name
# Return Values..: $true
#                  $false
# =================================================================================================================================
function Test-CARegistryEntryExist{
	[CmdletBinding()]
   param (
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regPath,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regKey
   )

	Process {
		If (Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) {
			Get-CARegistryEntryValue -regPath $regPath -regKey $regKey
			return $true
		}
		return $false
	}
	End{
		Write-Host "Finish checking if a registry entry exists"
   }
}

# @FUNCTION@ ======================================================================================================================
# Name...........: Get-CARegistryEntryValue
# Description....: Return registry value from path and key provided. Also print the value for the log
# Parameters.....: $regPath - Registry path
#                  $regKey - Registry key name
# Return Values..: return registry key value if exist, or $null if not found.
#
# =================================================================================================================================
function Get-CARegistryEntryValue{
	[CmdletBinding()]
   param (
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regPath,
   [parameter(Mandatory=$true)]
   [ValidateNotNullOrEmpty()]$regKey
   )

	Process {
		try {
         $returnRegValue = $null
			$returnRegValue = (Get-ItemProperty -Path $regPath -Name $regKey).$regKey
		}Catch{
         $returnRegValue = $null
			Write-Host $_.Exception
		}

      return $returnRegValue
	}
	End{
   }
}

Execute