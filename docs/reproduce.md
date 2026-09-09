# Reproduce Lab 7 locally

## Prerequisites

Use Docker with Linux containers, Git, kubectl compatible with Kubernetes 1.34 and kind v0.30.0. On Windows, start Docker Desktop before running PowerShell. Check `docker info`, `kubectl version --client` and `kind version`. Python 3.12 is optional for local static checks. The CI workflow records the exact kind node digest. The nginx digest was resolved and successfully run on the Linux amd64 CI runner; the user's Intel/AMD Windows machine is the primary local target. Other architectures are not verified by this lab.

These commands create only a local disposable cluster. They do not use AWS. Downloads require internet access. Images and tooling are versioned for the lab; review newer security patches before adapting anything beyond a disposable exercise.

## 1. Create the cluster and policy provider

If an earlier `lab7-secure-k8s` cluster exists, save any wanted evidence first. Recreating it discards its workloads. Do not try to change the CNI of a running cluster by simply reapplying the kind config.

```powershell
kind get clusters
# Only if replacing this disposable lab cluster:
# kind delete cluster --name lab7-secure-k8s
kind create cluster --name lab7-secure-k8s --config kind-config.yaml --image kindest/node:v1.34.0@sha256:7416a61b42b1662ca6ca89f02028ac133a309a2a30ba309614e8ec94d976dc5a
kubectl config use-context kind-lab7-secure-k8s
kubectl config current-context
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/calico.yaml
kubectl rollout status daemonset/calico-node -n kube-system --timeout=240s
kubectl rollout status deployment/calico-kube-controllers -n kube-system --timeout=180s
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes -o wide
```

**Stop if any step fails.** Nodes can be NotReady before Calico is installed because the default CNI is disabled. The Pod CIDR matches the Calico manifest. If it overlaps your LAN/VPN, choose a non-overlapping CIDR and adjust Calico's IP pool consistently before creating the cluster.

The upstream Calico manifest creates privileged networking components in `kube-system`; those are cluster infrastructure, not application containers. Do not copy their permissions into the nginx Deployment.

## 2. Deploy in the correct order

```powershell
kubectl apply -f manifests/namespace.yaml
kubectl apply --dry-run=server -f manifests/
kubectl apply -f manifests/
kubectl rollout status deployment/secure-web -n secure-app --timeout=180s
kubectl get deployment,replicaset,pods -n secure-app -o wide
kubectl get service -n secure-app
kubectl get endpointslices -n secure-app -l kubernetes.io/service-name=secure-web-service
```

Create the namespace first: a folder apply is not a dependency ordering system. Temporary Pending/ContainerCreating states are normal while images pull. Continue only after three replicas are Ready.

## 3. Open nginx locally

```powershell
kubectl port-forward -n secure-app service/secure-web-service 8080:80 --address 127.0.0.1
```

Leave that terminal open and visit `http://127.0.0.1:8080`. Stop with Ctrl+C. This is API-mediated access to a Pod behind the Service, not a load-balancing benchmark or NetworkPolicy test.

## 4. Test NetworkPolicy with positive controls

Use another terminal. The same client remains alive while its label changes, and requests use the Service IP to avoid confusing DNS errors with policy enforcement.

```powershell
kubectl apply -f tests/client.yaml
kubectl wait -n secure-app --for=condition=Ready pod/policy-client --timeout=120s
$serviceIp = kubectl get svc secure-web-service -n secure-app -o jsonpath='{.spec.clusterIP}'
kubectl label pod policy-client -n secure-app access=allowed --overwrite
Start-Sleep -Seconds 5
kubectl exec -n secure-app policy-client -- curl -fsS --connect-timeout 3 --max-time 5 "http://$serviceIp/"
# Expected: nginx HTML and exit code 0.
kubectl label pod policy-client -n secure-app access=blocked --overwrite
Start-Sleep -Seconds 5
kubectl exec -n secure-app policy-client -- curl -fsS --connect-timeout 3 --max-time 5 "http://$serviceIp/"
$LASTEXITCODE
# Expected: timeout and exit code 28, not a DNS error or connection refusal.
kubectl label pod policy-client -n secure-app access=allowed --overwrite
Start-Sleep -Seconds 5
kubectl exec -n secure-app policy-client -- curl -fsS --connect-timeout 3 --max-time 5 "http://$serviceIp/"
# Expected: nginx HTML again.
kubectl delete -f tests/client.yaml
```

Policies can take a few seconds to propagate. If the initial allowed request fails, troubleshoot before treating any timeout as a security result. If the blocked request succeeds, inspect the policy provider, selectors and other additive policies.

The namespace now enforces the Restricted standard. Use the provided client manifest; a bare `kubectl run` without a security context may be rejected before the network test even starts.

## 5. Test self-healing

```powershell
kubectl get pods -n secure-app -l app=secure-web -o wide
$oldPod = kubectl get pods -n secure-app -l app=secure-web -o jsonpath='{.items[0].metadata.name}'
kubectl delete pod $oldPod -n secure-app
kubectl get pods -n secure-app -l app=secure-web -w
```

Observe a new Pod name and wait for three Ready replicas; stop the watch with Ctrl+C. A new Pod has a new UID and may have a new IP. This tests Pod replacement, not physical-host availability.

## 6. Test RBAC and configuration without displaying secrets

```powershell
kubectl auth can-i get configmap/secure-web-config -n secure-app --as=system:serviceaccount:secure-app:secure-web-sa
# yes
kubectl auth can-i get secrets -n secure-app --as=system:serviceaccount:secure-app:secure-web-sa
# no
kubectl auth can-i list configmaps -n secure-app --as=system:serviceaccount:secure-app:secure-web-sa
# no: the Role permits only get on the named ConfigMap
kubectl exec -n secure-app deployment/secure-web -- printenv APP_ENV APP_NAME
kubectl exec -n secure-app deployment/secure-web -- test -r /etc/demo-secret/DEMO_API_KEY
```

Impersonation requires the cluster-admin context used by kind. The kubelet delivers ConfigMaps/Secret volumes independently of whether the application's ServiceAccount can read them through the API. Disabling automatic token mounting does not prevent volume delivery.

## 7. Repeat automated checks

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-ci.txt
python scripts/validate_manifests.py
checkov -d manifests --framework kubernetes --skip-download
```

The raw Checkov command exits nonzero for the documented UID finding. To apply the same exception policy as CI:

```powershell
checkov -d manifests --framework kubernetes --skip-download --soft-fail-on CKV_K8S_40
```

On Linux or WSL with Docker/kubectl access and the same context, run `bash scripts/test_cluster.sh`. This applies the app, tests RBAC, NetworkPolicy and reconciliation, and removes the temporary client. It deliberately refuses other context names.

## 8. Cleanup

Save any wanted evidence first, then remove only this lab cluster:

```powershell
kind delete cluster --name lab7-secure-k8s
kind get clusters
```

This deletes the kind nodes and their workloads. Cached Docker images may remain on disk; they are not running cloud resources. No global Docker prune is needed.
