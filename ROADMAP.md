### Technical Roadmap

#### Axis 1: Base OS Immutable Core
* **Objective:** Achieve a "Zero-Ansible" post-boot configuration state for all nodes.
* **Actions:**
    * Migrate base service configurations (networking, `systemd`) from Ansible to **Ignition**.
    * Create a custom, re-compiled Fedora CoreOS base image to "bake-in" static packages (e.g., Vault agent, base binaries).
    * Ansible's (or the Vault agent's) role will be restricted to fetching dynamic secrets/configs (certificates, etc.) from the "core" Vault instance.

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

#### Axis 4: OpenStack Control Plane Refactor (Core Project)
* **Objective:** Replace the current `openstack-helm` implementation with a modern, "Kube-native," multi-tenant control plane.
* **Actions:**
    * **Integrate `k-orc`** (Kube-OpenStack-Resource-Controller) as the central orchestration component.
        * *Note: Requires upstream contribution (project is new, scope must be extended).*
    * **Secret Management Security:** Complete replacement of clear-text secrets (from `openstack-helm`) with secure injection via the **Vault Secrets Operator (VSO)**.
    * **Develop a custom Controller / OpenStack Module** (TBD) for "sub-cluster" (cluster-as-a-service) management.
    * **Target Sub-Cluster Architecture:**
        * The tenant cluster `dataplane` will be isolated in dedicated **client namespaces** on the main control plane.
        * The tenant cluster `control plane` will be deployed (by the custom controller) onto OpenStack resources (VMs).
        * The custom controller will leverage `k-orc` to orchestrate the creation of OpenStack resources required for these sub-clusters (workers, networks).

#### Axis 5: Platform Layer & Commercialization
* **Objective:** Expose services as "turnkey" products and manage commercial licensing.
* **Actions:**
    * **License Management (Core):**
        * Implement a custom Kubernetes **Admission Controller**.
        * This controller will validate actions (e.g., "create new cluster") by querying **Vault** for license validity.
    * **Application Platform (PaaS):**
        * Develop a service layer (potentially via a UI) for rapid application deployment ("software factory," CNaaS).
        * The backend for this UI will leverage pre-packaged **Terraform** modules to provision and connect services (clusters, DBs, etc.).
        * This layer will integrate license pre-selection (see previous point) for service deployment.