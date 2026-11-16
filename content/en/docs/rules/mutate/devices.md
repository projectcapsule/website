---
title: Devices
weight: 3
description: >
  Default DeviceClass references in ResourceClaims and ResourceClaimTemplates.
---

Device mutations configure DRA class defaults under
`spec.rules[].mutate[].devices.class`. They fill missing class names when a
ResourceClaim or ResourceClaimTemplate is created in a selected Tenant namespace.

| Mutation | Resources | Operations |
|---|---|---|
| [`devices.class`](#default-class) | `resource.k8s.io/v1` and `resource.k8s.io/v1beta2` ResourceClaims and ResourceClaimTemplates | Main-resource `CREATE` only. |

Use [namespace selection](/docs/tenants/rules/) to give namespaces within one
Tenant different defaults. [Audience](/docs/rules/#audience) and
[mutation conditions](/docs/rules/#mutation-conditions) determine which entries
apply. Defaults remain subject to
[DeviceClass enforcement](/docs/rules/enforcement/devices/).

## Default class

`devices.class` supplies a default for every existing `exactly` request and
every `firstAvailable` alternative whose `deviceClassName` is omitted, `null`,
or the empty string. Explicit non-empty class names are always retained.

This example defaults GPU requests in namespaces labeled `device-profile: gpu`
and FPGA requests in namespaces labeled `device-profile: fpga`. The accompanying
enforcement rules limit each profile to its permitted classes:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: alice
  rules:
    - namespaceSelector:
        matchLabels:
          device-profile: gpu
      mutate:
        - action: merge
          devices:
            class: "{{ .tenant.metadata.name }}-gpu"
      enforce:
        action: allow
        devices:
          classes:
            - exact:
                - solar-gpu
                - solar-gpu-h100
    - namespaceSelector:
        matchLabels:
          device-profile: fpga
      mutate:
        - devices:
            class: solar-fpga
      enforce:
        action: allow
        devices:
          classes:
            - exact:
                - solar-fpga
```

The first default uses the shared
[Tenant/Namespace templates](/docs/tenants/rules/) support and resolves to
`solar-gpu`. Class values must resolve to valid DeviceClass names. Source values
can contain up to 4096 characters to allow templates; rendered names must satisfy
Kubernetes DNS subdomain and length requirements.

Namespaces without either profile label receive no default or class restriction
from these rules. Keep profile labels under platform control, and add a broader
deny rule if other namespaces must not request devices. The
[enforcement reference](/docs/rules/enforcement/devices/#reference) shows that
pattern. Namespaces in other Tenants use their own profiles.

In a `solar-production` namespace belonging to `solar` and labeled
`device-profile: gpu`, a tenant owner can submit this claim:

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: accelerator
  namespace: solar-production
spec:
  devices:
    requests:
      - name: gpu
        exactly: {}
```

Capsule supplies `spec.devices.requests[0].exactly.deviceClassName: solar-gpu`.
For a ResourceClaimTemplate, place the same requests under
`spec.spec.devices.requests`.

### Merge behavior and order

`merge` is the only supported action for `devices.class`, and is the default
when `action` is omitted. A mutation entry supplying `devices.class` with
`action: replace` is rejected. Keep it in a separate entry from other properties
that require replacement.

| Incoming value or structure | Result |
|---|---|
| Class name omitted, `null`, or `""` inside an existing request | Filled with the first applicable class default. |
| Explicit non-empty class name | Preserved, even when it differs from the default. Class enforcement can still reject it. |
| Mixture of empty and explicit names in `firstAvailable` | Empty names are filled independently; explicit alternatives and their order are preserved. |
| Missing device requests, or a request with neither `exactly` nor `firstAvailable` | No request structure is created. Kubernetes validation still applies. |
| Omitted or `null` `devices.class` | Supplies no default. An entry must supply some mutation property to be valid. |
| Empty `devices: {}` | Supplies no change and is invalid as the only property in a mutation entry. |
| Configured class value `""` or an invalid class name | Invalid configuration. |

Entries run in declaration order. Once a default fills a name, later defaults
retain that value. **The first applicable default wins** for each empty field.
Place more specific defaults before broader fallback defaults.

Conditions see the resource after metadata mutation and preceding device
defaults. A false condition skips the entry. A caller excluded by an audience
receives no default from that entry. With no audience, defaults apply to every
caller, including controllers; all explicit class names remain unchanged.

### Scope and enforcement

Defaulting neither creates a DeviceClass nor verifies that it exists. Provision
the classes and DRA driver needed for allocation. Selector-based enforcement and
an existing `Tenant.spec.deviceClasses` restriction may additionally require
every class to exist at admission.

A default is not an access grant. The resulting names must pass all applicable
class restrictions, including every fallback and the existing Tenant-wide
setting. With the GPU profile above, an explicit `other-gpu` is preserved by
mutation and rejected by the allow-list. A default outside that allow-list is rejected as well.

Defaulting runs only on creation. Metadata updates, status updates, and deletion
do not change class references. Updating a rule or namespace profile affects
subsequent creations; it does not reconcile existing claims or templates.

Kubernetes controllers create claims from the class names already stored in a
template. If a default changes after template creation, those explicit template
names are retained on the generated claim and checked against the current
enforcement rules. A scheduler-generated claim also keeps its explicit class
names, preserving the inputs used for allocation selection.

Device defaulting does not grant administrative device access. Keep the
[DRA administrative access baseline](/docs/operating/best-practices/tenants/#dra-administrative-access)
in place separately.
