# Agent Notes

## Argo Application Wiring

This repo owns Argo CD `Application` wiring, not the Kubernetes desired state for moved platform/app components.

For components moved to `k8s-playground-platform-config`, keep `Application` resources as single-source pointers to that repo and path. Do not put the component manifests or Helm values back under `components/` here.

For wrapper-chart Helm components, the upstream chart repo, chart name, chart version, values, and `Chart.lock` live in `k8s-playground-platform-config`. The `Application` here should only point at the wrapper chart path and preserve the Helm release name.

Current wrapper-chart applications:

- `cert-manager` -> `platform/cert-manager`
- `istio-base` -> `platform/istio/base`
- `istiod` -> `platform/istio/istiod`
- `istio-cni` -> `platform/istio/cni`
- `istio-ingressgateway` -> `platform/istio/ingressgateway`

Use this source shape for wrapper-chart apps:

```yaml
source:
  repoURL: https://github.com/mblayman/k8s-playground-platform-config.git
  targetRevision: main
  path: platform/example
  helm:
    releaseName: example
```

Keep `helm.releaseName` explicit. It preserves rendered resource names across migrations and avoids accidental delete/recreate behavior caused by release name drift.

Do not reintroduce multi-source `$values` wiring for these wrapper-chart apps. That split made chart ownership unclear. The wrapper chart exists so `platform-config` owns the chart dependency and values together.

## Validation

Run `mise run validate:all` from this repo after editing `Application` wiring.

The validation tasks check that moved components point at `k8s-playground-platform-config` and render the referenced sibling path from `../k8s-playground-platform-config`.

When changing a live app source repo/path, sync the root app first if the child spec is stale, then sync the child app. From `k8s-playground-platform-config`:

```sh
mise run argocd:sync-app --app k8s-playground-kind-root
mise run argocd:sync-app --app <child-app>
```
