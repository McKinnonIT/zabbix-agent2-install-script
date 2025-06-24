# Zabbix Agent 2 Installation Script for Windows

This repository contains a PowerShell script to automate the installation and configuration of the Zabbix Agent 2 on Windows systems.

## Prerequisites

- Windows PowerShell
- Administrator privileges

## Usage

To download and run the script, open an elevated PowerShell prompt and execute the following command:

```powershell
irm https://raw.githubusercontent.com/McKinnonIT/zabbix-agent2-install-script/refs/heads/main/Zabbix-Agent2-Install.ps1 | iex
```

## Important Notes

- If the Zabbix Agent 2 is already installed, the script will skip the installation and only perform the configuration steps. This may fail if the existing service is in a non-operational state.
- The script does not handle version upgrades. If a different version of the agent is already installed, this script will not upgrade it to the version specified in the script.

## Customization

You can fork this repository and customize the script. The following variables at the top of the `Zabbix-Agent2-Install.ps1` file are intended for modification:

- `$ZabbixVersion`: The version of the Zabbix Agent 2 to install.
- `$ZabbixServerMap`: A map of IP address prefixes to Zabbix Server IP addresses for the automatic detection logic. 