# k8s-playground-argocd-apps
Application configs for Argo CD for my k8s playground

## Structure

- `clusters/kind/shared.yaml`: shared/substrate root for Argo configuration, cert-manager, MinIO, Gateway API CRDs, and object-storage provisioning.
- `clusters/kind/application.yaml`: application-cluster root for Istio, gateways, Alloy, and application workloads.
- `clusters/kind/observability.yaml`: observability root for central backends and UI workloads.
- `clusters/kind/apps/`: shared/substrate child Applications and the restricted `observability` AppProject.
- `clusters/kind/application/apps/`: application-cluster child Applications.
- `clusters/kind/observability/apps/`: observability child Applications.
- Kubernetes desired state lives in `../k8s-playground-platform-config`; child apps here only point at that repo.

Initial bootstrap flow:

```sh
kubectl --context kind-k8s-playground apply -f clusters/kind/shared.yaml
kubectl --context kind-k8s-playground apply -f clusters/kind/observability.yaml
kubectl --context kind-k8s-playground apply -f clusters/kind/application.yaml
```

Validate Helm-backed components:

```sh
mise run validate:kind-roots
mise run validate:cert-manager
mise run validate:argocd-repositories
mise run validate:argocd-config
mise run validate:minio
mise run validate:observability-object-storage-config
mise run validate:mimir
mise run validate:tempo
mise run validate:loki
mise run validate:alloy
mise run validate:grafana
mise run validate:cert-manager-config
mise run validate:gateway-api-crds
mise run validate:gateway-api-config
mise run validate:management-gateway-config
mise run validate:k8s-playground-service
mise run validate:istio-base
mise run validate:istiod
mise run validate:istio-cni
mise run validate:istio-ingressgateway
mise run validate:istio-managementgateway
```

## Sync Wave Contract

Use sync waves as coarse creation-order bands inside each independently reconciled root, not as cross-Application readiness orchestration. Keep future child `Application` manifests in this table unless there is a concrete reason to add a new band.

| Wave | Purpose |
| ---: | --- |
| `0` | Cluster API extensions and CRDs not owned by an in-cluster controller app, such as Gateway API CRDs. |
| `5` | Argo CD repository/config prerequisites needed before Helm-backed wrapper apps, such as public Helm repository Secrets. |
| `10` | Core platform foundations that do not depend on Istio, such as cert-manager and kind-local object storage with MinIO. |
| `20` | Configuration consumed by core foundations, such as cert-manager issuers/certificates and MinIO buckets or backend object-storage credentials. |
| `25` | Core observability backend storage that should exist before workloads, including Mimir and Tempo. |
| `30` | Platform API foundations, currently Istio base APIs. |
| `35` | Management and observability UI runtime configuration, including Argo CD server settings and Grafana backed by Mimir. |
| `40` | Istio control plane runtime, currently `istiod` with revision `stable`. |
| `45` | Istio CNI node agent, installed after `istiod` and before meshed workloads. |
| `50` | Istio user and management ingress gateway data-plane components. |
| `55` | Workload-adjacent telemetry collectors that should converge after Istio CNI, including Alloy and future Beyla collection. |
| `60` | Platform-owned mesh, ingress, and telemetry integration configuration, including user and management Gateways, certificates, routes, namespace-level mesh defaults, and Istio-to-collector settings. |
| `70` | Application components, including workloads, services, and app-owned routes when internal resource ordering is sufficient. |
| `80` | Dashboards, alerting configuration, and other late visualization or operations resources that can reference app-specific signals. |

Guardrails:

- Keep Istio validation fail-closed in steady state with `failurePolicy: Fail`.
- Treat child Application waves as creation order only; each child reconciles and reports sync/health independently.
- Keep hard resource dependencies inside one Application when resource-level health-gated waves are required.
- Use lower child waves for CRD owners and admission controllers, then rely on Argo's bounded default sync retries and idempotent reconciliation for consumers.
- Treat non-Git Secrets required before a Helm app starts as bootstrap inputs, not ordinary later-wave configuration. For example, a MinIO `existingSecret` must be created by local bootstrap before the MinIO app syncs.
- Keep application and observability roots independent; application availability must not depend on observability health.
- Keep app-specific dashboards and alert rules after application wave `70` when they depend on labels, routes, or service names from app components.
- Prefer resource-level sync waves inside an app component before splitting app-owned resources into separate child apps.
- Avoid inventing new sync wave numbers unless the dependency cannot fit an existing band.
