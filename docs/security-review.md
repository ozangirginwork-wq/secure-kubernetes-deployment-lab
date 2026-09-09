# Security review and intentional limits

Review date: 2026-09-09. Original input commit: `d1629c133fca823e830d79949cf4e4a30b032b96`.

## Important changes and rationale

| Change | Reason |
| --- | --- |
| Restore a real Namespace manifest | Remove a conflicting second Deployment and make fresh installs possible |
| Restricted Pod Security Admission | Enforce the intended container baseline for this namespace |
| Explicit Pod security context and RuntimeDefault seccomp | Align declared process identity and system-call filtering with container hardening |
| Retain UID/GID 101 | Match the nginx image's built-in user instead of changing identity without need |
| Pin the nginx image to its observed digest and set imagePullPolicy Always | Use the immutable image reference recorded by successful CI, rather than guessing a digest |
| Mount the fake Secret as a read-only file | Reduce accidental leakage through environment inspection; nginx does not consume this value |
| Disable token automount on ServiceAccount and Pod | Make the default explicit; nginx does not use the API |
| Narrow RBAC to get one named ConfigMap | Remove unnecessary namespace-wide list/read access while preserving the authorization exercise |
| Bound `/tmp` and ephemeral storage | Keep nginx writable space limited without weakening the root filesystem |
| Change APP_ENV from production to lab | Reflect the educational setting; this variable does not configure nginx |
| Explicit Calico setup for a fresh cluster | Make NetworkPolicy enforcement reproducible rather than relying on undocumented local setup |
| Replace global soft-fail with documented exceptions | Make new meaningful application findings fail CI |
| Refresh checkout/setup-python to verified v6 commit pins | Remove deprecated Node 20 action-runtime warnings |
| Add server-side and runtime verification | Catch problems static scanning cannot prove, including actual policy enforcement |

## Checkov results

Pinned scanner: **3.2.495**, framework: **kubernetes**, directory: **manifests**.

| Revision | Passed | Failed | Skipped | Parsing errors |
| --- | ---: | ---: | ---: | ---: |
| Original commit | 170 | 24 | 0 | 0 |
| Reviewed manifests with verified digest | 104 | 1 | 0 | 0 |

Removing the duplicate Deployment changes the number of applicable checks. Do not describe this as a percentage improvement. Checkov's internal resource count can include representations beyond the nine Kubernetes objects; the manifest validator counts unique API objects.

### Finding left visible

| Finding | Scope | Decision and residual risk |
| --- | --- | --- |
| `CKV_K8S_40`: prefer a high UID | Application Deployment | Keep UID/GID 101 to match the nginx image's user and filesystem conventions. It is non-root, with no host mounts/namespaces and no additional capabilities. A high UID or user namespaces would reduce host-identity collision risk further; this is not claimed as solved. |


`--soft-fail-on CKV_K8S_40` keeps the finding in the output but lets the gate pass with only that finding. There are no inline skip annotations or global soft-fail. Reassess this policy whenever images or resources change; it is not a blanket exception for unrelated workloads.

This is an **application-level** tradeoff, not a cluster-level finding. Cluster security (API-server flags, etcd encryption, node patching, admission/audit configuration outside this namespace and CNI permissions) is not established by scanning this directory. No cluster findings are suppressed to improve the score.

The temporary curl Pod is a test fixture, not a deployed service; it intentionally has no web probes and lives for one test. `kind-config.yaml`, upstream Calico components and test fixtures are outside the application Checkov scan. The workflow validates their behavior by actually using them.

## Privacy and secret handling

The committed Secret contains one explicitly fake demonstration value. It is not used to authenticate anywhere. Never replace it with a credential. Real secrets must be supplied outside Git; base64 and `.gitignore` do not make an already committed secret safe.

The final audit covers the original Git history available in this repository, the final source files and selected evidence. See [the audit record](../evidence/audit.md) for scope and actual results. A scan cannot prove that no unknown credential format exists; visual review and contextual inspection complement detection.

## Boundaries

- Local single-host kind is not a production or highly available cluster.
- This is an ingress-only policy for the selected web Pods, not namespace-wide egress isolation.
- API-mediated port-forward and node-origin traffic have different policy behavior from ordinary client Pods.
- ConfigMap/Secret delivery does not require granting the application's account read access through the API.
- No container-image vulnerability assessment, penetration test, real-secret rotation or AWS deployment is claimed.
- CI runs on a disposable GitHub runner and cleans up the cluster; it does not alter the user's local kind cluster.

## Image digest provenance

The first successful integration run, [34299527912](https://github.com/ozangirginwork-wq/secure-kubernetes-deployment-lab/actions/runs/34299527912), reported `docker.io/nginxinc/nginx-unprivileged@sha256:c97ff0bf7cbae369953c6da1232ec14ad9f971d66360c5698db0856a4cd657a0` for all three running web containers. The final Deployment pins that observed digest. This resolves `CKV_K8S_43`; it is no longer an exception. Validation covers Linux amd64, not every CPU architecture. Digest pinning does not imply absence of image vulnerabilities, and updates require reviewing a new digest and repeating the tests.
