# k8s-playground-argocd-apps
Application configs for Argo CD for my k8s playground

## Structure

- `clusters/kind/application.yaml`: root Argo CD `Application` to apply manually after Argo CD is installed in the local kind cluster.
- `clusters/kind/apps/`: child Argo CD `Application` manifests rendered by the kind root app using Argo CD directory rendering.
- `components/apps/`: local application component configuration and manifests managed by child apps.
- `components/platform/`: local platform component configuration for cluster services such as cert-manager and Istio.

Initial bootstrap flow:

```sh
kubectl --context kind-k8s-playground apply -f clusters/kind/application.yaml
```

Validate Helm-backed components:

```sh
mise run validate:cert-manager
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
| `10` | Core platform controllers, such as cert-manager. |
| `20` | Configuration consumed by core controllers, such as cert-manager issuers and certificates. |
| `30` | Istio base APIs, CRDs, and validating webhook bootstrap. |
| `40` | Istio control plane runtime, currently `istiod` with revision `stable`. |
| `45` | Istio CNI node agent, installed after `istiod` and before meshed workloads. |
| `50` | Istio ingress gateway or other mesh data-plane gateway components. |
| `60` | Platform-owned mesh and ingress configuration, such as `GatewayClass`, shared `Gateway`, and namespace-level mesh defaults. |
| `70` | Application components, including workloads, services, and app-owned routes when internal resource ordering is sufficient. |
| `80` | Observability components, dashboards, and late visualization resources. |

Guardrails:

- Keep Istio validation fail-closed in steady state with `failurePolicy: Fail`.
- Do not create Istio custom resources before wave `40` has installed a healthy `istiod`.
- Put resources that depend on a CRD in a later wave than the CRD owner.
- Put resources that depend on an admission webhook in a later wave than the controller serving that webhook.
- Prefer resource-level sync waves inside an app component before splitting app-owned resources into separate child apps.
- Avoid inventing new sync wave numbers unless the dependency cannot fit an existing band.
