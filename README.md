# PowerShell_scripts

A collection of PowerShell scripts for various purposes.

* VMware_SSH_PW_TMP_DNS_Certs.ps1
    >A script with multiples checks on ESXi
    - Check the SSH Service (Start, test SSH and credentials and stop service)
    - TPM check
    - DNS check
    - Expiration date of SSL Certificate
    - Send report to O365 Sheet

* Dell_SSH_PW_CNC_OME.ps1
    >A script with multiples checks on DRAC of Dell servers / switches / Chassis Devices
    - Get devices from OME Server
    - SSH Test on DRAC
    - Get Model & ServiceTag
    - Change Password if default Password is used on device
    - Send report to O365 Sheet

* GetEventLog_LogOn_LogOff.ps1
    >Track Logon/Logoff events from windows eventlog.
