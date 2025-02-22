# Ensure script runs as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    exit
}

# Define progress checkpoint file
$CheckpointFile = "C:\AD_Setup_Progress.txt"

# Function to check progress
function CheckProgress($Step) {
    if (Test-Path $CheckpointFile) {
        $CompletedSteps = Get-Content $CheckpointFile
        return $CompletedSteps -contains $Step
    }
    return $false
}

# Function to mark step as completed
function MarkStepCompleted($Step) {
    Add-Content -Path $CheckpointFile -Value $Step
}

# Step 1: Configure Network (Skip if already done)
if (-not (CheckProgress "NetworkConfigured")) {
    # Prompt for network configuration
    $IPAddress = Read-Host "Enter the static IP address (e.g., 192.168.1.10)"
    $PrefixLength = Read-Host "Enter the subnet prefix length (e.g., 24 for 255.255.255.0)"
    $DefaultGateway = Read-Host "Enter the default gateway (e.g., 192.168.1.1)"
    $PrimaryDNS = Read-Host "Enter the primary DNS server IP (this server's IP if it's the DC)"
    $SecondaryDNS = Read-Host "Enter the secondary DNS server IP (another DC or external resolver like 8.8.8.8)"

    # Convert PrefixLength to an integer
    $PrefixLength = [int]$PrefixLength

    # Get the primary network adapter
    $NetAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

    if ($NetAdapter) {
        Write-Host "Resetting network configuration..."

        # Remove all existing IP addresses on the adapter
        Get-NetIPAddress -InterfaceIndex $NetAdapter.ifIndex -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

        # Remove any existing default gateway
        Remove-NetRoute -InterfaceIndex $NetAdapter.ifIndex -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

        # Reset DNS settings to default
        Set-DnsClientServerAddress -InterfaceIndex $NetAdapter.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue

        # Apply new network settings
        Write-Host "Applying new network configuration..."
        New-NetIPAddress -InterfaceIndex $NetAdapter.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
        Set-DnsClientServerAddress -InterfaceIndex $NetAdapter.ifIndex -ServerAddresses ($PrimaryDNS, $SecondaryDNS)
    } else {
        Write-Host "No active network adapter found!" -ForegroundColor Red
        exit
    }

    MarkStepCompleted "NetworkConfigured"
}

# Step 2: Rename Computer (Skip if already done)
if (-not (CheckProgress "RebootAfterRename")) {
    $NewHostname = Read-Host "Enter the new hostname for this server"
    Rename-Computer -NewName $NewHostname -Force
    Write-Host "Server name changed to $NewHostname. A reboot is required before continuing."

    # Mark progress and restart
    MarkStepCompleted "RebootAfterRename"
    Restart-Computer -Force
    exit
}

# Step 3: Install AD, DHCP, and DNS (Skip if already done)
if (-not (CheckProgress "RolesInstalled")) {
    Write-Host "Installing Active Directory Domain Services (AD DS), DHCP, and DNS..."

    # Check if the Windows Server installation ISO is mounted
    $InstallSource = "D:\Sources\SxS"
    if (Test-Path $InstallSource) {
        Install-WindowsFeature -Name AD-Domain-Services, DHCP, DNS -IncludeManagementTools -Source $InstallSource
    } else {
        Install-WindowsFeature -Name AD-Domain-Services, DHCP, DNS -IncludeManagementTools
    }

    # Verify installation was successful
    if (-not (Get-WindowsFeature AD-Domain-Services).Installed) {
        Write-Host "AD DS installation failed! Check Windows installation source." -ForegroundColor Red
        exit
    }

    MarkStepCompleted "RolesInstalled"
}

# Ensure ADDS module is available
if (-not (Get-Command Install-ADDSForest -ErrorAction SilentlyContinue)) {
    Write-Host "Loading AD DS module..."
    Import-Module ADDSDeployment -ErrorAction SilentlyContinue
}

# Step 4: Promote to Domain Controller (Skip if already done)
if (-not (CheckProgress "DomainPromoted")) {
    $DomainName = Read-Host "Enter the domain name (e.g., example.local)"
    $SafeModePassword = Read-Host "Enter a Safe Mode Administrator password (used for recovery mode)" -AsSecureString

    if (Get-Command Install-ADDSForest -ErrorAction SilentlyContinue) {
        Write-Host "Configuring the server as a domain controller..."
        Install-ADDSForest -DomainName $DomainName -SafeModeAdministratorPassword $SafeModePassword -InstallDNS -Force
        MarkStepCompleted "DomainPromoted"
    } else {
        Write-Host "ERROR: AD DS module is not available. Make sure the role is installed correctly." -ForegroundColor Red
        exit
    }
}

# Step 5: Configure DNS Forwarders (Optional)
$SetupForwarders = Read-Host "Do you want to configure DNS Forwarders? (Y/N)"
if ($SetupForwarders -match "[Yy]" -and -not (CheckProgress "DNSForwardersConfigured")) {
    $DNSForwarder1 = Read-Host "Enter a DNS forwarder IP (e.g., 8.8.8.8)"
    $DNSForwarder2 = Read-Host "Enter a second DNS forwarder IP (or press Enter to skip)"

    Write-Host "Setting DNS Forwarders..."
    Add-DnsServerForwarder -IPAddress $DNSForwarder1 -PassThru
    if ($DNSForwarder2 -ne "") {
        Add-DnsServerForwarder -IPAddress $DNSForwarder2 -PassThru
    }
    MarkStepCompleted "DNSForwardersConfigured"
}

# Step 6: Configure DHCP (Optional)
$SetupDHCP = Read-Host "Do you want to configure a DHCP scope? (Y/N)"
if ($SetupDHCP -match "[Yy]" -and -not (CheckProgress "DHCPConfigured")) {
    $DHCPStartIP = Read-Host "Enter the starting IP address for the DHCP scope (e.g., 192.168.1.100)"
    $DHCPEndIP = Read-Host "Enter the ending IP address for the DHCP scope (e.g., 192.168.1.200)"
    $DHCPSubnetMask = Read-Host "Enter the subnet mask for the DHCP scope (e.g., 255.255.255.0)"
    $DHCPLeaseTime = 8 # Default lease time in days

    Write-Host "Configuring DHCP Scope..."
    Add-DhcpServerv4Scope -Name "DefaultScope" -StartRange $DHCPStartIP -EndRange $DHCPEndIP -SubnetMask $DHCPSubnetMask -LeaseDuration (New-TimeSpan -Days $DHCPLeaseTime)
    Set-DhcpServerv4OptionValue -DnsServer $IPAddress -Router $DefaultGateway

    Write-Host "Authorizing DHCP Server in Active Directory..."
    Add-DhcpServerInDC
    MarkStepCompleted "DHCPConfigured"
}

# Final reboot prompt
$Reboot = Read-Host "Do you want to reboot now to apply changes? (Y/N)"
if ($Reboot -match "[Yy]") {
    Restart-Computer -Force
} else {
    Write-Host "Setup complete. Please reboot manually when ready."
}
