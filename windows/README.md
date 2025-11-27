# kubeadm-clusters

A project to spin up virtual machines on Hyper-V and setup local Kubernetes clusters with 1 master node and 2 worker nodes on a Windows machine.

## Overview

This repository provides automation scripts and configuration files to quickly provision a local Kubernetes cluster using Hyper-V on Windows.

**Cluster Configuration:**
- 1 Master (Control Plane) Node
- 2 Worker Nodes

## Prerequisites

- Windows 10/11 Pro or Enterprise (with Hyper-V support enabled)
- Hyper-V Manager installed and running
- PowerShell 5.0 or higher
- Sufficient system resources (minimum 8GB RAM recommended)

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/nvharish/kubeadm-clusters.git
   cd kubeadm-clusters
   ```

2. Configure your cluster parameters in the configuration file

3. Create virtual machines on Hyper-V script:
   ```powershell
   .\windows\create-vms.ps1
   ```

4. Wait for the VMs to be provisioned.

5. Setup networking on each virtual machine:
   Use NetPlan for network configuration. Copy the following yaml to /etc/netplan/01-netcfg.yaml
   ```yaml
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

   # Suggested IPs:
     # kube-master  -> 192.168.0.2
     # kube-worker1 -> 192.168.0.3
     # kube-worker2 -> 192.168.0.4
   ```

  6. Use the following command to apply netplan changes on each VM:
     ```bash
     sudo netplan apply
     ```

  7. Install ssh on each virtual machines to accept ssh connections:
     ```bash
     sudo apt-get update
     sudo apt-get install openssh-server
     ```

  8. Use SSH to connect to each VM from the host:
     ```bash
     ssh ubuntu@<VM-IP-ADDRESS>
     ```

  9. Check connectivity from host to VMs:
     ```bash
     ping <VM-IP-ADDRESS>
     # e.g. ping 192.168.0.3
     ```

  10. Check internet connectivity from each VM:
      ```bash
      ping google.com
      ```

  11. If all networking is good, proceed to install container runtime (eg. containerd),
      kubeadm, kubelet, kubectl inside each VM, then initialize/join the cluster. Follow
      the official kubeadm documentation for multi-node cluster setup using kubeadm.
      https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

## Features

- Automated VM provisioning on Hyper-V
- Kubernetes cluster initialization with kubeadm
- Network configuration for inter-node communication
- Storage and DNS setup

## System Requirements

- **CPU:** 4+ cores
- **RAM:** 8GB minimum (16GB+ recommended)
- **Storage:** 30GB free disk space

## Contributing

See [CODE_OF_CONDUCT.md](https://github.com/nvharish/kubeadm-clusters/.github/CODE_OF_CONDUCT.md).

## License

MIT © [N V Harish](https://github.com/nvharish/kubeadm-clusters/LICENSE)
