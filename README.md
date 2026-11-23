
# Azure VNet Peering & Network Watcher Lab (Terraform)

Infrastructure-as-Code (IaC) lab provisioning two peered Azure Virtual Networks with private-only Linux VMs, strict Network Security Group (NSG) segmentation using a deny-by-default model, and end-to-end connectivity diagnostics via Azure Network Watcher.

---

## Architecture Overview

```text
+-----------------------------------+          +-----------------------------------+
|         vnet-first (10.10.0.0/16) |          |        vnet-second (10.20.0.0/16) |
|                                   |          |                                   |
|  +-----------------------------+  |          |  +-----------------------------+  |
|  | SubnetForFirstVnet          |  |  VNet    |  | SubnetForSecondVnet         |  |
|  | 10.10.1.0/26                |  | Peering  |  | 10.20.1.0/26                |  |
|  |                             |  |<-------->|  |                             |  |
|  | [first-vnet-nsg]            |  | (Bi-dir) |  | [second-vnet-nsg]           |  |
|  |  - vm-first-vnet (Private)  |  |          |  |  - vm-second-vnet (Private) |  |
|  |  - NetworkWatcherAgentLinux |  |          |  |  - NetworkWatcherAgentLinux |  |
|  +-----------------------------+  |          |  +-----------------------------+  |
+-----------------------------------+          +-----------------------------------+
                                         |
                                         v
                       +-----------------------------------+
                       | Azure Network Watcher (westeurope)|
                       |  - Connection Monitor (TCP 8080)  |
                       |  - IP Flow Verify & Troubleshoot  |
                       +-----------------------------------+
```

### Key Design Decisions

* **Private-Only Compute:** Neither VM has a public IP address (`public_ip_address_id` omitted). All administrative verification uses Azure Run Command (`az vm run-command invoke`) or a dedicated management CIDR.
* **Bidirectional VNet Peering:** Explicit `first-vnet-to-second-vnet` and `second-vnet-to-first-vnet` peering resources with `allow_virtual_network_access = true`.
* **Policy-Compliant Region Routing:** Resources deploy into `westeurope` (`var.location`) inside the existing resource group (`rg-andrei`) to comply with subscription `Policy_allowed_locations` constraints.
* **DRY Resource Provisioning:** NSGs, subnet associations, NICs, VMs, and Network Watcher VM extensions use Terraform `for_each` maps rather than duplicated resource blocks or fragile `count` indexes.

---

## Project Structure

```text
azure-vnet-peering-lab/
├── main.tf          # Data source referencing the existing Azure Resource Group
├── providers.tf     # Terraform & HashiCorp azurerm/random provider version constraints
├── variables.tf     # Input variables (RG name, allowed region, admin CIDR, SSH key)
├── networks.tf      # Virtual Networks (10.10.0.0/16 and 10.20.0.0/16)
├── subnets.tf       # Workload subnets (10.10.1.0/26 and 10.20.1.0/26)
├── peering.tf       # Bidirectional VNet peering configurations
├── nsgs.tf          # NSGs, management/app/deny-by-default rules, subnet associations
├── compute.tf       # Private NICs, Ubuntu 22.04 VMs, and NetworkWatcherAgentLinux extensions
├── diagnostics.tf   # Network Watcher data source, Connection Monitor, and CLI check outputs
├── outputs.tf       # Exported VM private IPs and resource IDs
└── README.md        # Project documentation and verification runbook
```

---

## NSG Security Matrix & Deny-by-Default Reasoning

Each workload subnet is protected by a dedicated NSG (`first-vnet-nsg` and `second-vnet-nsg`) enforcing the following inbound rules:

| Priority       | Rule Name                  | Traffic Category | Source                                       | Destination           | Port / Protocol | Action          | Purpose                                                                  |
| :------------- | :------------------------- | :--------------- | :------------------------------------------- | :-------------------- | :-------------- | :-------------- | :----------------------------------------------------------------------- |
| **100**  | `AllowSSHManagement`     | Management       | `var.admin_source_cidr` (`10.10.2.0/26`) | Local workload subnet | `TCP / 22`    | **Allow** | Restricts SSH access strictly to a trusted management/Bastion subnet     |
| **200**  | `AllowAppFromPeerSubnet` | Application      | Peer workload subnet                         | Local workload subnet | `TCP / 8080`  | **Allow** | Permits explicit application traffic across the VNet peering link        |
| **4096** | `DenyAllInbound`         | Deny-by-default  | `*`                                        | `*`                 | `* / Any`     | **Deny**  | Drops all unapproved inbound traffic, including default cross-VNet flows |

### Why Priority `4096` (`DenyAllInbound`) Is Required

By default, Azure injects a built-in system rule named **`AllowVnetInBound`** at priority **`65000`** on every NSG. Because Azure defines the `VirtualNetwork` service tag to include **all connected peered VNets**, VNet peering automatically permits unrestricted traffic on every port between `10.10.0.0/16` and `10.20.0.0/16` unless overridden.

Placing `DenyAllInbound` at priority **`4096`** (the lowest priority available for custom rules) overrides `AllowVnetInBound` (`65000`) and establishes a true **deny-by-default** posture—ensuring only explicitly approved management (`22`) and application (`8080`) flows can traverse the peering link.

---

## Prerequisites

* [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.5.0`
* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) authenticated (`az login`)
* `jq` installed locally (for parsing JSON outputs in verification commands)
* An existing Azure Resource Group (default: `rg-andrei`) and an SSH public key (`~/.ssh/id_rsa.pub`)
* Regional Network Watcher enabled in `westeurope` (`NetworkWatcher_westeurope` in `NetworkWatcherRG`)

---

## Deployment

1. **Initialize and validate the configuration:**

   ```bash
   terraform init
   terraform fmt -check -recursive
   terraform validate
   ```
2. **Preview and apply the infrastructure:**

   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
3. **Inspect deployed outputs:**

   ```bash
   terraform output
   ```

---

## Private Connectivity & Network Watcher Verification

### 1. NSG Policy Evaluation (`IP Flow Verify`)

Verify at the control-plane level that `second-vnet-nsg` permits TCP `8080` from `vm-first-vnet` and blocks unapproved ports such as TCP `80`:

```bash
VM1_IP=$(terraform output -json vm_private_ips | jq -r .first)
VM2_IP=$(terraform output -json vm_private_ips | jq -r .second)

# Expected: Access: Allow | RuleName: AllowAppFromPeerSubnet
az network watcher test-ip-flow \
  --resource-group rg-andrei \
  --vm vm-second-vnet \
  --direction Inbound \
  --protocol TCP \
  --local "${VM2_IP}:8080" \
  --remote "${VM1_IP}:50000"

# Expected: Access: Deny | RuleName: DenyAllInbound
az network watcher test-ip-flow \
  --resource-group rg-andrei \
  --vm vm-second-vnet \
  --direction Inbound \
  --protocol TCP \
  --local "${VM2_IP}:80" \
  --remote "${VM1_IP}:50000"
```

### 2. End-to-End Path Diagnostics (`Connection Troubleshoot`)

Start a lightweight HTTP listener on port `8080` inside `vm-second-vnet` using Azure Run Command, then verify live reachability from `vm-first-vnet`:

```bash
# Start listener on VM2 (no public IP required)
az vm run-command invoke \
  --resource-group rg-andrei \
  --name vm-second-vnet \
  --command-id RunShellScript \
  --scripts "nohup python3 -m http.server 8080 >/tmp/http.log 2>&1 &"

# Expected: ConnectionStatus: Reachable (NSG priority 200)
az network watcher test-connectivity \
  --resource-group rg-andrei \
  --source-resource vm-first-vnet \
  --dest-resource vm-second-vnet \
  --dest-port 8080 \
  --protocol Tcp

# Expected: ConnectionStatus: Unreachable (blocked by NSG priority 4096)
az network watcher test-connectivity \
  --resource-group rg-andrei \
  --source-resource vm-first-vnet \
  --dest-resource vm-second-vnet \
  --dest-port 80 \
  --protocol Tcp
```

### 3. Direct Private HTTP Request

Confirm application-layer traffic succeeds across the peering link over private IP space:

```bash
# Expected: HTTP/1.0 200 OK
az vm run-command invoke \
  --resource-group rg-andrei \
  --name vm-first-vnet \
  --command-id RunShellScript \
  --scripts "curl -sI --max-time 5 http://${VM2_IP}:8080 | head -n 1"
```

### 4. Continuous Monitoring (`Connection Monitor`)

Terraform also provisions `cm-vnet-peering-check` inside `NetworkWatcher_westeurope`, which probes `vm-first-vnet -> vm-second-vnet` every 60 seconds on both TCP `8080` (expected pass) and TCP `80` (expected fail) to continuously validate peering health and NSG enforcement.

---

## Cleanup

Destroy all lab resources when finished to avoid ongoing VM and Connection Monitor charges:

```bash
terraform destroy
```
