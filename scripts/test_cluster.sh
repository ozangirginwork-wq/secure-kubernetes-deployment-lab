#!/usr/bin/env bash
# Run only against the disposable lab context, never a production cluster.
set -euo pipefail
[[ "$(kubectl config current-context)" == 'kind-lab7-secure-k8s' ]] || { echo 'Select kind-lab7-secure-k8s first'; exit 1; }
cleanup() { kubectl delete -f tests/client.yaml --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT
kubectl apply -f manifests/namespace.yaml
kubectl apply --dry-run=server -f manifests/
kubectl apply -f manifests/
kubectl rollout status deployment/secure-web -n secure-app --timeout=180s
kubectl get nodes
kubectl get deployment,replicaset,pods,service -n secure-app -o wide
kubectl get endpointslices -n secure-app -l kubernetes.io/service-name=secure-web-service
[[ "$(kubectl auth can-i get configmap/secure-web-config --as=system:serviceaccount:secure-app:secure-web-sa -n secure-app)" == 'yes' ]]
[[ "$(kubectl auth can-i get secrets --as=system:serviceaccount:secure-app:secure-web-sa -n secure-app || true)" == 'no' ]]
echo 'PASS: RBAC permits named ConfigMap read and denies Secret reads'
kubectl exec -n secure-app deployment/secure-web -- sh -c 'test -r /etc/demo-secret/DEMO_API_KEY && test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token'
echo 'PASS: demo Secret file readable; no automatic API token'
kubectl apply -f tests/client.yaml
kubectl wait -n secure-app --for=condition=Ready pod/policy-client --timeout=120s
# Use the Service IP so a DNS failure cannot masquerade as an ingress-policy denial.
service_ip=$(kubectl get svc secure-web-service -n secure-app -o jsonpath='{.spec.clusterIP}')
kubectl label pod policy-client -n secure-app access=allowed --overwrite
for attempt in {1..20}; do
  if kubectl exec -n secure-app policy-client -- curl -fsS --connect-timeout 3 --max-time 5 "http://$service_ip/" >/dev/null; then break; fi
  [[ "$attempt" -lt 20 ]] || exit 1
  sleep 2
done
echo 'PASS: allowed client reaches nginx (positive control)'
kubectl label pod policy-client -n secure-app access=blocked --overwrite
sleep 5
for attempt in {1..3}; do
  set +e
  kubectl exec -n secure-app policy-client -- curl -fsS --connect-timeout 3 --max-time 5 "http://$service_ip/"
  result=$?
  set -e
  [[ "$result" -eq 28 ]] || { echo "FAIL: expected curl timeout 28, got $result"; exit 1; }
done
echo 'PASS: blocked client times out in three attempts'
kubectl label pod policy-client -n secure-app access=allowed --overwrite
for attempt in {1..20}; do
  if kubectl exec -n secure-app policy-client -- curl -fsS --connect-timeout 3 --max-time 5 "http://$service_ip/" >/dev/null; then break; fi
  [[ "$attempt" -lt 20 ]] || exit 1
  sleep 2
done
echo 'PASS: relabeling the same client restores access'
old_uid=$(kubectl get pods -n secure-app -l app=secure-web -o jsonpath='{.items[0].metadata.uid}')
old_name=$(kubectl get pods -n secure-app -l app=secure-web -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$old_name" -n secure-app --wait=true
for attempt in {1..60}; do
  kubectl get pods -n secure-app -l app=secure-web -o json > /tmp/lab7-pods.json
  if python - "$old_uid" <<'PY'
import json,sys
pods=json.load(open('/tmp/lab7-pods.json'))['items']
ready=lambda p: any(c['type']=='Ready' and c['status']=='True' for c in p['status'].get('conditions',[]))
sys.exit(0 if len(pods)==3 and all(p['metadata']['uid']!=sys.argv[1] and ready(p) and not p['metadata'].get('deletionTimestamp') for p in pods) else 1)
PY
  then break; fi
  [[ "$attempt" -lt 60 ]] || exit 1
  sleep 2
done
kubectl get pods -n secure-app -l app=secure-web -o wide
echo 'PASS: deleted Pod UID replaced; three Ready replicas restored'
kubectl get pods -n secure-app -l app=secure-web -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
