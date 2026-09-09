# Troubleshooting notes

## Incidents captured during the original lab

| Symptom | Evidence and diagnosis | Fix | What to verify |
| --- | --- | --- | --- |
| Non-root rollout would not start | Pod event: `container has runAsNonRoot and image will run as root` with standard nginx | Use an image designed for unprivileged execution and its port 8080 | New Pod starts without relaxing `runAsNonRoot` |
| Read-only rollout failed | nginx logged `mkdir() /tmp/proxy_temp failed (30: Read-only file system)` | Mount writable `emptyDir` at `/tmp`; retain read-only root | Successful rollout and three Ready replicas; original screenshot retained |
| Old Endpoints command warned about deprecation | Kubernetes directed the user to EndpointSlice | Inspect `discovery.k8s.io/v1` EndpointSlices | Service selector resolves to expected backend Pods and port |
| Deleted managed Pod reappeared | Original foundations exercise showed a new name/age while replica count returned to three | No manual Pod recreation: ReplicaSet reconciliation is expected | Compare names/UIDs and Ready count |
| Unlabeled client timed out | A labeled client could reach the same nginx Service | Ingress policy selects web Pods and permits `access=allowed` sources | Check a positive control and denial; don't infer policy from timeout alone |

## Problems found during repository review

`namespace.yaml` contained a second Deployment rather than a Namespace. Its Pod template used standard nginx without the hardening in `deployment.yaml`. Applying the folder could update the same Deployment twice and leave an incorrect template; a fresh cluster also lacked the namespace. It now declares the real Namespace, and static validation rejects duplicate resource identities.

CI used global `soft_fail: true`. That allowed a green check even with 24 failures. It now keeps only the explained UID finding non-blocking and adds live deployment/policy tests. The original scan screenshot is labeled as a before-review result.

The committed kind config did not establish a NetworkPolicy provider. The reproduction config now disables the default CNI and installs versioned Calico. This is a fresh-cluster recipe, not evidence that the original session used Calico.

## Short diagnostic sequence

Run only in the disposable kind context:

```powershell
kubectl config current-context
kubectl get pods -n secure-app -o wide
kubectl describe deployment secure-web -n secure-app
kubectl get events -n secure-app --sort-by=.lastTimestamp
kubectl logs -n secure-app deployment/secure-web --tail=30
kubectl get service secure-web-service -n secure-app -o yaml
kubectl get endpointslices -n secure-app -l kubernetes.io/service-name=secure-web-service
kubectl describe networkpolicy secure-web-ingress -n secure-app
```

For a failing Pod, `kubectl describe pod <pod-name> -n secure-app` shows scheduling and container events. Use `kubectl logs <pod-name> -n secure-app --previous` after a restart. Replace the placeholder with the actual Pod name. Do not publish unrestricted environment dumps or Secret YAML.

- **Pending:** inspect CPU/memory scheduling messages, node readiness and CNI health.
- **ImagePullBackOff:** inspect the image tag/digest, registry connectivity and pull limits.
- **CreateContainerConfigError:** check referenced ConfigMap/Secret names and namespace.
- **Running but not Ready:** inspect the readiness path/port and application logs.
- **Empty Service backends:** compare Service selectors, Pod labels and readiness.
- **Connection refused:** check the listening port and `targetPort`; it is not the expected NetworkPolicy timeout.
- **All clients can connect:** check Calico readiness, policy selectors and other policies. Policy allows are additive.
- **Port-forward works but Pod request fails:** these use different traffic paths; inspect NetworkPolicy and DNS.

Change the manifest, apply it and wait for rollout completion. Do not remove a security control simply to make a failing Pod start without understanding the underlying cause.
