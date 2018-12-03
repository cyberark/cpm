CPM
=========

This Playbook will install the CyberArk CPM software on a Windows 2016 server / VM / instance

Requirements
------------

- Windows 2016 must be installed on the server
- Administrator credentials (either Local or Domain)
- Location of CPM CD image
- 

Role Variables
--------------

A list of vaiables the playbook is using 

| Variable                  | Required | Default | Choices                   | Comments                                 |
|---------------------------|----------|---------|---------------------------|------------------------------------------|
| cpm_uninstall             | no       | false   | true, false               | N/A                                      |
| cpm_prerequisites         | no       | false   | true, false               | Install CPM pre requisites               |
| cpm_install               | no       | false   | true, false               | Install CPM                              |
| cpm_postinstall           | no       | false   | true, false               | CPM port install role                    |
| cpm_hardening             | no       | false   | true, false               | CPM hardening role                       |
| cpm_registration          | no       | false   | true, false               | CPM Register with Vault                  |
| cpm_upgrade               | no       | false   | true, false               | N/A                                      |
| cpm_clean                 | no       | false   | true, false               | Clean host from installation             |


Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: localhost
      connection: local
      tasks:
        - include_task:
            name: main
          vars:
            cpm_install: true
            cpm_hardening: true
            cpm_clean: true

License
-------

Apache 2 
