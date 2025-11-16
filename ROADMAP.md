### Technical Roadmap

#### Axis 1: Base OS Immutable Core
* **Objective:** Achieve a "Zero-Ansible" post-boot configuration state for all nodes.
* **Actions:**
    * Migrate base service configurations (networking, `systemd`) from Ansible to **Ignition**.
    * Create a custom, re-compiled Fedora CoreOS base image to "bake-in" static packages (e.g., Vault agent, base binaries).
    * Ansible's (or the Vault agent's) role will be restricted to fetching dynamic secrets/configs (certificates, etc.) from the "core" Vault instance.
    * **[NEW] Implement full SELinux configuration:** Plan the transition from the current "permissive" mode (prioritizing functionality) to "enforcing" by defining and applying all necessary system policies.

#### Axis 2: System Runtime Unification
* **Objective:** Standardize the management of all host-level containerized services.
* **Actions:**
    * Migrate system services (e.g., `haproxy`, `keepalived`, `vault-agent`) currently managed by Podman + `systemd`.
    * Target: Utilize the **Kubelet in "standalone" mode** to manage these services as "Static Pods".
    * Benefit: A single container manager (Kubelet) on the host.

#### Axis 3: Storage Infrastructure
* **Objective:** Provide a unified, resilient, persistent storage solution for the control plane and tenants.
* **Actions:**
    * Integrate **Ceph** using the **Rook** operator.
    * Scope: Manage data for the pilot cluster (etcd, Kube services) AND provide storage for tenant sub-clusters (Cinder volumes, Swift objects, etc.).

#### Axis 4: OpenStack Deployment & Orchestration
* **Objective:** Deploy OpenStack natively via Terraform for custom integration, and use `k-orc` for tenant resource orchestration.
* **Actions:**
    * **Native Terraform Deployment:**
        * Re-implement the OpenStack deployment (currently based on `openstack-helm`) **natively in Terraform**.
        * This custom implementation is critical for deep integration with **Vault** (for secrets) and the **immutable OS** (for virtualization components). The Helm charts serve only as a functional baseline to be corrected and replaced.
    * **Secret Management Security:** During the Terraform re-implementation, completely replace all clear-text secrets with secure injection via the **Vault Secrets Operator (VSO)**.
    * **Tenant Resource Orchestration:**
        * Integrate **`k-orc`** (Kube-OpenStack-Resource-Controller) as the "driver" for orchestrating tenant *requests* (e.g., "create VM", "create storage") against the OpenStack platform. `k-orc` does **not** deploy OpenStack itself.
        * *Note: Requires upstream contribution to `k-orc` (project is new, scope must be extended).*
    * **"Cluster-as-a-Service" Controller:**
        * Develop a **custom Kubernetes controller** for managing tenant "sub-clusters".
        * This controller will orchestrate the `control plane` of tenant clusters (as VMs on OpenStack) and their `dataplane` (isolated in namespaces on the main pilot cluster).
        * This custom controller will **use `k-orc`** as its interface to request the necessary OpenStack resources (VMs, networks) for the tenant clusters.

#### Axis 5: Cluster Security Hardening
* **Objective:** Implement a "Zero Trust" security posture at the cluster and network level.
* **Actions:**
    * ** Implement Cilium Network Policies:** Move beyond basic CNI connectivity and define a comprehensive set of network policies to strictly control pod-to-pod communication (firewalling).
    * ** Eliminate Privileged Pods:** Audit all deployed components (especially OpenStack compute nodes) and refactor them to run without `privileged: true` security contexts, replacing them with granular capabilities and security contexts.

#### Axis 6: Platform Layer & Commercialization
* **Objective:** Expose services as "turnkey" products and manage commercial licensing.
* **Actions:**
    * **License Management (Core):**
        * Implement a custom Kubernetes **Admission Controller**.
        * This controller will validate actions (e.g., "create new cluster") by querying **Vault** for license validity.
    * **Application Platform (PaaS):**
        * Develop a service layer (potentially via a UI) for rapid application deployment ("software factory," CNaaS).
        * The backend for this UI will leverage pre-packaged **Terraform** modules to provision and connect services (clusters, DBs, etc.).
        * This layer will integrate license pre-selection for service deployment.
    * **Prepare for AI/GPU Integration:**
        * Architect a "placeholder" within the platform to integrate GPU hardware support (e.g., NVIDIA device plugins for Kubernetes).
        * **Target AI Platform:** The goal is to enable an SME-focused (PME) platform for:
            * Partial/Custom model training (fine-tuning).
            * Multi-GPU inference, fully orchestrated by Kubernetes.