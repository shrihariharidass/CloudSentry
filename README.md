# ☁️ CloudSentry

An open-source, real-time cloud governance and compliance monitoring platform built on [Cloud Custodian](https://github.com/cloud-custodian/cloud-custodian). Inspired by Stacklet — but fully free and self-hosted.

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Python](https://img.shields.io/badge/python-3.8%2B-green)
![Terraform](https://img.shields.io/badge/terraform-1.5%2B-purple)
![AWS](https://img.shields.io/badge/cloud-AWS-orange)

---

## 🎯 What Does This Do?

CloudSentry automatically detects and reports cloud resources that violate your governance policies — in near real-time.

**Example:** Someone creates an EC2 instance without `Environment` and `Owner` tags → within 2-5 minutes, the dashboard shows it as non-compliant. They add the tags → within 5 minutes, it shows compliant again.

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                            AWS Account                                │
│                                                                       │
│   User creates EC2/S3                                                │
│         │                                                             │
│         ▼                                                             │
│   ┌────────────┐    ┌──────────────┐    ┌─────────────────────┐      │
│   │ CloudTrail │───▶│ EventBridge  │───▶│ Lambda (Cloud       │      │
│   │ (API logs) │    │ (Event rules)│    │ Custodian policies) │      │
│   └────────────┘    └──────────────┘    └──────────┬──────────┘      │
│                                                     │                 │
│                                                     ▼                 │
│   ┌─────────────────┐              ┌───────────────────────┐         │
│   │ Dashboard (EC2) │◀─── reads ───│ S3 (Results + Logs)   │         │
│   │ Flask + Gunicorn │              │ Encrypted, versioned  │         │
│   │ Port 5000        │              └───────────────────────┘         │
│   └─────────────────┘                                                │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘

CI/CD: GitHub Actions → Deploys policies (Lambda) + Dashboard (EC2)
Infra: Terraform → Manages all AWS resources
```

---

## ✨ Features

- **Real-time detection** — CloudTrail + EventBridge triggers Lambda within 2-5 min
- **Tag compliance** — Detects missing `Environment` and `Owner` tags on EC2/S3
- **Auto-remediation** — Tags non-compliant resources automatically
- **Near real-time updates** — Scheduled scans every 5 minutes
- **Tag change detection** — Catches both tag additions and removals
- **Web dashboard** — Dark-themed UI with auto-refresh every 30 seconds
- **3 dashboard views** — Compliance Status, Real-time Events (audit log), CloudTrail Events
- **CI/CD pipeline** — GitHub Actions auto-deploys on push
- **Infrastructure as Code** — Full Terraform for all AWS resources
- **S3-backed storage** — Encrypted, versioned, with lifecycle policies

---

## 📁 Project Structure

```
.
├── frontend/                          # Dashboard web application
│   ├── app.py                         # Flask app (S3 reader + CloudTrail API)
│   ├── templates/
│   │   └── index.html                 # Dashboard UI (dark theme, 3 tabs)
│   ├── Dockerfile                     # Optional container deployment
│   └── requirements.txt               # Python dependencies
│
├── backend/                           # Cloud Custodian policy definitions
│   └── policies/
│       ├── realtime-tag-enforcement.yml   # Triggers: RunInstances, CreateBucket
│       ├── tag-change-rescan.yml          # Triggers: CreateTags, DeleteTags
│       └── scheduled-scan.yml             # Runs every 5 min (EC2, S3, EBS)
│
├── infra/                             # Terraform infrastructure
│   ├── main.tf                        # Provider + S3 backend
│   ├── variables.tf                   # Configurable values
│   ├── iam.tf                         # IAM roles (Lambda, Dashboard, Deploy)
│   ├── s3.tf                          # S3 buckets (results + CloudTrail logs)
│   ├── cloudtrail.tf                  # CloudTrail + EventBridge rules
│   ├── ec2.tf                         # Dashboard EC2 + Security Group
│   └── outputs.tf                     # Terraform outputs
│
├── .github/workflows/                 # CI/CD pipelines
│   ├── deploy-policies.yml            # Auto-deploy Lambda on policy changes
│   ├── deploy-dashboard.yml           # Auto-deploy dashboard on frontend changes
│   └── validate-pr.yml                # Validate policies on pull requests
│
├── .env.example                       # Environment variable template
├── policy.yml                         # Local testing policies
├── CONTRIBUTING.md                    # Contribution guidelines
├── CODE_OF_CONDUCT.md                 # Community code of conduct
└── LICENSE                            # Apache 2.0
```

---

## 💰 Pricing (Estimated Monthly Cost)

| Resource | Purpose | Cost |
|----------|---------|------|
| CloudTrail (1 trail, management events) | API logging | **Free** |
| EventBridge (AWS service events) | Event routing | **Free** |
| Lambda (6 functions, ~5 min intervals) | Policy execution | **~$0.20** |
| S3 (results + logs) | Storage | **~$0.50** |
| EC2 t3.micro (dashboard) | Web UI | **~$8.50** (free tier eligible) |
| IAM | Roles and policies | **Free** |
| CloudWatch Logs | Lambda logs | **~$0.50** |

| **Total** | | **~$10/month** (or ~$0 with free tier) |
|-----------|--|----------------------------------------|

---

## 🔒 Security

| Layer | Implementation |
|-------|---------------|
| IAM | Least-privilege roles for Lambda, Dashboard, and CI/CD |
| S3 | AES-256 encryption, public access blocked, versioning enabled |
| EC2 | Instance profile (no hardcoded keys), security group restricted |
| CI/CD | AWS keys stored as GitHub encrypted secrets |
| Data | Results auto-expire after 90 days via lifecycle policy |
| Network | Only ports 22 (SSH) and 5000 (dashboard) open |

---

## 🚀 Quick Start

### Prerequisites

- AWS Account
- [Terraform](https://www.terraform.io/downloads) >= 1.5
- Python 3.8+
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- GitHub account

---

### 1. Clone the Repo

```bash
git clone https://github.com/shrihariharidass/CloudSentry.git
cd CloudSentry
```

---

### 2. Copy Environment Template

```bash
cp .env.example .env
# Edit .env with your AWS account details
```

---

### 3. Configure Terraform Variables

Edit `infra/variables.tf`:

```hcl
variable "account_id" {
  default = "YOUR_AWS_ACCOUNT_ID"
}

variable "vpc_id" {
  default = "vpc-xxxxxxxx"
}

variable "subnet_id" {
  default = "subnet-xxxxxxxx"
}

variable "key_name" {
  default = "your-key-pair-name"
}
```

---

### 4. Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

This creates: S3 buckets, CloudTrail, EventBridge rules, IAM roles, EC2 instance, and security group.

---

### 5. Setup the Dashboard EC2

SSH into the EC2:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<dashboard_public_ip>
```

```bash
# Install dependencies
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip git

# Clone and setup
cd /home/ubuntu
git clone https://github.com/shrihariharidass/CloudSentry.git
cd CloudSentry
python3 -m venv custodian
source custodian/bin/activate
pip install c7n
pip install -r frontend/requirements.txt

# Create systemd service
sudo tee /etc/systemd/system/cloudsentry.service << 'EOF'
[Unit]
Description=CloudSentry Dashboard
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/CloudSentry/frontend
Environment=C7N_S3_BUCKET=custodian-results-<YOUR_ACCOUNT_ID>
Environment=C7N_S3_PREFIX=policies/
Environment=C7N_LOCAL_OUTPUT=../output
Environment=AWS_REGION=us-east-1
ExecStart=/home/ubuntu/CloudSentry/custodian/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloudsentry
sudo systemctl start cloudsentry
```

---

### 6. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Deploy user access key |
| `AWS_SECRET_ACCESS_KEY` | Deploy user secret key |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `EC2_SSH_KEY` | Contents of your `.pem` private key |
| `GH_USERNAME` | Your GitHub username |
| `GH_TOKEN` | GitHub Personal Access Token |

---

### 7. Deploy Policies

**GitHub → Actions → "Deploy Cloud Custodian Policies" → Run workflow**

---

### 8. Test It

1. Create an EC2 without `Environment` and `Owner` tags
2. Wait 2-5 minutes → dashboard shows **non-compliant**
3. Add the tags → wait 5 minutes → dashboard shows **compliant**

---

## 🔄 CI/CD Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| Deploy Policies | Push to `backend/policies/` | Deploys Lambda functions |
| Deploy Dashboard | Push to `frontend/` | Updates EC2 dashboard |
| Validate PR | PR touching policies | Validates YAML + dry run |

---

## 📋 Policies Included

| Policy | Type | Trigger | Checks |
|--------|------|---------|--------|
| `ec2-tag-enforcement-realtime` | Real-time | RunInstances | EC2 missing tags |
| `s3-tag-enforcement-realtime` | Real-time | CreateBucket | S3 missing tags |
| `ec2-compliance-rescan-on-tag` | Real-time | CreateTags/DeleteTags | Re-evaluates on tag changes |
| `ec2-missing-tags-scheduled` | Scheduled | Every 5 min | All running EC2 |
| `s3-encryption-check-scheduled` | Scheduled | Every 6 hours | S3 without encryption |
| `ebs-unused-volumes-scheduled` | Scheduled | Every 12 hours | Unattached EBS volumes |

---

## 🆚 CloudSentry vs Stacklet (Commercial)

| Feature | CloudSentry | Stacklet/Firefly |
|---------|-------------|-----------------|
| Policy engine | Cloud Custodian | Cloud Custodian |
| Real-time detection | ✅ | ✅ |
| Dashboard | ✅ Self-hosted | ✅ SaaS |
| Multi-account | Manual (c7n-org) | Built-in |
| Cost | ~$10/month | $$$$/ month |
| Customization | Full control | Limited |
| Open source | ✅ Apache 2.0 | ❌ |

---

## 🛠️ Useful Commands

```bash
# Validate policies locally
custodian validate policy.yml

# Dry run
custodian run --dryrun -s output --cache-period 0 policy.yml

# Invoke Lambda manually
aws lambda invoke --function-name custodian-ec2-missing-tags-scheduled \
  --invocation-type Event /dev/null

# Check results in S3
aws s3 ls s3://custodian-results-<ACCOUNT_ID>/policies/ --recursive

# Dashboard management
sudo systemctl restart cloudsentry
sudo journalctl -u cloudsentry --no-pager -n 30
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Dashboard empty | Check S3: `aws s3 ls s3://bucket/policies/` |
| Lambda not triggering | Verify CloudTrail + EventBridge rules |
| Permission denied | Check IAM role permissions |
| Stale results | Wait 5 min or invoke Lambda manually |
| GitHub Action SSH fails | Check `EC2_SSH_KEY` secret format |

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📄 License

Apache 2.0 — see [LICENSE](LICENSE) for details.

---

## ⭐ Star This Repo

If you find CloudSentry useful, give it a star! It helps others discover the project.
