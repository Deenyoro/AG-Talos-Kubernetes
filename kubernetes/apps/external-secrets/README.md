# External Secrets Operator - AG-Talos-Kubernetes

This directory contains the External Secrets Operator (ESO) deployment and integration for the AG-Talos-Kubernetes repository. ESO enables dynamic secret management from external providers while maintaining GitOps workflows.

## Overview

External Secrets Operator provides:
- **Dynamic secret synchronization** from external secret stores
- **GitOps compatibility** with Flux CD workflows
- **SOPS coexistence** for gradual migration
- **Vaultwarden integration** using webhook provider pattern

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AG-Talos-Kubernetes                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ SOPS Secrets    │    │ External Secrets Operator      │ │
│  │ (Existing)      │    │ (New)                          │ │
│  │                 │    │                                │ │
│  │ • Age encrypted │    │ • Vaultwarden Provider         │ │
│  │ • Git committed │    │ • Dynamic sync                 │ │
│  │ • Manual mgmt   │    │ • Auto refresh                 │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│           │                           │                     │
│           ▼                           ▼                     │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │            Kubernetes Secrets                           │ │
│  │  • SOPS-managed secrets (*.sops.yaml)                  │ │
│  │  • ESO-managed secrets (*-eso suffix)                  │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Vaultwarden    │
                    │  Instance       │
                    │  (External)     │
                    └─────────────────┘
```

## Components

### 1. External Secrets Operator
- **Location**: `operator/`
- **Namespace**: `external-secrets-system`
- **Purpose**: Core ESO deployment with CRDs and controllers

### 2. Vaultwarden Provider
- **Location**: `vaultwarden-provider/`
- **Namespace**: `default`
- **Purpose**: Bitwarden CLI webhook provider for Vaultwarden integration

## Deployment Status

- ✅ External Secrets Operator deployed
- ✅ Vaultwarden provider configured
- ✅ ClusterSecretStores available
- ⏳ Ready for secret migration

## Available ClusterSecretStores

| Store Name                | Purpose                  | JSONPath                                     |
|---------------------------|--------------------------|----------------------------------------------|
| `vaultwarden-login`       | Username/password fields | `$.data.login.{property}`                    |
| `vaultwarden-fields`      | Custom fields            | `$.data.fields[?@.name=="{property}"].value` |
| `vaultwarden-notes`       | Notes field              | `$.data.notes`                               |
| `vaultwarden-attachments` | File attachments         | Direct download                              |

## Migration Strategy

### Phase 1: Coexistence (Current)
- SOPS secrets continue to work unchanged
- ESO deployed and ready for new secrets
- Both systems operational simultaneously

### Phase 2: New Secrets via ESO
- New applications use ESO for secret management
- Existing SOPS secrets remain untouched
- Gradual adoption of ESO patterns

### Phase 3: Gradual Migration
- Migrate non-critical secrets first
- Test ESO functionality thoroughly
- Maintain SOPS as fallback

### Phase 4: Full Migration (Optional)
- All secrets managed via ESO
- SOPS deprecated (can remain for Talos secrets)
- Simplified secret management workflow

## Usage Examples

### Basic ExternalSecret
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-secrets-eso
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vaultwarden-login
    kind: ClusterSecretStore
  target:
    name: app-secrets-eso
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: "item-id-from-vaultwarden"
        property: username
    - secretKey: password
      remoteRef:
        key: "item-id-from-vaultwarden"
        property: password
```

### Custom Fields Example
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-config-eso
  namespace: default
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: vaultwarden-fields
    kind: ClusterSecretStore
  target:
    name: app-config-eso
  data:
    - secretKey: api-key
      remoteRef:
        key: "item-id"
        property: "API_KEY"
    - secretKey: database-url
      remoteRef:
        key: "item-id"
        property: "DATABASE_URL"
```

## Best Practices

### Naming Conventions
- ESO-managed secrets: Use `-eso` suffix
- SOPS secrets: Keep existing `.sops.yaml` pattern
- Avoid naming conflicts during migration

### Security Considerations
- ESO secrets are dynamic and auto-refreshed
- SOPS secrets are static and git-committed
- Both use Kubernetes RBAC for access control
- Vaultwarden credentials stored in SOPS-encrypted secret

### Migration Guidelines
1. **Start with non-critical secrets**
2. **Test thoroughly in development**
3. **Maintain SOPS as backup during transition**
4. **Document secret sources clearly**
5. **Monitor ESO operator health**

## Troubleshooting

### Check ESO Status
```bash
kubectl get pods -n external-secrets-system
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

### Verify ClusterSecretStores
```bash
kubectl get clustersecretstores
kubectl describe clustersecretstore vaultwarden-login
```

### Test Vaultwarden Provider
```bash
kubectl get pods -l app.kubernetes.io/name=vaultwarden-provider
kubectl logs -l app.kubernetes.io/name=vaultwarden-provider
```

### Debug ExternalSecrets
```bash
kubectl get externalsecrets -A
kubectl describe externalsecret <name> -n <namespace>
```

## Support

For issues or questions:
1. Check ESO operator logs
2. Verify Vaultwarden connectivity
3. Validate secret store configurations
4. Review ExternalSecret specifications

## Migration Examples

### Example 1: Migrating a Simple Secret

**Before (SOPS):**
```yaml
# kubernetes/apps/myapp/app/secret.sops.yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
stringData:
  username: <encrypted>
  password: <encrypted>
```

**After (ESO):**
```yaml
# kubernetes/apps/myapp/app/externalsecret.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: myapp-secret-eso
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vaultwarden-login
    kind: ClusterSecretStore
  target:
    name: myapp-secret-eso
  data:
    - secretKey: username
      remoteRef:
        key: "myapp-credentials-item-id"
        property: username
    - secretKey: password
      remoteRef:
        key: "myapp-credentials-item-id"
        property: password
```

### Example 2: Complex Configuration Migration

**Before (SOPS):**
```yaml
# kubernetes/apps/database/app/config.sops.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-config
stringData:
  DATABASE_URL: <encrypted>
  API_KEY: <encrypted>
  SMTP_PASSWORD: <encrypted>
```

**After (ESO):**
```yaml
# kubernetes/apps/database/app/externalsecret.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-config-eso
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: vaultwarden-fields
    kind: ClusterSecretStore
  target:
    name: db-config-eso
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: "database-config-item-id"
        property: "DATABASE_URL"
    - secretKey: API_KEY
      remoteRef:
        key: "database-config-item-id"
        property: "API_KEY"
    - secretKey: SMTP_PASSWORD
      remoteRef:
        key: "smtp-config-item-id"
        property: "password"
```

## Step-by-Step Migration Process

### 1. Prepare Vaultwarden
1. Create items in Vaultwarden for your secrets
2. Note the item IDs (visible in Vaultwarden web interface)
3. Organize secrets logically (one item per application/service)

### 2. Create ExternalSecret
1. Create ExternalSecret manifest alongside existing SOPS secret
2. Use `-eso` suffix to avoid conflicts
3. Test with non-production workloads first

### 3. Update Application
1. Modify application to use new secret name
2. Deploy and verify functionality
3. Monitor for any issues

### 4. Cleanup (Optional)
1. Remove SOPS secret file after successful migration
2. Update kustomization.yaml to remove old secret
3. Commit changes

## References

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
- [AG-Talos-Kubernetes SOPS Documentation](../../.sops.yaml)
