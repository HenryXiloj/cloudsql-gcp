# EKS → GCS Upload via Workload Identity Federation (Kubernetes OIDC)

Lets a workload running on **AWS EKS** upload files to a **GCS bucket** with **no service account keys**.

> **Approach: Kubernetes OIDC (not AWS IAM).** EKS pods authenticate with a projected Kubernetes ServiceAccount JWT signed by the cluster's own OIDC issuer — not with an AWS IAM credential. Google routes EKS/AKS workloads to the [Kubernetes federation path](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes), not the [AWS/VM path](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds). An AWS-IAM/IMDS approach fails because IMDS on EKS returns the node role, not the pod identity. **If you authenticate with an AWS IAM role instead, see [ec2.md](ec2.md).**

> ⚠️ All values here (`000000000000`, `EXAMPLE0OIDCID`, `example-*`, `aws-wif-pool`, `<my-region>`) are **dummy placeholders**. Replace them before applying.

---

## Architecture

```
EKS Pod (ServiceAccount: example-sa, namespace: example-ns)
        |
        | projected Kubernetes ServiceAccount JWT (audience = provider URL)
        ↓
GCP WIF Pool (aws-wif-pool)
  Provider: eks-provider-example-dev (OIDC)
  - issuer_uri = EKS cluster OIDC issuer
  - attribute_condition gates on assertion.sub
        |
        | token exchange + impersonation
        ↓
GCP Service Account (example-aws-wif-sa)
        |
        | roles/storage.objectCreator
        ↓
GCS bucket (example-test-bucket)
```

---

## EKS Details

| Item | Value |
|------|-------|
| Cluster key | `example-dev` |
| OIDC issuer URL | `https://oidc.eks.<my-region>.amazonaws.com/id/EXAMPLE0OIDCID` |
| Namespace | `example-ns` |
| Kubernetes ServiceAccount | `example-sa` |
| Full subject | `system:serviceaccount:example-ns:example-sa` |

---

## GCP Resources (this repo)

| File | Resources |
|------|-----------|
| [aws-wif-pool.tf](../aws-wif-pool.tf) | WIF pool `aws-wif-pool` + AWS IAM provider |
| [eks-identity-provider.tf](../eks-identity-provider.tf) | EKS OIDC provider(s), one per `eks_clusters` entry via `for_each` |
| [example-aws-wif.tf](../example-aws-wif.tf) | GCP service account, `roles/iam.workloadIdentityUser` binding, test bucket + `roles/storage.objectCreator` grant |
| [apis.tf](../apis.tf) | Enables `iam`, `sts`, `iamcredentials`, `cloudresourcemanager`, `storage` APIs |

**EKS OIDC provider** — `google.subject = assertion.sub` (+ namespace / service_account_name); `attribute_condition` accepts only the listed `allowed_service_accounts`.

**Access granted** — write-only:

| Action | Access |
|--------|--------|
| Upload / create objects | ✓ |
| List objects | ✗ |
| Read / download objects | ✗ |
| Delete objects | ✗ |

---

## Configuration

**`terraform.tfvars`**

```hcl
project_id     = "your-project-id"
project_number = "000000000000"
region         = "us-central1"
zone           = "us-central1-a"

eks_clusters = {
  "example-dev" = {
    issuer_uri   = "https://oidc.eks.<my-region>.amazonaws.com/id/EXAMPLE0OIDCID"
    display_name = "Example EKS Dev Cluster"
    description  = "EKS OIDC Identity Provider for the example team"
    allowed_service_accounts = [
      "system:serviceaccount:example-ns:example-sa",
    ]
  }
}

example_eks_subjects = [
  "system:serviceaccount:example-ns:example-sa",
]
```

> The subject in `example_eks_subjects` (binds impersonation) and `allowed_service_accounts` (gates the provider) **must match exactly**.

**Adding more:**

| Scenario | Change |
|----------|--------|
| New namespace/ServiceAccount, same cluster | add a line to both `example_eks_subjects` and `allowed_service_accounts` |
| New EKS cluster | add a new entry to `eks_clusters` (its own issuer URL) |

---

## Deploy

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

---

## Generating the Credential Config File

Run once after the OIDC provider is deployed. The output file contains **no secrets** and is safe to share. `--sts-location` is optional.

**Global STS (recommended)**

```bash
gcloud iam workload-identity-pools create-cred-config \
  projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/providers/eks-provider-example-dev \
  --service-account=example-aws-wif-sa@your-project-id.iam.gserviceaccount.com \
  --credential-source-file=/var/run/service-account/token \
  --credential-source-type=text \
  --output-file=gcp.json
```

Resulting JSON: `"token_url": "https://sts.googleapis.com/v1/token"`

> **Regional STS (optional):** add `--sts-location=<my-region>` only if you have a data-residency / VPC-SC requirement (token_url becomes `https://sts.<my-region>.rep.googleapis.com/v1/token`). Needs a recent gcloud.

---

## Using It From EKS

EKS needs **no cluster-side OIDC config change** (per Google's docs). Two things must be present in the pod:

1. A **projected ServiceAccount token** (audience = the provider URL) at `/var/run/service-account/token`.
2. The **`gcp.json`** credential config, with `GOOGLE_APPLICATION_CREDENTIALS` pointing at it.

**Provider URL / audience:**

```
https://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/providers/eks-provider-example-dev
```

### Constraints (a mismatch = silent auth failure)

| # | Requirement |
|---|-------------|
| 1 | Pod runs in namespace `example-ns` (the `<namespace>` half of the bound subject) |
| 2 | `serviceAccountName: example-sa` (the `<name>` half) |
| 3 | `mountPath: /var/run/service-account` → token at `/var/run/service-account/token`, matching `--credential-source-file` |
| 4 | Projected token `audience` exactly equals the provider URL |

### Step 1 — make `gcp.json` available

`gcp.json` holds no secrets, so a ConfigMap is fine (a Secret or AWS Secrets Manager + External Secrets Operator also work):

```bash
kubectl -n example-ns create configmap gcp-cred-config \
  --from-file=gcp.json=./gcp.json
```

### Step 2 — pod spec

```yaml
spec:
  serviceAccountName: example-sa
  volumes:
    - name: gcp-token
      projected:
        sources:
          - serviceAccountToken:
              audience: "https://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/providers/eks-provider-example-dev"
              expirationSeconds: 3600
              path: token
    - name: gcp-cred-config
      configMap:
        name: gcp-cred-config
  containers:
    - name: app
      env:
        - name: GOOGLE_APPLICATION_CREDENTIALS
          value: /var/run/gcp/gcp.json
      volumeMounts:
        - name: gcp-token
          mountPath: /var/run/service-account
          readOnly: true
        - name: gcp-cred-config
          mountPath: /var/run/gcp
          readOnly: true
```

Once mounted, any Google client library reads the projected token and exchanges it for a GCP access token automatically.

### Upload — client library (Python)

```python
from google.cloud import storage   # GOOGLE_APPLICATION_CREDENTIALS set by the pod spec
client = storage.Client()
```

### Upload — REST API

```
POST https://storage.googleapis.com/upload/storage/v1/b/example-test-bucket/o?uploadType=media&name=incoming/example_YYYY-MM-DD_NNN.txt
Authorization: Bearer <GCP_ACCESS_TOKEN>
Content-Type: text/plain
```

### Upload — gcloud (testing only)

```bash
gcloud auth login --cred-file=/path/to/gcp.json
gcloud storage cp ./example_2026-06-11_001.txt gs://example-test-bucket/incoming/example_2026-06-11_001.txt
```

---

## Verification

```bash
# SA exists
gcloud iam service-accounts describe example-aws-wif-sa@your-project-id.iam.gserviceaccount.com

# WIF binding on the SA
gcloud iam service-accounts get-iam-policy example-aws-wif-sa@your-project-id.iam.gserviceaccount.com
```

Expected binding:

```yaml
bindings:
- members:
  - principal://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/subject/system:serviceaccount:example-ns:example-sa
  role: roles/iam.workloadIdentityUser
```

---

## Troubleshooting

**Reach Google APIs from inside the pod** (a hang/timeout = blocked egress, fix that first):

```bash
curl -I https://sts.googleapis.com               # token exchange
curl -I https://iamcredentials.googleapis.com    # SA impersonation
curl -I https://storage.googleapis.com           # the upload
```

**Confirm the projected token** — `cat /var/run/service-account/token` should print a JWT whose `aud` matches the provider URL and `sub` is `system:serviceaccount:example-ns:example-sa`.

| Error | Likely cause |
|-------|--------------|
| `Unable to retrieve AWS role name` | Using an AWS/IMDS `gcp.json` — must use the OIDC one |
| `iam.serviceAccounts.getAccessToken denied` | `serviceAccountName` / token `sub` doesn't match the bound subject |
| Provider rejects token | `audience` doesn't exactly match the provider URL |
| `403` on upload | Auth worked, but writing outside `objectCreator` scope (list/read/delete) |
| Connection hangs | Egress to Google APIs blocked |

---

## WIF Pool Reference

| Item | Value |
|------|-------|
| WIF Project Number | `000000000000` |
| WIF Pool ID | `aws-wif-pool` |
| EKS Provider ID | `eks-provider-example-dev` |
| Provider audience | `https://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/providers/eks-provider-example-dev` |
| Principal (member) | `principal://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/subject/system:serviceaccount:example-ns:example-sa` |

---

## References

- Kubernetes WIF (EKS tab): https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes
- AWS/VM WIF (not used for EKS pods): https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds
