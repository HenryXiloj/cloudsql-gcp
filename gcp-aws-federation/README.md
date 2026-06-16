# AWS → Google Cloud Workload Identity Federation

Terraform that lets AWS workloads upload to a GCS bucket using Workload Identity Federation (WIF) — **no service account keys**.

A single WIF pool (`aws-wif-pool`) supports two authentication paths. Pick the one that matches how your workload gets its identity:

| Doc                          | Use when                                | Identity presented                                  | Required inputs                                     |
| ---------------------------- | --------------------------------------- | --------------------------------------------------- | --------------------------------------------------- |
| **[doc/eks.md](doc/eks.md)** | Workload runs on **EKS pods**           | Kubernetes ServiceAccount JWT (cluster OIDC issuer) | EKS OIDC issuer URL, namespace, ServiceAccount name |
| **[doc/ec2.md](doc/ec2.md)** | Workload runs on **EC2 / AWS IAM role** | AWS temporary credentials (STS)                     | AWS Account ID, IAM Role Name, IAM Role ARN         |

> On EKS, prefer the **Kubernetes OIDC** path (`doc/eks.md`). The AWS-IAM/IMDS path returns the node role, not the pod identity. Use `doc/ec2.md` for EC2 instances or when the workload genuinely authenticates with an AWS IAM role.

> ⚠️ All values in this repo are **dummy placeholders** (`000000000000`, `<aws-account-id>`, `example-*`, `aws-wif-pool`). Replace them with your real values before applying.

## Architecture

```text
              AWS side                          │                Google Cloud side
                                                │
  ┌──────────────────────────────┐              │
  │ EKS Pod                      │              │     apis.tf
  │  ServiceAccount: example-sa  │  K8s OIDC    │  enables iam / sts / iamcredentials /
  │  namespace:      example-ns  │ ─ JWT ───┐   │  cloudresourcemanager / storage
  └──────────────────────────────┘          │   │            │
                                            │   │            ▼
  ┌──────────────────────────────┐          │   │   ┌─────────────────────────────────┐
  │ EC2 / pod with IAM role      │  AWS STS │   │   │ aws-wif-pool.tf                 │
  │  role: example-gcp-upload-role│ ─ creds ┼───┼──▶│ WIF Pool: aws-wif-pool          │
  └──────────────────────────────┘          │   │   │  ├─ aws-provider     (aws {})   │◀── EC2 path
                                            └───┼──▶│  └─ eks-provider-*   (oidc {})  │◀── EKS path
                                                │   │      eks-identity-provider.tf   │
                                                │   └───────────────┬─────────────────┘
                                                │                   │ token exchange + impersonation
                                                │                   ▼
                                                │   ┌─────────────────────────────────┐
                                                │   │ GCP Service Account             │
                                                │   │  EKS → example-aws-wif-sa       │
                                                │   │  EC2 → example-aws-ec2-sa       │
                                                │   └───────────────┬─────────────────┘
                                                │                   │ roles/storage.objectCreator
                                                │                   ▼
                                                │   ┌─────────────────────────────────┐
                                                │   │ GCS bucket: example-test-bucket │
                                                │   └─────────────────────────────────┘
```

## Project structure

Read / deploy the files in this order — each layer builds on the one above it:

```text
1. provider.tf          providers (google, google-beta, ~> 6.0)
   variable.tf          input variable definitions
   terraform.tfvars     ← you edit this (project id/number, cluster, role, ...)

2. apis.tf              enable required GCP APIs (must come first)
        │
        ▼

3. aws-wif-pool.tf      the WIF pool + the AWS IAM provider (aws {})
        │
        ▼

4. eks-identity-provider.tf   the EKS OIDC provider(s) on that pool (oidc {})
        │
        ├─▶ 5a. example-aws-wif.tf   EKS path: SA + subject binding + bucket + grant
        │
        └─▶ 5b. example-aws-ec2.tf   EC2 path: SA + attribute.aws_role binding + grant
```

| #  | File                                                 | Purpose                                                                                   |
| -- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 1  | [provider.tf](provider.tf)                           | `google` + `google-beta` providers (`~> 6.0`)                                             |
| 1  | [variable.tf](variable.tf)                           | Input variable definitions                                                                |
| 1  | [terraform.tfvars](terraform.tfvars)                 | Variable values — **the only file you edit**                                              |
| 2  | [apis.tf](apis.tf)                                   | Enables `iam`, `sts`, `iamcredentials`, `cloudresourcemanager`, `storage` APIs            |
| 3  | [aws-wif-pool.tf](aws-wif-pool.tf)                   | WIF pool `aws-wif-pool` + AWS IAM provider (`aws {}`)                                     |
| 4  | [eks-identity-provider.tf](eks-identity-provider.tf) | EKS OIDC provider(s), one per `eks_clusters` entry (`oidc {}`)                            |
| 5a | [example-aws-wif.tf](example-aws-wif.tf)             | **EKS** example: SA, subject binding, test bucket + `objectCreator` grant                 |
| 5b | [example-aws-ec2.tf](example-aws-ec2.tf)             | **EC2/IAM** example: SA, `attribute.aws_role` principalSet binding, `objectCreator` grant |

> `depends_on` makes the pool, service accounts, and bucket wait for `apis.tf`; everything else is ordered automatically through references. You only need **5a** (EKS) or **5b** (EC2) — whichever path your workload uses.

## Setup

### 1. Prerequisites

* A Google Cloud project with billing enabled
* Terraform >= 1.3 (the `google`/`google-beta` providers are pinned to `~> 6.0`) and the `gcloud` CLI, authenticated with rights to manage IAM / WIF / service accounts:

```bash
gcloud auth application-default login
```

### 2. Configure `terraform.tfvars`

Replace every placeholder with your real values. All replaceable values live here — you do **not** need to edit any `.tf` file.

```hcl
project_id     = "your-project-id"      # GCP project ID
project_number = "000000000000"         # GCP project NUMBER (used in the WIF pool path)
region         = "us-central1"
zone           = "us-central1-a"

# --- EKS path only (doc/eks.md) ---
eks_clusters = {
  "example-dev" = {
    issuer_uri   = "https://oidc.eks.<my-region>.amazonaws.com/id/EXAMPLE0OIDCID"
    display_name = "Example EKS Dev Cluster"
    description  = "EKS OIDC Identity Provider"

    allowed_service_accounts = [
      "system:serviceaccount:example-ns:example-sa",
    ]
  }
}

example_eks_subjects = [
  "system:serviceaccount:example-ns:example-sa", # must match allowed_service_accounts
]

# --- EC2 / AWS IAM path only (doc/ec2.md) ---
aws_account_id        = "<aws-account-id>"     # AWS account the IAM role lives in
example_aws_role_name = "<aws-iam-role-name>"  # AWS IAM role NAME (not the ARN)
```

> Only filling one path? Leave the other path's variables at their defaults — an empty `eks_clusters` simply creates no EKS provider.

| Variable                                         | Required for | Notes                                                                   |
| ------------------------------------------------ | ------------ | ----------------------------------------------------------------------- |
| `project_id`, `project_number`, `region`, `zone` | always       | `project_number` is the numeric ID, not the string ID                   |
| `eks_clusters`                                   | EKS          | one entry per cluster; `allowed_service_accounts` gates the provider    |
| `example_eks_subjects`                           | EKS          | subjects bound for impersonation; must match `allowed_service_accounts` |
| `aws_account_id`                                 | EC2          | AWS account ID                                                          |
| `example_aws_role_name`                          | EC2          | IAM role name used in the `attribute.aws_role` binding                  |

### 3. Deploy

```bash
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

### 4. Next steps

Generate the credential config file and wire up the workload — see the per-path guide:

* **EKS pods** → [doc/eks.md](doc/eks.md)
* **EC2 / AWS IAM role** → [doc/ec2.md](doc/ec2.md)
