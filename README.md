# cpm


This Playbook will install the CyberArk CPM software on a Windows 2016 server / VM / instance.
Each task in the role is independent and can be run several times, in the step already occurred then the task will be skipped.


## Requirements

- Windows 2016 must be installed on the server
- hosts should be available via WinRM on port 5986
- Administrator credentials (either Local or Domain)
- Network connection to the vault and the repository server (???? The server which holds the packages ????)
- Location of CPM CD image


## Role Variables

A list of vaiables the playbook is using 

| Variable                         | Required     | Default                                                                        | Choices                   | Comments                                 |
|----------------------------------|--------------|--------------------------------------------------------------------------------|---------------------------|------------------------------------------|
| cpm_uninstall                    | no           | false                                                                          | true, false               | N/A                                      |
| cpm_prerequisites                | no           | false                                                                          | true, false               | Install CPM pre requisites               |
| cpm_install                      | no           | false                                                                          | true, false               | Install CPM                              |
| cpm_postinstall                  | no           | false                                                                          | true, false               | CPM port install role                    |
| cpm_hardening                    | no           | false                                                                          | true, false               | CPM hardening role                       |
| cpm_registration                 | no           | false                                                                          | true, false               | CPM Register with Vault                  |
| cpm_upgrade                      | no           | false                                                                          | true, false               | N/A                                      |
| cpm_base_bin_path                | no           | "C:"                                                                           | "C:", "D:"...             | Base path to extract CyberArk packages   |
| cpm_zip_file_path                | yes          | None                                                                           | string                    | Zip File path of CyberArk packages       |
| cpm_extract_folder               | no           | "{{ cpm_base_bin_path }}\\Cyberark\\packages"                                  | string                    | Zip File path of CyberArk packages       |
| cpm_artifact_name                | no           | "cpm.zip"                                                                      | string                    | zip file name of cpm package             |
| cpm_component_folder             | no           | "Central Policy Manager"                                                       | string                    | The name of CPM unzip folder             |
| cpm_installationautomation_folder| no           | "{{ cpm_extract_folder }}\\{{ cpm_component_folder }}\\InstallationAutomation" | string                    | The name of CPM unzip folder             |
| cpm_installation_drive           | no           | "C:"                                                                           | "C:", "D:"...             | Base drive to install CPM                |
| cpm_installation_path            | no           | "{{ cpm_installation_drive }}\\Program Files (x86)\\CyberArk\\Password Manager"| true, false               |             |
| cpm_registrationtool_folder      | no           | "{{ cpm_base_bin_path }}\\Cyberark\\Components Registration"                   | true, false               |             |
| vault_ip                         | yes          | None                                                                           | string                    | Vault ip to perform registration         |
| dr_vault_ip                      | no           | None                                                                           | string                    | vault dr ip to perform registration      |
| vault_port                       | no           | 1858                                                                           | integer                   | vault port                               |
| vault_username                   | no           | "administrator"                                                                | string                    | vault username to perform registration   |
| vault_password                   | yes          | None                                                                           | string                    | vault password to perform registration   |
| pvwa_url                         | yes          | None                                                                           | URL                       | URL of registered PVWA                   |
                    


## Dependencies

This is a sub role which should be called by parent role, 


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
