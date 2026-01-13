class NetworkInterface {
    [string]$InterfaceName
    [string]$IPAddress
    [string]$MACAddress
    [string]$VLAN
    [string]$NetworkType  # e.g., "Management", "Production", "Storage"
    
    NetworkInterface() {}
    
    NetworkInterface([string]$name, [string]$ip, [string]$mac, [string]$vlan) {
        $this.InterfaceName = $name
        $this.IPAddress = $ip
        $this.MACAddress = $mac
        $this.VLAN = $vlan
    }
}

class PhysicalHost {
    [string]$HostName
    [string]$Platform  # "Proxmox", "VMware", "OpenStack", "Zen"
    [int]$PhysicalCores
    [int]$PhysicalSockets
    [string]$CPUModel
    [decimal]$TotalMemoryGB
    [string]$HypervisorVersion
    [System.Collections.Generic.List[string]]$HostedVMs
    
    PhysicalHost() {
        $this.HostedVMs = [System.Collections.Generic.List[string]]::new()
    }
}

class Asset {
    # Identity
    [string]$AssetID
    [string]$AssetName
    [string]$FQDN
    [string]$AssetType  # "VM", "PhysicalServer", "Container"
    
    # Platform Information
    [string]$Platform  # "Proxmox", "VMware", "OpenStack", "Zen"
    [string]$ClusterName
    [string]$DataCenter
    
    # Compute Resources
    [int]$vCPUs
    [decimal]$MemoryGB
    [decimal]$StorageGB
    [string]$PowerState  # "Running", "Stopped", "Suspended"
    
    # Host Relationship (Critical for licensing)
    [string]$PhysicalHostName
    [int]$PhysicalHostCores
    [int]$PhysicalHostSockets
    [string]$PhysicalHostCPUModel
    
    # Operating System (Critical for licensing compliance)
    [string]$OperatingSystem
    [string]$OSVersion
    [string]$OSEdition  # "Standard", "Enterprise", "Datacenter"
    [string]$OSLicenseType  # "BYOL", "SPLA", "Included"
    [bool]$RequiresLicensing
    
    # Network Configuration
    [System.Collections.Generic.List[NetworkInterface]]$NetworkInterfaces
    [string]$PrimaryIPAddress
    [string]$PrimaryVLAN
    [string]$AuthDomain  # One of five auth domains
    
    # Organizational
    [string]$Application
    [string]$OwningTeam
    [string]$Environment  # "Dev", "Staging", "Production"
    [string]$CostCenter
    [string]$BusinessUnit
    
    # Lifecycle
    [datetime]$CreatedDate
    [datetime]$LastModifiedDate
    [datetime]$LastInventoryDate
    [string]$LifecycleStatus  # "Active", "Decommissioned", "Maintenance"
    
    # Compliance & Tagging
    [hashtable]$Tags
    [hashtable]$CustomAttributes
    [string]$ComplianceStatus  # "Compliant", "Non-Compliant", "Review Required"
    [System.Collections.Generic.List[string]]$ComplianceNotes
    
    # JIRA Integration
    [string]$JiraAssetKey
    [datetime]$LastSyncToJira
    
    # Constructor
    Asset() {
        $this.NetworkInterfaces = [System.Collections.Generic.List[NetworkInterface]]::new()
        $this.Tags = @{}
        $this.CustomAttributes = @{}
        $this.ComplianceNotes = [System.Collections.Generic.List[string]]::new()
        $this.LastInventoryDate = Get-Date
    }
    
    # Method to add network interface
    [void]AddNetworkInterface([NetworkInterface]$nic) {
        $this.NetworkInterfaces.Add($nic)
        if ([string]::IsNullOrEmpty($this.PrimaryIPAddress)) {
            $this.PrimaryIPAddress = $nic.IPAddress
            $this.PrimaryVLAN = $nic.VLAN
        }
    }
    
    # Method to calculate licensing requirement based on physical cores
    [int]GetLicensingCoreCount() {
        if ($this.RequiresLicensing -and $this.PhysicalHostCores -gt 0) {
            return $this.PhysicalHostCores
        }
        return 0
    }
    
    # Method to validate required fields before JIRA upload
    [bool]IsValid() {
        $required = @(
            $this.AssetName,
            $this.Platform,
            $this.OperatingSystem,
            $this.OwningTeam,
            $this.Environment
        )
        
        foreach ($field in $required) {
            if ([string]::IsNullOrWhiteSpace($field)) {
                return $false
            }
        }
        return $true
    }
    
    # Method to convert to hashtable for JIRA Asset API
    [hashtable]ToJiraAssetHash() {
        $hash = @{
            'Name' = $this.AssetName
            'AssetType' = $this.AssetType
            'Platform' = $this.Platform
            'OperatingSystem' = $this.OperatingSystem
            'OSVersion' = $this.OSVersion
            'Environment' = $this.Environment
            'OwningTeam' = $this.OwningTeam
            'Application' = $this.Application
            'PhysicalHost' = $this.PhysicalHostName
            'PhysicalCores' = $this.PhysicalHostCores
            'vCPUs' = $this.vCPUs
            'MemoryGB' = $this.MemoryGB
            'PrimaryIP' = $this.PrimaryIPAddress
            'AuthDomain' = $this.AuthDomain
            'ComplianceStatus' = $this.ComplianceStatus
            'RequiresLicensing' = $this.RequiresLicensing
            'LastInventory' = $this.LastInventoryDate.ToString('yyyy-MM-dd HH:mm:ss')
        }
        
        # Add network interfaces as JSON string
        if ($this.NetworkInterfaces.Count -gt 0) {
            $hash['NetworkInterfaces'] = ($this.NetworkInterfaces | ConvertTo-Json -Compress)
        }
        
        # Add custom attributes
        foreach ($key in $this.CustomAttributes.Keys) {
            $hash[$key] = $this.CustomAttributes[$key]
        }
        
        return $hash
    }
    
    # Method to generate unique asset ID
    [void]GenerateAssetID() {
        $this.AssetID = "{0}_{1}_{2}" -f $this.Platform, $this.Environment, ($this.AssetName -replace '[^a-zA-Z0-9]', '_')
    }
    
    # Method to add compliance note
    [void]AddComplianceNote([string]$note) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $this.ComplianceNotes.Add("[$timestamp] $note")
    }
}

# Helper function to create asset from platform-specific data
function New-AssetFromPlatform {
    param(
        [Parameter(Mandatory)]
        [string]$Platform,
        
        [Parameter(Mandatory)]
        [hashtable]$PlatformData
    )
    
    $asset = [Asset]::new()
    $asset.Platform = $Platform
    $asset.LastInventoryDate = Get-Date
    
    # Map common fields (customize based on your platform data structure)
    if ($PlatformData.ContainsKey('Name')) { $asset.AssetName = $PlatformData.Name }
    if ($PlatformData.ContainsKey('OS')) { $asset.OperatingSystem = $PlatformData.OS }
    if ($PlatformData.ContainsKey('vCPU')) { $asset.vCPUs = $PlatformData.vCPU }
    if ($PlatformData.ContainsKey('Memory')) { $asset.MemoryGB = $PlatformData.Memory }
    
    $asset.GenerateAssetID()
    
    return $asset
}

# Example usage
<#
$asset = [Asset]::new()
$asset.AssetName = "web-server-01"
$asset.Platform = "VMware"
$asset.OperatingSystem = "Windows Server 2022"
$asset.OSEdition = "Datacenter"
$asset.RequiresLicensing = $true
$asset.Environment = "Production"
$asset.OwningTeam = "Infrastructure"
$asset.Application = "E-Commerce Platform"
$asset.PhysicalHostName = "esxi-host-05"
$asset.PhysicalHostCores = 48
$asset.AuthDomain = "CORP"

# Add network interface
$nic1 = [NetworkInterface]::new("eth0", "10.1.100.50", "00:50:56:XX:XX:XX", "100")
$asset.AddNetworkInterface($nic1)

$nic2 = [NetworkInterface]::new("eth1", "10.1.200.50", "00:50:56:XX:XX:YY", "200")
$asset.AddNetworkInterface($nic2)

# Generate ID and validate
$asset.GenerateAssetID()
Write-Host "Asset Valid: $($asset.IsValid())"
Write-Host "Licensing Cores: $($asset.GetLicensingCoreCount())"

# Convert to JIRA format
$jiraHash = $asset.ToJiraAssetHash()
$jiraHash | ConvertTo-Json
#>
