
# Enum definitions for better type safety
enum ServerType {
    VM
    Hypervisor
    BareMetal
}
IF(!$Environment){
    enum Environment {
    Development
    Staging
    Production
}

}


enum OSDistribution {
    Windows
    Linux
    ESXi
    HyperV
    Other
}

# Class to represent a network interface card
class NetworkInterface {
    hidden [string]$_name
    hidden [string]$_macAddress
    hidden [System.Collections.Generic.List[IPAddress]]$_ipAddresses
    hidden [System.Collections.Generic.List[NetworkConnection]]$_networkConnections
    hidden [bool]$_isEnabled
    hidden [int]$_speedMbps

    # Property with validation for Name
    [string]$Name
    
    # Property with validation for MACAddress
    [string]$MACAddress
    
    [System.Collections.Generic.List[IPAddress]]$IPAddresses
    [System.Collections.Generic.List[NetworkConnection]]$NetworkConnections
    [bool]$IsEnabled
    [int]$SpeedMbps

    NetworkInterface([string]$name, [string]$macAddress) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Network interface name cannot be empty"
        }
        if (-not $this.ValidateMACAddress($macAddress)) {
            throw "Invalid MAC address format: $macAddress"
        }
        
        $this.Name = $name
        $this.MACAddress = $macAddress
        $this.IPAddresses = [System.Collections.Generic.List[IPAddress]]::new()
        $this.NetworkConnections = [System.Collections.Generic.List[NetworkConnection]]::new()
        $this.IsEnabled = $true
    }
    
    [bool]ValidateMACAddress([string]$mac) {
        if ([string]::IsNullOrWhiteSpace($mac)) {
            return $false
        }
        
        # Validate MAC address format (supports formats like 00:50:56:12:34:56, 00-50-56-12-34-56, or 005056123456)
        $macPattern = '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$|^[0-9A-Fa-f]{12}
    }$'
        return $mac -match $macPattern
    }
    [void]AddIPAddress([string]$ip, [string]$subnetMask) {
        # Validate IP address format
        if (-not $this.ValidateIPAddress($ip)) {
            throw "Invalid IP address format: $ip"
        }
        
        # Validate subnet mask format
        if (-not $this.ValidateIPAddress($subnetMask)) {
            throw "Invalid subnet mask format: $subnetMask"
        }
        
        $ipAddr = [IPAddress]::new($ip, $subnetMask)
        $this.IPAddresses.Add($ipAddr)
    }

    [bool]ValidateIPAddress([string]$ipString) {
        if ([string]::IsNullOrWhiteSpace($ipString)) {
            return $false
        }
        
        # Try to parse as System.Net.IPAddress
        try {
            $parsedIP = [System.Net.IPAddress]::Parse($ipString)
            # Ensure it's IPv4 or IPv6
            return ($parsedIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -or 
                    $parsedIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6)
        }
        catch {
            return $false
        }
    }

    [void]AddNetworkConnection([string]$networkName, [int]$vlanId) {
        $connection = [NetworkConnection]::new($networkName, $vlanId)
        $this.NetworkConnections.Add($connection)
    }
}

# Class to represent IP address configuration
class IPAddress {
    hidden [string]$_address
    hidden [string]$_subnetMask
    hidden [string]$_gateway
    
    [string]$Address
    [string]$SubnetMask
    [string]$Gateway
    [bool]$IsDHCP

    IPAddress([string]$address, [string]$subnetMask) {
        if (-not $this.ValidateIPAddress($address)) {
            throw "Invalid IP address format: $address"
        }
        if (-not $this.ValidateIPAddress($subnetMask)) {
            throw "Invalid subnet mask format: $subnetMask"
        }
        
        $this.Address = $address
        $this.SubnetMask = $subnetMask
        $this.IsDHCP = $false
    }
    
    [void]SetGateway([string]$gateway) {
        if (-not [string]::IsNullOrWhiteSpace($gateway) -and -not $this.ValidateIPAddress($gateway)) {
            throw "Invalid gateway IP address format: $gateway"
        }
        $this.Gateway = $gateway
    }
    
    [bool]ValidateIPAddress([string]$ipString) {
        if ([string]::IsNullOrWhiteSpace($ipString)) {
            return $false
        }
        
        try {
            $parsedIP = [System.Net.IPAddress]::Parse($ipString)
            return ($parsedIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -or 
                    $parsedIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6)
        }
        catch {
            return $false
        }
    }
}

# Class to represent network connection with VLAN
class NetworkConnection {
    hidden [string]$_networkName
    hidden [int]$_vlanId
    
    [string]$NetworkName
    [int]$VLANId
    [string]$NetworkDescription

    NetworkConnection([string]$networkName, [int]$vlanId) {
        if ([string]::IsNullOrWhiteSpace($networkName)) {
            throw "Network name cannot be empty"
        }
        if ($vlanId -lt 1 -or $vlanId -gt 4094) {
            throw "VLAN ID must be between 1 and 4094 (provided: $vlanId)"
        }
        
        $this.NetworkName = $networkName
        $this.VLANId = $vlanId
    }
}

# Main Server class
class Server {
    # Identity and basic properties
    hidden [guid]$_guid
    hidden [string]$_name
    hidden [ServerType]$_type
    hidden [string]$_hardwareIdentifier
    
    [guid]$GUID
    [string]$Name
    [ServerType]$Type
    [string]$HardwareIdentifier
    
    # Environment and ownership
    [Environment]$Environment
    [string]$ApplicationStack
    [string]$Owner
    
    # Operating System information
    [OSDistribution]$OSDistribution
    [string]$OSVersion
    
    # Virtualization properties
    [string]$HostServer
    [string]$HypervisorType
    
    # Hardware specifications
    [int]$CPUCores
    [long]$MemoryGB
    [long]$StorageGB
    
    # Network configuration
    [System.Collections.Generic.List[NetworkInterface]]$NetworkInterfaces
    
    # Metadata
    [datetime]$CreatedDate
    [datetime]$LastModified
    [hashtable]$Tags

    # Constructor with required parameters
    Server(
        [string]$name,
        [ServerType]$type,
        [Environment]$environment,
        [string]$applicationStack,
        [string]$owner
    ) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Server name cannot be empty"
        }
        if ([string]::IsNullOrWhiteSpace($applicationStack)) {
            throw "Application stack cannot be empty"
        }
        if ([string]::IsNullOrWhiteSpace($owner)) {
            throw "Owner cannot be empty"
        }
        
        $this.GUID = [guid]::NewGuid()
        $this.Name = $name
        $this.Type = $type
        $this.Environment = $environment
        $this.ApplicationStack = $applicationStack
        $this.Owner = $owner
        $this.NetworkInterfaces = [System.Collections.Generic.List[NetworkInterface]]::new()
        $this.CreatedDate = Get-Date
        $this.LastModified = Get-Date
        $this.Tags = @{}
    }

    # Method to add a network interface
    [void]AddNetworkInterface([NetworkInterface]$nic) {
        if ($null -eq $nic) {
            throw "Network interface cannot be null"
        }
        $this.NetworkInterfaces.Add($nic)
        $this.LastModified = Get-Date
    }

    # Method to set virtualization details
    [void]SetVirtualizationDetails([string]$hostServer, [string]$hypervisorType, [string]$hardwareId) {
        if ($this.Type -ne [ServerType]::VM) {
            throw "Virtualization details can only be set for VM server types"
        }
        if ([string]::IsNullOrWhiteSpace($hostServer)) {
            throw "Host server cannot be empty for VM"
        }
        if ([string]::IsNullOrWhiteSpace($hypervisorType)) {
            throw "Hypervisor type cannot be empty for VM"
        }
        if ([string]::IsNullOrWhiteSpace($hardwareId)) {
            throw "Hardware identifier cannot be empty"
        }
        
        $this.HostServer = $hostServer
        $this.HypervisorType = $hypervisorType
        $this.HardwareIdentifier = $hardwareId
        $this.LastModified = Get-Date
    }

    # Method to set operating system details
    [void]SetOSDetails([OSDistribution]$distribution, [string]$version) {
        if ([string]::IsNullOrWhiteSpace($version)) {
            throw "OS version cannot be empty"
        }
        
        $this.OSDistribution = $distribution
        $this.OSVersion = $version
        $this.LastModified = Get-Date
    }

    # Method to set hardware specifications
    [void]SetHardwareSpecs([int]$cpuCores, [long]$memoryGB, [long]$storageGB) {
        if ($cpuCores -lt 1) {
            throw "CPU cores must be at least 1 (provided: $cpuCores)"
        }
        if ($memoryGB -lt 1) {
            throw "Memory must be at least 1 GB (provided: $memoryGB)"
        }
        if ($storageGB -lt 1) {
            throw "Storage must be at least 1 GB (provided: $storageGB)"
        }
        
        $this.CPUCores = $cpuCores
        $this.MemoryGB = $memoryGB
        $this.StorageGB = $storageGB
        $this.LastModified = Get-Date
    }

    # Method to add tags for additional metadata
    [void]AddTag([string]$key, [string]$value) {
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw "Tag key cannot be empty"
        }
        
        $this.Tags[$key] = $value
        $this.LastModified = Get-Date
    }

    # Method to get all IP addresses across all NICs
    [string[]]GetAllIPAddresses() {
        $allIPs = @()
        foreach ($nic in $this.NetworkInterfaces) {
            foreach ($ip in $nic.IPAddresses) {
                $allIPs += $ip.Address
            }
        }
        return $allIPs
    }

    # Method to get summary information
    [string]ToString() {
        return "$($this.Name) [$($this.Type)] - $($this.Environment) - $($this.ApplicationStack)"
    }

    # Method to export server configuration
    [hashtable]ToHashtable() {
        return @{
            GUID = $this.GUID
            Name = $this.Name
            Type = $this.Type
            Environment = $this.Environment
            ApplicationStack = $this.ApplicationStack
            Owner = $this.Owner
            OSDistribution = $this.OSDistribution
            OSVersion = $this.OSVersion
            HostServer = $this.HostServer
            HypervisorType = $this.HypervisorType
            HardwareIdentifier = $this.HardwareIdentifier
            CPUCores = $this.CPUCores
            MemoryGB = $this.MemoryGB
            StorageGB = $this.StorageGB
            NetworkInterfaceCount = $this.NetworkInterfaces.Count
            CreatedDate = $this.CreatedDate
            LastModified = $this.LastModified
        }
    }
}

# Example usage demonstrating the class capabilities

# Create a VM server
$webServer = [Server]::new(
    "web-prod-01",
    [ServerType]::VM,
    [Environment]::Production,
    "WebApplication",
    "john.doe@company.com"
)

# Set OS details
$webServer.SetOSDetails([OSDistribution]::Linux, "Ubuntu 22.04 LTS")

# Set virtualization details
$webServer.SetVirtualizationDetails("esxi-host-03", "VMware ESXi 7.0", "564d1234-5678-90ab-cdef-1234567890ab")

# Set hardware specs
$webServer.SetHardwareSpecs(8, 32, 500)

# Create and add network interface
$nic1 = [NetworkInterface]::new("eth0", "00:50:56:12:34:56")
$nic1.AddIPAddress("10.10.10.50", "255.255.255.0")
$nic1.AddNetworkConnection("Production-Web", 100)
$webServer.AddNetworkInterface($nic1)

# Add another NIC for management network
$nic2 = [NetworkInterface]::new("eth1", "00:50:56:12:34:57")
$nic2.AddIPAddress("10.20.20.50", "255.255.255.0")
$nic2.AddNetworkConnection("Management", 200)
$webServer.AddNetworkInterface($nic2)

# Add custom tags
$webServer.AddTag("CostCenter", "IT-Web-Services")
$webServer.AddTag("BackupSchedule", "Daily")

# Display server info
Write-Host $webServer.ToString()
Write-Host "Server GUID: $($webServer.GUID)"
Write-Host "All IP Addresses: $($webServer.GetAllIPAddresses() -join ', ')"

# Export configuration
$config = $webServer.ToHashtable()
$config | Format-Table
