"""Catch duplicate resources/keys and cross-file mistakes before a cluster exists."""
from pathlib import Path
import yaml

class UniqueLoader(yaml.SafeLoader):
    pass

def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result

UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)
resources = {}
for path in sorted(Path('manifests').glob('*.yaml')):
    for doc in yaml.load_all(path.read_text(), Loader=UniqueLoader):
        assert doc and {'apiVersion', 'kind', 'metadata'} <= doc.keys(), path
        meta = doc['metadata']
        key = (doc['kind'], meta.get('namespace', ''), meta['name'])
        assert key not in resources, f'Duplicate resource {key}: {path}'
        resources[key] = doc

ns = 'secure-app'
assert ('Namespace', '', ns) in resources, 'Missing real Namespace object'
for kind, namespace, name in resources:
    assert kind == 'Namespace' or namespace == ns, (kind, namespace, name)
def get(kind, name):
    return resources[(kind, ns, name)]
dep = get('Deployment', 'secure-web')['spec']
pod = dep['template']
labels = pod['metadata']['labels']
service = get('Service', 'secure-web-service')['spec']
for selector in (dep['selector']['matchLabels'], service['selector'], get('NetworkPolicy', 'secure-web-ingress')['spec']['podSelector']['matchLabels']):
    assert all(labels.get(k) == v for k, v in selector.items()), 'Selector mismatch'
ports = {p['containerPort'] for c in pod['spec']['containers'] for p in c.get('ports', [])}
assert service['ports'][0]['targetPort'] in ports
get('ServiceAccount', pod['spec']['serviceAccountName'])
secret = get('Secret', 'secure-web-secret')
assert secret.get('stringData') == {'DEMO_API_KEY': 'EXAMPLE_ONLY_NOT_A_REAL_SECRET'}
assert not secret.get('data'), 'Only the fake stringData example may be committed'
for volume in pod['spec']['volumes']:
    if 'secret' in volume:
        get('Secret', volume['secret']['secretName'])
for container in pod['spec']['containers']:
    for env in container.get('envFrom', []):
        if 'configMapRef' in env:
            get('ConfigMap', env['configMapRef']['name'])
assert len(resources) == 9, f'Unexpected application resource count: {len(resources)}'
print(f'Validated {len(resources)} unique application resources, selectors, references and fake Secret')
