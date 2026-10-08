---
title: Storage
weight: 6
description: >
  Default PersistentVolume isolation and additional volume access through namespace rules.
---

Storage enforcement is configured under `spec.rules[].enforce.storage`.
[Persistent Volumes](#persistent-volumes) covers default Tenant isolation and
[additional volume access](#volumes) for PVs without a Tenant label.

Rules use the shared [namespace selection](/docs/tenants/rules/),
[audiences](/docs/rules/#audience),
[conditions](/docs/rules/#enforcement-conditions), and
[actions and order](/docs/rules/enforcement/#action).
See [Reference](#reference) for a complete Tenant example.

## Rule Composition

### Actions and order

Storage rules use the existing ordered action evaluation, but affect only
additional access to PVs without a Tenant label:

| Action | Effect on additional access |
|---|---|
| `allow` | Grants access when the selector, audience, namespace selection, and all conditions match. |
| `deny` | Rejects the exception when it is the last matching allow/deny rule. This is the default action. |
| `audit` | Emits a Kubernetes event for a match; never grants access. |

The last matching `allow` or `deny` wins. If none grants access, the existing
missing-Tenant-label rejection remains. An audit-only rule therefore does not
permit an unlabeled PV. Other applicable admission checks must still pass after
a storage rule allows access.

Same-Tenant volume access remains available without these rules. A matching
rule cannot authorize another Tenant's labeled PV or a PV whose Tenant label
has an empty value. See [Ownership and label protection](#ownership-and-label-protection).

### Admission scope and limits

<span id="admission-scope"></span>

- Checks apply to PVC creation and updates of an unbound PVC with an explicit
  `spec.volumeName`, including the PATCH that sets it during a restore.
- The referenced PV must exist. A PV being deleted cannot receive an additional
  grant.
- PVCs without `spec.volumeName` do not use these additional rules. They do not
  change dynamic provisioning or how Kubernetes selects a PV.
- Already-bound PVC updates keep their existing behavior. These rules do not
  reauthorize or revoke an established binding.
- The grant authorizes the PVC admission request. It does not rewrite the PV's
  `claimRef`, restore labels, move data, or complete binding. RBAC, StorageClass
  restrictions, other admission policies, and Kubernetes binding requirements
  continue to apply.

PVC selector mutation runs only on creation. All updates preserve the existing
selector, including updates while the claim is still Pending. The PV ownership
check still applies when an unbound PVC is updated to reference a volume. See
[PVC selectors and dynamic provisioning](#pvc-selectors-and-dynamic-provisioning).

## Persistent Volumes

Capsule isolates PersistentVolumes (PVs) between Tenants by default. Storage rules
let administrators grant additional access to selected PVs that do not yet carry
Capsule's Tenant ownership label. Configure these additional grants under
`spec.rules[].enforce.storage.volumes`.

This supports workflows that patch a destination PersistentVolumeClaim (PVC)
before changing the restored PV's claim reference from a temporary claim to the
destination claim. The [default isolation](#default-persistentvolume-isolation)
described below continues to apply.

### Default PersistentVolume isolation

Tenant owners can create PVCs using the
[StorageClasses available to their Tenant](/docs/tenants/enforcement/#storageclasses).
When a PV's `spec.claimRef` points to a PVC in a Tenant namespace, Capsule's PV
controller labels the volume with `capsule.clastix.io/tenant: <tenant-name>`.
The controller resolves the Tenant from the claim's namespace; PVs themselves
are cluster-scoped. This behavior does not require any `storage.volumes` rules.

For example, a PV claimed in `solar-production`, a namespace belonging to the
`solar` Tenant, has the following relevant fields. This is an excerpt of the
existing PV, not a complete volume definition:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: solar-data
  labels:
    capsule.clastix.io/tenant: solar
spec:
  storageClassName: standard
  persistentVolumeReclaimPolicy: Retain
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    namespace: solar-production
    name: data
```

#### Reusing retained volumes

What happens after a PVC is deleted depends on the PV's reclaim policy. With
`Retain`, the volume and its data remain for manual reclamation; it is not
automatically ready for another claim. Follow the
[Kubernetes reclamation procedure](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaiming)
before reusing the storage.

Once the PV is available for reuse, Capsule permits claims from namespaces
belonging to `solar` to reference it. Kubernetes must still be able to bind the
claim: the requested capacity, access modes, StorageClass, and other binding
requirements must be satisfied. Deleting the old PVC does not remove the PV's
Tenant label or authorize a different Tenant to use it.

A claim from `green-energy`, a namespace belonging to another Tenant named
`green`, cannot reference `solar-data`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: green-energy
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  volumeName: solar-data
```

Capsule rejects that request with a cross-Tenant mount error:

```text
admission webhook "pvc.validating.projectcapsule.dev" denied the request: Preventing a cross-tenant mount for PersistentVolume solar-data
```

#### PVC selectors and dynamic provisioning

On PVC creation, Capsule adds the owning Tenant requirement to an existing
`spec.selector`, or creates a selector when `spec.volumeName` is set. It preserves
unrelated selector requirements and replaces conflicting requirements for
`capsule.clastix.io/tenant` with the correct Tenant value.

A new PVC with neither `spec.selector` nor `spec.volumeName` receives no Tenant
selector, preserving dynamic provisioning. On update, Capsule leaves the
selector unchanged, even while the PVC is Pending: Kubernetes treats the
selector as immutable after creation. This allows a restore component to set
`spec.volumeName` without Capsule adding a selector change that Kubernetes
would reject.

For an explicit `spec.volumeName`, Capsule also checks the referenced PV's
Tenant label during PVC admission. A PV labeled for the same Tenant passes this
ownership check; another Tenant's PV is rejected. Without an additional grant,
a PV with no Tenant label is also rejected. The rules below extend this last
case while retaining the default ownership checks.

### Additional volume access {#volumes}

Each entry in `storage.volumes` has a required Kubernetes label `selector` and an
optional `name` for admission and audit messages. The selector matches labels on
the PV named by the PVC's `spec.volumeName`.

```yaml
rules:
  - namespaceSelector:
      matchLabels:
        storage-profile: shared-imports
    enforce:
      action: allow
      storage:
        volumes:
          - name: approved-imports
            selector:
              matchLabels:
                storage.example.com/pool: imports
              matchExpressions:
                - key: storage.example.com/quarantined
                  operator: DoesNotExist
```

Place this `rules` block under `Tenant.spec`. It grants additional access to PVs
with the `imports` pool label and no quarantine label, only from selected
namespaces. Without an audience, the rule applies to every caller in that scope.

- All requirements in one selector must match. Entries in `volumes` are
  alternatives: any matching entry matches that enforcement rule.
- `selector: {}` explicitly matches every eligible PV, including a PV with no
  labels. Use conditions and an audience to scope a restore exception.
- Omitting `selector`, or setting it to `null`, is invalid. An omitted or empty
  `volumes` list grants no additional access.
- A rule supports at most 64 volume entries. Optional names must be unique
  within the list and use DNS labels of up to 63 characters.

#### Ownership and label protection

Capsule checks the PV's `capsule.clastix.io/tenant` label before evaluating any
additional grant:

| PV ownership label | Volume access decision |
|---|---|
| Matches the destination Tenant | Existing access is retained, even if no storage rule matches or a storage rule says `deny`. |
| Names another Tenant | Denied; no selector or CEL condition can override ownership. |
| Key exists with an empty value | Denied; this is not treated as an absent label. |
| Key is absent | Requires an applicable matching `allow` rule. |

**Selectors only read PV labels.** They never add, remove, or overwrite PV labels,
and are never copied into `PVC.spec.selector`. Labels supplied on the PVC cannot
satisfy a PV selector. Capsule's existing PVC Tenant selector enforcement remains
in place.

Labels used for authorization must be controlled by administrators or trusted
storage components. Tenant actors must not receive RBAC permissions to edit PVs
or the rules granting access. A name prefix or a label alone does not establish
Tenant ownership.

#### Conditions

Use `enforce.conditions` to inspect both the PVC being admitted and the referenced
PV. There is no separate conditions field on a volume entry.

| CEL variable | Value during additional volume access evaluation |
|---|---|
| `object` | The incoming PVC, including its destination namespace and `spec.volumeName`. |
| `request` | Admission metadata, including operation and authenticated caller. |
| `volume` | A read-only snapshot of the existing PV referenced by `spec.volumeName`. |

Check optional fields with `has(...)`, for example
`volume != null && has(volume.spec.claimRef)`. Outside additional volume access
evaluation, `volume` is `null`, including in metadata conditions on a PVC. Keep
conditions that depend on `volume` in a separate storage enforcement block when
other policies need independent conditions.

All conditions must be true. A false condition skips the enforcement block; it
does not grant access. Evaluation errors reject admission unless another
condition in that block is false, following the normal
[condition evaluation rules](/docs/rules/#evaluation).

## Reference

### Restore through a temporary namespace

For a restore workflow using temporary claims in `openshift-adp`, the destination
PVC may need to reference a PV whose `claimRef` still names a temporary claim.
PVs are cluster-scoped; the namespace in `spec.claimRef` belongs to that PVC.
If that PV has no Tenant label, the default Capsule ownership check rejects the
PVC patch. An additional storage rule can authorize this handoff without
relaxing access to another Tenant's labeled PVs.

The following Tenant grants the exception in namespaces labeled
`storage-profile: restore`. It allows service accounts from `openshift-adp` to
update a PVC only when the PV's temporary claim is in that namespace and its
name starts with the destination namespace followed by `-`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  rules:
    - namespaceSelector:
        matchLabels:
          storage-profile: restore
      audience:
        - kind: Group
          name: system:serviceaccounts:openshift-adp
      enforce:
        action: allow
        conditions:
          - name: restore-handoff
            expression: >-
              request.operation == 'UPDATE' &&
              volume != null &&
              has(volume.spec.claimRef) &&
              volume.spec.claimRef.namespace == 'openshift-adp' &&
              volume.spec.claimRef.name.startsWith(object.metadata.namespace + '-')
        storage:
          volumes:
            - name: temporary-restore-volume
              selector: {}
```

Replace the owner, staging namespace, and claim naming condition with values
from your restore workflow. This example grants the audience to **all service
accounts in `openshift-adp`**. To scope it to one restoring component, use an
audience with `kind: ServiceAccount` and its full
`system:serviceaccount:<namespace>:<name>` username. Match the identity making
the PVC patch, which may differ from the user who submitted a NonAdminRestore.

The prefix check is a naming convention, not proof of ownership. The trusted
restore component remains responsible for handing the correct volume to the
destination claim. Use the actual temporary claim naming scheme; Capsule does
not derive it from a NonAdminRestore object.

If the temporary PV carries an administrator-controlled pool label, replace
`selector: {}` with a `matchLabels` selector to narrow the grant further. Capsule
does not add that label on your behalf.

After the PVC patch is admitted, the restore component can finish the PV
handoff. Capsule's existing PV labeling behavior still applies when the claim
reference points to a Tenant namespace. The rule itself does not change labels
or claim references.

| Request or PV state | Result with this example |
|---|---|
| Trusted restore caller, selected namespace, matching temporary claim, no Tenant label | Additional access is allowed. |
| Tenant owner without the restore audience | No additional access. |
| Namespace without `storage-profile: restore` | No additional access. |
| PVC creation rather than update | No additional access; the condition requires `UPDATE`. |
| Missing claim reference or a different temporary namespace/name prefix | No additional access. |
| PV labeled for another Tenant | Denied regardless of the rule. |
| PV already labeled for `solar` | Existing access is retained; other checks still apply. |
