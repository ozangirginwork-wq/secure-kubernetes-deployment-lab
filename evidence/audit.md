# Privacy and secrets audit

Reviewed on 2026-09-09 before publication.

- The original repository contained one reachable commit and 11 unique file blobs. Every historical blob was extracted and scanned, not just the current working tree.
- `detect-secrets` 1.5.0 (with verification/network calls disabled) scanned the historical blobs, current source and OCR text from the recovered original screenshots. Findings were manually reviewed: the deliberately fake value, its expected-value assertion and the Kubernetes Secret resource name. No real credential was identified.
- The six published screenshots were individually inspected at readable resolution. They show local lab commands, private cluster addresses, public repository identity and the clearly fake value. No credential, token, password, private account information or sensitive personal data was identified in the selected images.
- Original screenshots are copied without pixel edits. Their checksums match the source uploads. Unrelated LinkedIn/browser/chat captures and redundant screenshots are not published.
- `secret.yaml` has exactly one fake stringData entry. The manifest validator rejects changes to that value or additional encoded data.
- `.gitignore` excludes common kubeconfig, private-key, environment and private-evidence paths. This is preventive hygiene, not protection for a secret already in Git.
- The banner is an illustration, contains no user account data and is stored outside the evidence directory.

Scope: reachable Git history, reviewed working tree, selected image pixels and metadata. Git author identity already belongs to the public repository and is not treated as a credential. Deleted remote refs, inaccessible objects, the user's computer and their live kubeconfig are outside the audit. Automated detection plus visual inspection found no sensitive material to remove; this is not a mathematical guarantee against every possible unknown secret format.
