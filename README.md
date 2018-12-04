# cpm


This Ansible role install the CyberArk CPM software on a Windows 2016 server / VM / instance.
Each task in the role is independent and can be run several times, if the step already occurred then the task will be skipped.



## Requirements

- Windows 2016 must be installed on the server
- server should be available via WinRM on port 5986
- Administrator credentials (either Local or Domain)
- Network connection to the vault and the repository server (???? The server which holds the packages ????)
- Location of CPM CD image


## Role Variables

A list of vaiables the playbook is using 

**CI/CD Flow Variables**
                    
| Variable                         | Required     | Default                                                                        | Comments                                 |
|----------------------------------|--------------|--------------------------------------------------------------------------------|------------------------------------------|
| cpm_prerequisites                | no           | false                                                                          | Install CPM pre requisites               |
| cpm_install                      | no           | false                                                                          | Install CPM                              |
| cpm_postinstall                  | no           | false                                                                          | CPM port install role                    |
| cpm_hardening                    | no           | false                                                                          | CPM hardening role                       |
| cpm_registration                 | no           | false                                                                          | CPM Register with Vault                  |
| cpm_upgrade                      | no           | false                                                                          | N/A                                      |
| cpm_clean                        | no           | false                                                                          | Clean server after deployment            |
| cpm_uninstall                    | no           | false                                                                          | N/A                                      |

**Installation Variables**

| Variable                         | Required     | Default                                                                        | Comments                                 |
|----------------------------------|--------------|--------------------------------------------------------------------------------|------------------------------------------|
| cpm_base_bin_drive               | no           | "C:"                                                                           | Base path to extract CyberArk packages   |
| cpm_zip_file_path                | no           | "C:\\Cyberark\\packages"                                                       | Zip File path of CyberArk packages       |
| cpm_extract_folder               | no           | "{{cpm_base_bin_drive}}\\Cyberark\\packages"                                   | Path to extract the CyberArk packages    |
| cpm_artifact_name                | no           | "cpm.zip"                                                                      | zip file name of cpm package             |
| cpm_component_folder             | no           | "Central Policy Manager"                                                       | The name of CPM unzip folder             |
| cpm_installation_drive           | no           | "C:"                                                                           | Base drive to install CPM                |
| vault_ip                         | yes          | None                                                                           | Vault ip to perform registration         |
| dr_vault_ip                      | no           | None                                                                           | vault dr ip to perform registration      |
| vault_port                       | no           | 1858                                                                           | vault port                               |
| vault_username                   | no           | "administrator"                                                                | vault username to perform registration   |
| vault_password                   | yes          | None                                                                           | vault password to perform registration   |
| pvwa_url                         | yes          | None                                                                           |  URL of registered PVWA                   |


## Usage 

**cpm_install**

This task will deploy the CPM to required folder and validate deployment succeed.

**cpm_hardening**

This task will run the CPM hardening process

**cpm_registration**

This task perform registration with active Vault

**cpm_validateparameters**

This task validate which CPM steps already occurred on the server so the other tasks won't run again

**cpm_clean**

This task will clean inf files from installation, delete cpm installation logs from Temp folder & Delete cred files


## Example Playbook

Example playbook to show how to call the CPM main playbook with several parameters:

    ---
    - hosts: localhost
      connection: local
      tasks:
        - include_task:
            name: main
          vars:
            cpm_install: true
            cpm_hardening: true
            cpm_clean: true

## Running the  playbook:

To run the above playbook:

    ansible-playbook -i ../inventory.yml cpm-orchestrator.yml -e "cpm_install=true cpm_installation_drive='D:'"

## License

Apache 2  **TBD**
