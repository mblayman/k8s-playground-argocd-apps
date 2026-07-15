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
mise run validate:istio-base
mise run validate:istiod
```

## Sync Wave Contract

Use sync waves as coarse platform dependency bands, not arbitrary ordering numbers. Keep future child `Application` manifests in this table unless there is a concrete reason to add a new band.

| Wave | Purpose |
| ---: | --- |
| `10` | Core platform controllers, such as cert-manager. |
| `20` | Configuration consumed by core controllers, such as cert-manager issuers and certificates. |
| `30` | Istio base APIs, CRDs, and validating webhook bootstrap. |
| `40` | Istio control plane runtime, currently `istiod` with revision `stable`. |
| `50` | Istio ingress gateway or other mesh data-plane gateway components. |
| `60` | Platform-owned mesh and ingress configuration, such as Gateway API resources and namespace-level mesh defaults. |
| `70` | Application workloads and services. |
| `80` | App-owned routes and mesh policies, such as `HTTPRoute`, `AuthorizationPolicy`, and `PeerAuthentication`. |
| `90` | Observability components and dashboards. |

Guardrails:

- Keep Istio validation fail-closed in steady state with `failurePolicy: Fail`.
- Do not create Istio custom resources before wave `40` has installed a healthy `istiod`.
- Put resources that depend on a CRD in a later wave than the CRD owner.
- Put resources that depend on an admission webhook in a later wave than the controller serving that webhook.
- Avoid inventing new sync wave numbers unless the dependency cannot fit an existing band.
