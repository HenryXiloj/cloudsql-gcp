# EC2 / AWS IAM → GCS Upload via Workload Identity Federation (AWS IAM)

Lets a workload running on **AWS EC2** (or any compute using an **AWS IAM role**) upload files to a **GCS bucket** with **no service account keys**.

> **Approach: AWS IAM (not Kubernetes OIDC).** The workload presents AWS temporary credentials from its IAM role; GCP validates the signed AWS STS/IAM request via the `aws {}` provider block, then exchanges it for a GCP token. **If you are on EKS pods using a Kubernetes ServiceAccount token instead, see [eks.md](eks.md).**

> ⚠️ All values here (`000000000000`, `<aws-account-id>`, `example-*`, `aws-wif-pool`) are **dummy placeholders**. Replace them before applying.

---

## Required inputs (provided by the AWS team)

| Item | Value |
|------|-------|
| AWS Account ID | `<aws-account-id>` |
| AWS IAM Role Name | `example-gcp-upload-role` |
| AWS IAM Role ARN | `arn:aws:iam::<aws-account-id>:role/example-gcp-upload-role` |

---

## Architecture

```
EC2 instance / pod (assumes IAM role: example-gcp-upload-role)
        |
        | AWS temporary credentials (STS)
        ↓
GCP WIF Pool (aws-wif-pool)
  Provider: aws-provider (aws {} block, account <aws-account-id>)
  - attribute.aws_role gates on the IAM role
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

## GCP Resources (this repo)

| File | Resources |
|------|-----------|
| [aws-wif-pool.tf](../aws-wif-pool.tf) | WIF pool `aws-wif-pool` + AWS IAM provider `aws-provider` (account `<aws-account-id>`) |
| [example-aws-ec2.tf](../example-aws-ec2.tf) | GCP service account `example-aws-ec2-sa`, `roles/iam.workloadIdentityUser` principalSet binding on `attribute.aws_role`, `roles/storage.objectCreator` grant on the test bucket |
| [example-aws-wif.tf](../example-aws-wif.tf) | The shared test bucket (`example-test-bucket`) |
| [apis.tf](../apis.tf) | Enables `iam`, `sts`, `iamcredentials`, `cloudresourcemanager`, `storage` APIs |

The WIF binding grants `roles/iam.workloadIdentityUser` to the AWS role via a **principalSet** on `attribute.aws_role`:

```
principalSet://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/attribute.aws_role/example-gcp-upload-role
```

**Access granted** — write-only:

| Action | Access |
|--------|--------|
| Upload / create objects | ✓ |
| List objects | ✗ |
| Read / download objects | ✗ |
| Delete objects | ✗ |

---

## Configuration

**`terraform.tfvars`** — everything replaceable lives here:

```hcl
project_id     = "your-project-id"
project_number = "000000000000"
region         = "us-central1"
zone           = "us-central1-a"

aws_account_id        = "<aws-account-id>"          # the AWS account the IAM role lives in
example_aws_role_name = "example-gcp-upload-role" # role name, used to build the principalSet binding
```

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

Run once after Terraform is deployed. The output file contains **no secrets** and is safe to share. The `--aws` flag selects the AWS credential source.

```bash
gcloud iam workload-identity-pools create-cred-config \
  projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/providers/aws-provider \
  --service-account=example-aws-ec2-sa@your-project-id.iam.gserviceaccount.com \
  --aws \
  --output-file=gcp.json
```

### EC2 node IAM role vs EKS IRSA

The same `--aws` command works for both — the difference is handled entirely by the AWS credential chain at runtime, **no Terraform or flag changes needed**:

- **EC2 / node IAM role** — the instance's IAM role (`example-gcp-upload-role`) is picked up from instance metadata.
- **EKS IRSA** — these are injected into the pod automatically:
  ```bash
  AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
  AWS_ROLE_ARN=arn:aws:iam::<aws-account-id>:role/example-gcp-upload-role
  AWS_ROLE_SESSION_NAME=...
  ```

---

## Using It

| Mode | Requirement |
|------|-------------|
| EC2 / node IAM role | The instance/node role must be `example-gcp-upload-role` |
| EKS IRSA | The Kubernetes ServiceAccount must be annotated with `example-gcp-upload-role` |

Make `gcp.json` available on the instance/pod, then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/gcp.json
```

Any Google client library exchanges the AWS credentials for a GCP access token using `gcp.json` automatically.

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
gcloud iam service-accounts describe example-aws-ec2-sa@your-project-id.iam.gserviceaccount.com

# WIF binding on the SA
gcloud iam service-accounts get-iam-policy example-aws-ec2-sa@your-project-id.iam.gserviceaccount.com
```

Expected binding (AWS role-based):

```yaml
bindings:
- members:
  - principalSet://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/attribute.aws_role/example-gcp-upload-role
  role: roles/iam.workloadIdentityUser
```

---

## WIF Pool Reference

| Item | Value |
|------|-------|
| WIF Project Number | `000000000000` |
| WIF Pool ID | `aws-wif-pool` |
| WIF Provider ID | `aws-provider` |
| AWS Account ID | `<aws-account-id>` |
| Principal Set | `principalSet://iam.googleapis.com/projects/000000000000/locations/global/workloadIdentityPools/aws-wif-pool/attribute.aws_role/example-gcp-upload-role` |

---

## References

- AWS/VM WIF: https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds
- Kubernetes WIF (for EKS pods using a ServiceAccount token): https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes
