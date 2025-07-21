# Define agent version and download URL
$ZabbixVersion = "7.2.6" # Update this to the latest stable version if needed
$ZabbixMajorVersion = ($ZabbixVersion -Split '\.')[0..1] -join '.'
$DownloadUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/$ZabbixMajorVersion/$ZabbixVersion/zabbix_agent2-$ZabbixVersion-windows-amd64-openssl.msi"
$TempPath = Join-Path $env:TEMP "zabbix_agent2.msi"
$InstallPath = "C:\Program Files\Zabbix Agent 2"
$ConfigFile = Join-Path $InstallPath "zabbix_agent2.conf"

# Zabbix Server Map
$ZabbixServerMap = @{
    "10.128.16"   = "10.128.16.199";
    "10.128.18"   = "10.128.18.9";
    "10.160.145"  = "10.160.145.199";
    "10.192.192"  = "10.192.192.9";
    "172.22.10"   = "172.22.10.9";
    "172.22.12"   = "172.22.12.9";
    "172.22.14"   = "172.22.14.9";
    "172.22.16"   = "172.22.16.9";
    "172.22.24"   = "172.22.10.9";
    "172.22.32"   = "172.22.32.9";
    "172.22.40"   = "172.22.40.9";
    "172.22.50"   = "172.22.50.9";
    "192.168.200" = "192.168.200.11"
}

# Determine Zabbix Server based on local IP
$ZabbixServer = $null
$ZabbixServerActive = $null

$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike "169.254.*" }

foreach ($ip in $ipAddresses) {
    $ipParts = $ip.IPAddress.Split('.')
    if ($ipParts.Count -eq 4) {
        $currentPrefix = "$($ipParts[0]).$($ipParts[1]).$($ipParts[2])"
        if ($ZabbixServerMap.ContainsKey($currentPrefix)) {
            $ZabbixServer = $ZabbixServerMap[$currentPrefix]
            $ZabbixServerActive = $ZabbixServer
            break
        }
    }
}

# If Zabbix Server could not be determined, prompt the user
if (-not $ZabbixServer) {
    Write-Warning "Could not automatically determine Zabbix Server based on local IP address."
    $UserProvidedServer = Read-Host "Please enter the Zabbix Server IP address or Hostname"
    if ([string]::IsNullOrWhiteSpace($UserProvidedServer)) {
        Write-Error "No Zabbix Server IP/Hostname provided. Exiting."
        exit 1
    }
    $ZabbixServer = $UserProvidedServer
    $ZabbixServerActive = $UserProvidedServer
    Write-Host "Using user-provided Zabbix Server: $ZabbixServer"
}

# Get Hostname (just the computer name, not FQDN)
$ZabbixHostname = $env:COMPUTERNAME

try {
    # Check if Zabbix Agent 2 is already installed
    $service = Get-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "Zabbix Agent 2 is already installed. Skipping installation."
    } else {
        Write-Host "Zabbix Agent 2 not detected, starting installation..."
        Write-Host "Downloading Zabbix Agent 2 from $DownloadUrl..."
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempPath -UseBasicParsing
        Write-Host "Download complete. Installing Zabbix Agent 2..."

        $LogFile = Join-Path $env:TEMP "zabbix_agent2_install.log"
        $msiArgs = "/i `"$TempPath`" /qn /L*V `"$LogFile`" SERVER=$ZabbixServer SERVERACTIVE=$ZabbixServerActive HOSTNAME=`"$ZabbixHostname`" HOSTMETADATA=windows"
        $InstallProcess = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -NoNewWindow -PassThru

        if ($InstallProcess.ExitCode -ne 0) {
            Write-Error "Zabbix Agent 2 installation failed with exit code $($InstallProcess.ExitCode). Check '$LogFile' for details."
            exit $InstallProcess.ExitCode
        }
        Write-Host "Zabbix Agent 2 installed successfully."
    }

    # Configuration will run if installed or was already present
    Write-Host "Configuring Zabbix Agent..."

    if (Test-Path $ConfigFile) {
        $ConfigFileContent = Get-Content $ConfigFile -Raw

        # Update Server, ServerActive, and HostMetadata
        $ConfigFileContent = $ConfigFileContent -replace "(?m)^#?\s*Server=.*", "Server=$ZabbixServer"
        $ConfigFileContent = $ConfigFileContent -replace "(?m)^#?\s*ServerActive=.*", "ServerActive=$ZabbixServerActive"
        $ConfigFileContent = $ConfigFileContent -replace "(?m)^#?\s*HostMetadata=.*", "HostMetadata=windows"
        
        # Only update Hostname if it's not already correctly set (to avoid duplicates)
        if ($ConfigFileContent -notmatch "(?m)^Hostname=$ZabbixHostname$") {
            $ConfigFileContent = $ConfigFileContent -replace "(?m)^#?\s*Hostname=.*", "Hostname=$ZabbixHostname"
        }

        $ConfigFileContent | Set-Content $ConfigFile

        Write-Host "Zabbix Agent 2 configuration updated."

        # Restart / Start the Zabbix Agent 2 service
        Start-Sleep -Seconds 5
        Get-Service -Name "Zabbix Agent 2" | Restart-Service -Force
        Write-Host "Zabbix Agent 2 service restarted."
    } else {
        Write-Warning "Zabbix Agent 2 configuration file not found at $ConfigFile. Please configure it manually."
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
