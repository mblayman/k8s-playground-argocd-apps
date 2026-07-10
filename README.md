# k8s-playground-argocd-apps
Application configs for Argo CD for my k8s playground

## Structure

- `clusters/kind/application.yaml`: root Argo CD `Application` to apply manually after Argo CD is installed in the local kind cluster.
- `clusters/kind/apps/`: child Argo CD `Application` manifests rendered by the kind root app using Argo CD directory rendering.
- `components/apps/`: local application component configuration and manifests managed by child apps.
- `components/platform/`: local platform component configuration for cluster services such as MetalLB, cert-manager, and Istio.

Initial bootstrap flow:

```sh
kubectl --context kind-k8s-playground apply -f clusters/kind/application.yaml
```
