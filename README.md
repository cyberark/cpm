# CPM Ansible Role
This Ansible Role will deploy and install CyberArk Central Policy Manager including the pre-requisites, application, hardening and connect to an existing Vault environment.

## Requirements
------------
- Windows 2016 installed on the remote host
- WinRM open on port 5986 (**not 5985**) on the remote host 
- Pywinrm is installed on the workstation running the playbook
- The workstation running the playbook must have network connectivity to the remote host
- The remote host must have Network connectivity to the CyberArk vault and the repository server
  - 443 port outbound
  - 1858 port outbound 
- Administrator access to the remote host 
- CPM CD image



## Role Variables
These are the variables used in this playbook:

### Flow Variables
Variable                         | Required     | Default                                   | Comments
:--------------------------------|:-------------|:------------------------------------------|:---------
cpm_prerequisites                | no           | false                                     | Install CPM pre requisites
cpm_install                      | no           | false                                     | Install CPM
cpm_postinstall                  | no           | false                                     | CPM post install role
cpm_hardening                    | no           | false                                     | Apply CPM hardening 
cpm_registration                 | no           | false                                     | Connect CPM to the Vault
cpm_upgrade                      | no           | false                                     | N/A
cpm_clean                        | no           | false                                     | N/A
cpm_uninstall                    | no           | false                                     | N/A

### Deployment Variables
Variable                         | Required     | Default                                              | Comments
:--------------------------------|:-------------|:-----------------------------------------------------|:---------
vault_ip                         | yes          | None                                                 | Vault IP to perform registration
vault_password                   | yes          | None                                                 | Vault password to perform registration
pvwa_url                         | yes          | None                                                 | URL of registered PVWA
accept_eula                      | yes          | **"No"**                                             | Accepting EULA condition 
cpm_zip_file_path                | yes          | None                                                 | Zip File path of CyberArk packages
vault_username                   | no           | **administrator**                                    | Vault username to perform registration
vault_port                       | no           | **1858**                                             | Vault port
dr_vault_ip                      | no           | None                                                 | Vault DR IP address to perform registration
cpm_installation_drive           | no           | **C:**                                               | Base drive to install CPM

## Dependencies
None

## Usage
The role consists of a number of different tasks which can be enabled or disabled for the particular
run.

`cpm_install`

This task will deploy the CPM to required folder and validate successful deployment.

`cpm_hardening`

This task will run the CPM hardening process.

`cpm_registration`

This task will perform registration with active Vault.

`cpm_validateparameters`

This task will validate which CPM steps have already occurred on the server to prevent repetition.

`cpm_clean`

This task will clean the configuration (inf) files from the installation, delete the
CPM installation logs from the Temp folder and delete the cred files.

## Example Playbook
Below is an example of how you can incorporate this role into an Ansible playbook
to call the CPM role with several parameters:

```
---
- include_role:
    name: cpm
  vars:
    - cpm_prerequisites: true
    - cpm_install: true
    - cpm_postinstall: true
    - cpm_hardening: true
    - cpm_registration: true
```

## Running the  playbook:
For an example of how to incorporate this role into a complete playbook, please see the
**[pas-orchestrator](https://github.com/cyberark/pas-orchestrator)** example.

## License
[Apache 2](LICENSE)
