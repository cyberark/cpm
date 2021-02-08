<powershell>
# Change Password
$admin = [adsi]("WinNT://./administrator, user")
$admin.PSBase.Invoke("SetPassword", "Nopass123")

# Configure machine for ansible remoting
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "$env:temp\ConfigureRemotingForAnsible.ps1"
Invoke-WebRequest -Uri $url -OutFile $file
powershell.exe -ExecutionPolicy ByPass -File $file -EnableCredSSP
</powershell>