<#
. SYNOPSIS
  Create Hyper-V VMs (Ubuntu) for a kubeadm multi-node lab on Windows 11.

. NOTES
  - Run PowerShell as Administrator.
  - Tested workflow on Windows 11 Pro (Hyper-V available).
  - After Ubuntu install inside each VM, you'll need to set static IPs/netplan,
    install container runtime, kubeadm/kubelet/kubectl, then kubeadm init and join.
#>

# ---------------------------
# Safety / admin check
# ---------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator (elevated PowerShell). Exiting."
    exit 1
}

# ---------------------------
# User-editable variables
# ---------------------------
$vmBasePath    = "$env:PROGRAMDATA\Microsoft\Windows\Virtual Hard Disks"                    # where VHDs will be stored
$isoPath       = "$env:USERPROFILE\Downloads\ubuntu-22.04.5-live-server-amd64.iso"
$isoUrl        = "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
$vSwitchName   = "KubeSwitch"
$natNetwork    = "KubeNATNetwork"
$vmNames       = @("kube-master","kube-worker1","kube-worker2")
$memoryPerVM   = 2GB
$cpuCount      = 2
$vhdSize       = 30GB
$generation    = 1    # use Generation 1 VMs
$vmNetworkName = $vSwitchName
$vSwitchIPAddr = "192.168.0.1"   # for static IPs inside VMs (eg. .2, .3, .4)
$intIPPrefix  = "192.168.0.0/24"

# ---------------------------
# Enable Hyper-V (one-time)
# ---------------------------
Write-Host "`n==> Enabling Hyper-V feature (may require reboot)..." -ForegroundColor Cyan
$hvFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
if ($hvFeature.State -ne "Enabled") {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    Write-Host "Hyper-V feature enabled. You should restart the machine if required." -ForegroundColor Yellow
} else {
    Write-Host "Hyper-V already enabled." -ForegroundColor Green
}

# ---------------------------
# Create base folders
# ---------------------------
if (-not (Test-Path -Path $vmBasePath)) {
    New-Item -ItemType Directory -Path $vmBasePath -Force | Out-Null
    Write-Host "Created $vmBasePath"
}

# ---------------------------
# Create internal virtual switch and configure NAT
# ---------------------------
Write-Host "`n==> Creating/ensuring virtual switch '$vSwitchName'..." -ForegroundColor Cyan
$existingSwitch = Get-VMSwitch -Name $vSwitchName -ErrorAction SilentlyContinue
if ($existingSwitch) {
    Write-Host "Virtual switch '$vSwitchName' already exists." -ForegroundColor Green
} else {
    # Create a new internal vSwitch
    $switch = New-VMSwitch -SwitchName "$vSwitchName" -SwitchType Internal

    # Get the interface index of the virtual switch
    $ifIndex = (Get-NetAdapter -Name "vEthernet ($vSwitchName)").ifIndex

    if ($ifIndex) {
        Write-Host "Switch Name : $($switch.Name)"
        Write-Host "Interface Index (ifIndex): $($ifIndex)"

        # Create the NAT Gateway
        $netIPAddress = Get-NetIPAddress -IPAddress $vSwitchIPAddr -ErrorAction SilentlyContinue
        if (-not $netIPAddress) {
            New-NetIPAddress -IPAddress $vSwitchIPAddr -PrefixLength 24 -InterfaceIndex $ifIndex
            Write-Host "Assigned IP Address $vSwitchIPAddr to interface index $ifIndex" -ForegroundColor Green

            # Configure the NAT network
            New-NetNat -Name $natNetwork -InternalIPInterfaceAddressPrefix $intIPPrefix
            Write-Host "Created NAT network '$natNetwork'" -ForegroundColor Green
        } else {
            Write-Host "IP Address $vSwitchIPAddr already assigned to interface index $($netIPAddress.InterfaceIndex). Please use different IPv4 cidr." -ForegroundColor Green
            Remove-VMSwitch -SwitchName "$vSwitchName"
            Remove-NetAdapter -Name "vEthernet ($vSwitchName)"
            exit 1
        }
    } else {
        Write-Host "No matching network adapter found for switch $($switch.Name)"
    }
}

# ---------------------------
# Download Ubuntu ISO if missing
# ---------------------------
if (-not (Test-Path -Path $isoPath)) {
    Write-Host "`n==> Downloading Ubuntu ISO to $isoPath ..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $isoUrl -OutFile $isoPath -UseBasicParsing -Verbose:$false
        Write-Host "Downloaded ISO." -ForegroundColor Green
    } catch {
        Write-Error "Failed to download ISO. $_"
        exit 1
    }
} else {
    Write-Host "ISO already exists at $isoPath" -ForegroundColor Green
}

# ---------------------------
# Create VMs
# ---------------------------
Write-Host "`n==> Creating VMs..." -ForegroundColor Cyan
foreach ($vmName in $vmNames) {
    $vhdPath = Join-Path $vmBasePath "$vmName.vhdx"

    # If VM exists, skip
    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Write-Host "VM '$vmName' already exists - skipping creation." -ForegroundColor Yellow
        continue
    }

    # Create New-VM with new VHD
    Write-Host "Creating VM: $vmName (Memory: $memoryPerVM, CPU: $cpuCount, VHD: $vhdPath, Size: $vhdSize)" -ForegroundColor White
    New-VM -Name $vmName -MemoryStartupBytes $memoryPerVM -Generation $generation `
           -NewVHDPath $vhdPath -NewVHDSizeBytes $vhdSize -SwitchName $vmNetworkName | Out-Null

    # Set CPU count
    Set-VMProcessor -VMName $vmName -Count $cpuCount

    # Disable Secure Boot (Linux)
    try {
        Set-VMFirmware -VMName $vmName -EnableSecureBoot Off
    } catch {
        Write-Warning "Could not set firmware SecureBoot property for $vmName. You may need to disable Secure Boot manually."
    }

    # Attach ISO to DVD drive
    try {
        Set-VMDvdDrive -VMName $vmName -Path $isoPath
    } catch {
        Write-Warning "Failed to attach ISO to $vmName. You can attach manually in Hyper-V Manager."
    }

    # Ensure VM is using dynamic RAM disabled (optional)
    Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $false -StartupBytes $memoryPerVM

    Write-Host "VM $vmName created." -ForegroundColor Green
}

# ---------------------------
# Start VMs
# ---------------------------
Write-Host "`n==> Starting VMs..." -ForegroundColor Cyan
foreach ($vmName in $vmNames) {
    Start-VM -Name $vmName -ErrorAction SilentlyContinue
    Write-Host "Started $vmName. Use vmconnect.exe localhost `"$vmName`" to open console." -ForegroundColor Green
}

# ---------------------------
# Final notes / next steps
# ---------------------------
Write-Host "`n==> Finished Hyper-V VM creation." -ForegroundColor Cyan
Write-Host "Next steps (manual inside each VM):" -ForegroundColor Yellow
Write-Host @"
1. Open each VM console:
   vmconnect.exe localhost "<VM-NAME>"
   (or use Hyper-V Manager)

2. Install Ubuntu Server (use the ISO attached). Recommended: Ubuntu 22.04 LTS.
   - During installation: create a user (eg. ubuntu), enable OpenSSH.
   - After installation, remove the ISO from DVD and reboot.

3. Recommended VM networking: assign static IPs using netplan.
   Example netplan (/etc/netplan/01-netcfg.yaml):
   network:
     version: 2
     renderer: networkd
     ethernets:
       eth0:
         addresses:
          - 192.168.0.2/24    # change per VM
         routes:
          - to: default
            via: 192.168.0.1
         nameservers:
          addresses:
            - 8.8.8.8
            - 8.8.4.4

   Suggested IPs:
     kube-master  -> 192.168.0.2
     kube-worker1 -> 192.168.0.3
     kube-worker2 -> 192.168.0.4

4. Use the following command to apply netplan changes on each VM:
   sudo netplan apply

5. Use SSH to connect to each VM from the host:
   ssh ubuntu@<VM-IP-ADDRESS>

6. Check connectivity from host to VMs:
   ping <VM-IP-ADDRESS>

7. Check connectivity between VMs:
   From one VM, ping the others using their static IPs.
   e.g., from kube-master:
   ping 192.168.0.3

8. Check internet connectivity from each VM:
   ping google.com

9. If all networking is good, proceed to install container runtime (eg. containerd),
   kubeadm, kubelet, kubectl inside each VM, then initialize/join the cluster. Follow
   the official kubeadm documentation for multi-node cluster setup using kubeadm.
   https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

"@ -ForegroundColor White

Write-Host "`nHelpful: To copy VM (clone) after you fully configure a master image, you can shutdown the master and copy its VHDX file to create worker images (use Copy-Item), then create new VMs that point to the copied VHDX." -ForegroundColor Magenta
Write-Host "`nScript complete. Good luck!`n" -ForegroundColor Green
