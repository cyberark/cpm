# CPM Ansible Role
This Playbook will install the [CyberArk CPM](https://www.cyberark.com/products/privileged-account-security-solution/core-privileged-account-security/) software on a Windows 2016 server / VM / instance.

## Requirements
------------
- The host running the playbook must have network connectivity to the remote hosts in the inventory
- Windows 2016 must be installed on the remote host
- Administrator credentials for access to the remote host (either Local or Domain)
- Network connectivity to the CyberArk vault and the repository server
- CPM package version 10.6 and above, including the location of the CD images
- pywinrm is installed on the workstation running the playbook


## Role Variables
These are the variables used in this playbook:

### Flow Variables
Variable                         | Required     | Default                                   | Comments
:--------------------------------|:-------------|:------------------------------------------|:---------
cpm_prerequisites                | no           | false                                     | Install CPM pre requisites
cpm_install                      | no           | false                                     | Install CPM
cpm_postinstall                  | no           | false                                     | CPM port install role
cpm_hardening                    | no           | false                                     | CPM hardening role
cpm_registration                 | no           | false                                     | CPM Register with Vault
cpm_upgrade                      | no           | false                                     | N/A            
cpm_clean                        | no           | false                                     | Clean server after deployment
cpm_uninstall                    | no           | false                                     | N/A     

### Deployment Variables
Variable                         | Required     | Default                                              | Comments         
:--------------------------------|:-------------|:-----------------------------------------------------|:---------
vault_ip                         | yes          | None                                                 | Vault IP to perform registration   
vault_password                   | yes          | None                                                 | Vault password to perform registration
pvwa_url                         | yes          | None                                                 | URL of registered PVWA                 
accept_eula                      | yes          | **No**                                               | Accepting EULA condition       
cpm_zip_file_path                | yes          | None                                                 | Zip File path of CyberArk packages   
vault_username                   | no           | **administrator**                                    | Vault username to perform registration
vault_port                       | no           | **1858**                                             | Vault port
dr_vault_ip                      | no           | None                                                 | Vault DR IP address to perform registration
cpm_base_bin_drive               | no           | **C:**                                               | Base path to extract CyberArk packages
cpm_extract_folder               | no           | **{{cpm_base_bin_drive}}\\Cyberark\\packages**       | Path to extract the CyberArk packages
cpm_artifact_name                | no           | **cpm.zip**                                          | Zip file name of cpm package
cpm_component_folder             | no           | **Central Policy Manager**                           | The name of CPM unzip folder
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
