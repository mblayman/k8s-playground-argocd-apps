# k8s-playground-argocd-apps
Application configs for Argo CD for my k8s playground

## Structure

- `clusters/kind/application.yaml`: root Argo CD `Application` to apply manually after Argo CD is installed in the local kind cluster.
- `clusters/kind/apps/`: child Argo CD `Application` manifests rendered by the kind root app using Argo CD directory rendering.
- Moved platform/app desired state lives in `../k8s-playground-platform-config`; child apps here point at that repo.

Initial bootstrap flow:

```sh
kubectl --context kind-k8s-playground apply -f clusters/kind/application.yaml
```

Validate Helm-backed components:

```sh
mise run validate:cert-manager
mise run validate:argocd-repositories
mise run validate:minio
mise run validate:observability-object-storage-config
mise run validate:cert-manager-config
mise run validate:gateway-api-crds
mise run validate:gateway-api-config
mise run validate:k8s-playground-service
mise run validate:istio-base
mise run validate:istiod
mise run validate:istio-cni
mise run validate:istio-ingressgateway
```

## Sync Wave Contract

Use sync waves as coarse platform dependency bands, not arbitrary ordering numbers. Keep future child `Application` manifests in this table unless there is a concrete reason to add a new band.

| Wave | Purpose |
| ---: | --- |
| `0` | Cluster API extensions and CRDs not owned by an in-cluster controller app, such as Gateway API CRDs. |
| `5` | Argo CD repository/config prerequisites needed before Helm-backed wrapper apps, such as public Helm repository Secrets. |
| `10` | Core platform foundations that do not depend on Istio, such as cert-manager and kind-local object storage with MinIO. |
| `20` | Configuration consumed by core foundations, such as cert-manager issuers/certificates and MinIO buckets or backend object-storage credentials. |
| `25` | Core observability metrics storage that should exist before workloads, starting with Mimir. |
| `30` | Istio base APIs, CRDs, and validating webhook bootstrap. |
| `35` | Core observability collection, UI, and datasource wiring, especially Alloy Kubernetes/node metrics collection and Grafana backed by Mimir. |
| `40` | Istio control plane runtime, currently `istiod` with revision `stable`. |
| `45` | Istio CNI node agent, installed after `istiod` and before meshed workloads. |
| `50` | Istio ingress gateway or other mesh data-plane gateway components. |
| `55` | Additional telemetry layers that should be available before app workloads where practical, such as Loki log collection, Pyroscope, Tempo, and Beyla. |
| `60` | Platform-owned mesh, ingress, and telemetry integration configuration, such as `GatewayClass`, shared `Gateway`, namespace-level mesh defaults, and Istio-to-collector settings. |
| `70` | Application components, including workloads, services, and app-owned routes when internal resource ordering is sufficient. |
| `80` | Dashboards, alerting configuration, and other late visualization or operations resources that can reference app-specific signals. |

Guardrails:

- Keep Istio validation fail-closed in steady state with `failurePolicy: Fail`.
- Do not create Istio custom resources before wave `40` has installed a healthy `istiod`.
- Put resources that depend on a CRD in a later wave than the CRD owner.
- Put resources that depend on an admission webhook in a later wave than the controller serving that webhook.
- Treat non-Git Secrets required before a Helm app starts as bootstrap inputs, not ordinary later-wave configuration. For example, a MinIO `existingSecret` must be created by local bootstrap before the MinIO app syncs.
- Keep foundational observability before application wave `70` so metrics/log collectors are already online when workloads start during a scratch rebuild.
- Keep app-specific dashboards and alert rules after application wave `70` when they depend on labels, routes, or service names from app components.
- Prefer resource-level sync waves inside an app component before splitting app-owned resources into separate child apps.
- Avoid inventing new sync wave numbers unless the dependency cannot fit an existing band.
