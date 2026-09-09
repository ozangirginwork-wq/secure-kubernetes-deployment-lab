# Evidence: original lab captures

These are original screenshots from the Lab 7 session on September 8–9, 2026, recovered from the user's existing uploads. They are not generated terminal output. They were visually reviewed, renamed and copied without altering their pixels. [Checksums](checksums.md) record the published files.

They show the lab's development history, not an assertion that every screenshot matches the final YAML. The banner is separate illustrative artwork and is never used as execution evidence.

| Capture | What it proves | Context / limits |
| --- | --- | --- |
| [01 · Self-healing, ownership and labels](screenshots/01-self-healing.png) | Deployment/ReplicaSet/Pod output; deletion of one Pod followed by a replacement; Service/EndpointSlice inspection | Earlier `nginx-deployment` foundations exercise in `default`, before the hardened `secure-app` deployment. The deprecated Endpoints warning prompted use of EndpointSlices. |
| [02 · Blocked and allowed clients](screenshots/02-networkpolicy.png) | Curl timeout for the blocked client, nginx HTML for `access=allowed` | Original ingress test. Provider installation is not shown. The new CI test adds a positive control before denial and uses the same client and Service IP. |
| [03 · Read-only filesystem recovery](screenshots/03-readonly-rollout.png) | nginx's `/tmp/proxy_temp` write error, writable `/tmp` manifest, successful rollout and three Ready Pods | Original troubleshooting evidence; temporary old replicas during rollout are expected. |
| [04 · Service and EndpointSlices](screenshots/04-service-endpointslices.png) | ClusterIP port 80 targets port 8080 and resolves to three backend addresses | Harmless local cluster addresses; one previous Pod is terminating during the rollout. |
| [05 · Original Checkov result](screenshots/05-original-checkov.png) | 170 passed, 24 failed, 0 skipped with the original local scanner | **Before review**, Checkov 3.3.16 and globally soft-failing workflow visible. Current pinned CI is 3.2.495, independently reproducing the old totals before the fixes. This is not a screenshot of the final CI result. |
| [06 · Explicitly fake Secret](screenshots/06-fake-secret.png) | `EXAMPLE_ONLY_NOT_A_REAL_SECRET` in the original file; original Git push | No real credential. Final manifests mount it as a file instead of an environment variable. |

## Current execution evidence

[Verified runtime log excerpt](ci-validation.md) records the first successful full CI run, including all three Ready nodes.

Use [GitHub Actions](https://github.com/ozangirginwork-wq/secure-kubernetes-deployment-lab/actions/workflows/security-scan.yml) for commit-specific static and runtime results. Successful integration logs contain three-node readiness, server-side validation, RBAC allow/deny, NetworkPolicy allow/block/allow and Pod UID replacement assertions. A workflow definition alone is not proof that those tests passed: inspect the run conclusion and steps.

No original screenshot of all three nodes in a single `kubectl get nodes` view, the CNI installation, or a completed GitHub Actions run was found among the reviewed original captures. Those were not fabricated. The current CI provides fresh node/runtime evidence when it succeeds. A standalone nginx-browser screenshot was not selected because the successful HTTP response is already visible in the policy test.

## Capture guidance

Keep the command and relevant output together. Avoid kubeconfig, tokens, actual Secret values, `printenv` without selected harmless variables, browser account menus and unrelated chats. Private cluster IPs, Pod UIDs and clearly fake values are harmless in this local lab. Never redact or alter an error into a success.
