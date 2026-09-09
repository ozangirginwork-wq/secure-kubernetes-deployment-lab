# Verified runtime evidence

Source: [GitHub Actions run 34299527912](https://github.com/ozangirginwork-wq/secure-kubernetes-deployment-lab/actions/runs/34299527912), input commit `174bf54e6858b16173fa023f7500c8f2be09e1bb`. Both jobs succeeded. These are selected verbatim lines from the integration job, not simulated output.

```text
2026-09-09T01:33:11.1042565Z lab7-secure-k8s-control-plane   Ready    control-plane   76s   v1.34.0
2026-09-09T01:33:11.1043000Z lab7-secure-k8s-worker          Ready    <none>          66s   v1.34.0
2026-09-09T01:33:11.1043513Z lab7-secure-k8s-worker2         Ready    <none>          67s   v1.34.0
2026-09-09T01:33:11.6796010Z PASS: RBAC permits named ConfigMap read and denies Secret reads
2026-09-09T01:33:11.9099250Z PASS: demo Secret file readable; no automatic API token
2026-09-09T01:33:14.7543228Z PASS: allowed client reaches nginx (positive control)
2026-09-09T01:33:30.0125118Z PASS: blocked client times out in three attempts
2026-09-09T01:33:30.3446633Z PASS: relabeling the same client restores access
2026-09-09T01:33:34.7225498Z PASS: deleted Pod UID replaced; three Ready replicas restored
2026-09-09T01:33:36.0578774Z Deleted nodes: ["lab7-secure-k8s-worker" "lab7-secure-k8s-control-plane" "lab7-secure-k8s-worker2"]
```

This run resolved the nginx image digest that was subsequently pinned in the application. It also produced two deprecated action-runtime warnings, addressed by moving checkout/setup-python to verified v6 commit pins. Use the workflow badge/current run for the latest commit's result. The original screenshots remain distinct from this newly executed CI evidence.

