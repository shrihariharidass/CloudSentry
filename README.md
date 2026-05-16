# ☁️ Cloud Custodian Dashboard

An open-source, real-time cloud governance and compliance monitoring platform built on top of [Cloud Custodian](https://github.com/cloud-custodian/cloud-custodian). Inspired by Stacklet — but fully free and self-hosted.

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Python](https://img.shields.io/badge/python-3.8%2B-green)
![Terraform](https://img.shields.io/badge/terraform-1.5%2B-purple)
![AWS](https://img.shields.io/badge/cloud-AWS-orange)

---

## 🎯 What Does This Do?

This project automatically detects and reports cloud resources that violate your governance policies — in near real-time.

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
├── policy.yml                         # Local testing policies
└── blog/                              # Blog documentation
    └── cloud-custodian-complete-guide.md
```

---

## 💰 Pricing (Estimated Monthly Cost)

| Resource | Purpose | Cost |
|----------|---------|------|
| CloudTrail (1 trail, management events) | API logging | **Free** |
| EventBridge (AWS service events) | Event routing | **Free** |
| Lambda (6 functions, ~5 min intervals) | Policy execution | **~$0.20** (free tier: 1M requests) |
| S3 (results + logs, ~1GB) | Storage | **~$0.50** |
| EC2 t3.micro (dashboard) | Web UI | **~$8.50** (free tier eligible) |
| IAM | Roles and policies | **Free** |
| CloudWatch Logs | Lambda logs | **~$0.50** (free tier: 5GB) |

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

- AWS Account with admin access (for initial setup)
- [Terraform](https://www.terraform.io/downloads) >= 1.5
- Python 3.8+
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- GitHub account

---

### 1. Clone the Repo

```bash
git clone https://github.com/shrihariharidass/cloudcustodian-UI.git
cd cloudcustodian-UI
```

---

### 2. Configure Variables

Edit `infra/variables.tf` with your values:

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

### 3. Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

This creates: S3 buckets, CloudTrail, EventBridge rules, IAM roles, EC2 instance, and security group.

Save the outputs:
```
dashboard_url        = "http://<ip>:5000"
lambda_role_arn      = "arn:aws:iam::<id>:role/CloudCustodianLambdaRole"
s3_results_bucket    = "custodian-results-<id>"
```

---

### 4. Setup the Dashboard EC2

SSH into the EC2 created by Terraform:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<dashboard_public_ip>
```

Run the setup script:

```bash
# Install system dependencies
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip git

# Clone repo (use your GitHub token for private repos)
cd /home/ubuntu
git clone https://github.com/shrihariharidass/cloudcustodian-UI.git
cd cloudcustodian-UI

# Create Python environment
python3 -m venv custodian
source custodian/bin/activate
pip install c7n
pip install -r frontend/requirements.txt

# Create systemd service for auto-start
sudo tee /etc/systemd/system/custodian-dashboard.service << 'EOF'
[Unit]
Description=Cloud Custodian Dashboard
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/cloudcustodian-UI/frontend
Environment=C7N_S3_BUCKET=custodian-results-<YOUR_ACCOUNT_ID>
Environment=C7N_S3_PREFIX=policies/
Environment=C7N_LOCAL_OUTPUT=../output
Environment=AWS_REGION=us-east-1
ExecStart=/home/ubuntu/cloudcustodian-UI/custodian/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the dashboard
sudo systemctl daemon-reload
sudo systemctl enable custodian-dashboard
sudo systemctl start custodian-dashboard
```

Visit `http://<dashboard_ip>:5000` — dashboard is live.

---

### 5. Create GitHub Actions Deploy User

Create IAM user `custodian-github-deploy` with these permissions:

- `AWSLambda_FullAccess` (managed policy)
- `CloudWatchEventsFullAccess` (managed policy)
- Custom policy for S3 + EC2 describe:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
            "Resource": [
                "arn:aws:s3:::custodian-results-<ACCOUNT_ID>",
                "arn:aws:s3:::custodian-results-<ACCOUNT_ID>/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": ["ec2:DescribeInstances", "iam:PassRole"],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": ["logs:CreateLogGroup", "logs:DescribeLogGroups"],
            "Resource": "*"
        }
    ]
}
```

Create access keys for this user.

---

### 6. Configure GitHub Secrets

Go to **GitHub repo → Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Deploy user access key |
| `AWS_SECRET_ACCESS_KEY` | Deploy user secret key |
| `AWS_ACCOUNT_ID` | Your AWS account ID (e.g., `858688858026`) |
| `EC2_SSH_KEY` | Full contents of your `.pem` private key file |
| `GH_USERNAME` | Your GitHub username |
| `GH_TOKEN` | GitHub Personal Access Token (repo scope) |

---

### 7. Deploy Policies

Trigger the workflow manually or push to `backend/policies/`:

**GitHub → Actions → "Deploy Cloud Custodian Policies" → Run workflow**

This deploys 6 Lambda functions that monitor your AWS account.

---

### 8. Test It

1. Create an EC2 instance **without** `Environment` and `Owner` tags
2. Wait 2-5 minutes
3. Refresh dashboard → **non-compliant** shown
4. Add the missing tags to the instance
5. Wait ~5 minutes
6. Refresh dashboard → **compliant** shown

---

## 🔄 CI/CD Workflows

| Workflow | File | Trigger | What It Does |
|----------|------|---------|--------------|
| Deploy Policies | `deploy-policies.yml` | Push to `backend/policies/` | Validates + deploys Lambda functions |
| Deploy Dashboard | `deploy-dashboard.yml` | Push to `frontend/` | SSH into EC2, git pull, restart service |
| Validate PR | `validate-pr.yml` | PR touching policies | Validates YAML + dry run scan |

All workflows also support manual trigger via `workflow_dispatch`.

---

## 📋 Policies Included

| Policy | Type | Trigger | What It Checks |
|--------|------|---------|----------------|
| `ec2-tag-enforcement-realtime` | Real-time | RunInstances | EC2 missing Environment/Owner tags |
| `s3-tag-enforcement-realtime` | Real-time | CreateBucket | S3 missing Environment/Owner tags |
| `ec2-compliance-rescan-on-tag` | Real-time | CreateTags/DeleteTags | Re-evaluates EC2 on tag changes |
| `ec2-missing-tags-scheduled` | Scheduled | Every 5 min | All running EC2 missing tags |
| `s3-encryption-check-scheduled` | Scheduled | Every 6 hours | S3 buckets without encryption |
| `ebs-unused-volumes-scheduled` | Scheduled | Every 12 hours | Unattached EBS volumes |

---

## 🖥️ Dashboard

The dashboard has 3 tabs:

**Compliance Status** — Current state from scheduled scans. Shows what's compliant right now.

**Real-time Events** — Audit log of resources caught at creation time. Historical record.

**CloudTrail Events** — Recent write API calls. Who did what and when.

The dashboard auto-refreshes every 30 seconds from S3.

---

## 🛠️ Useful Commands

```bash
# Local testing
custodian validate policy.yml
custodian run --dryrun -s output --cache-period 0 policy.yml

# Invoke Lambda manually
aws lambda invoke --function-name custodian-ec2-missing-tags-scheduled \
  --invocation-type Event /dev/null

# Check S3 results
aws s3 ls s3://custodian-results-<ACCOUNT_ID>/policies/ --recursive

# Read a specific result
aws s3 cp s3://custodian-results-<ID>/policies/ec2-missing-tags-scheduled/2026/05/16/08/resources.json.gz /tmp/r.gz
gunzip -f /tmp/r.gz && cat /tmp/r

# Dashboard management (on EC2)
sudo systemctl status custodian-dashboard
sudo systemctl restart custodian-dashboard
sudo journalctl -u custodian-dashboard --no-pager -n 30
```

---

## 🆚 This Project vs Stacklet (Commercial)

| Feature | This Project | Stacklet/Firefly |
|---------|-------------|-----------------|
| Policy engine | Cloud Custodian | Cloud Custodian |
| Real-time detection | ✅ CloudTrail + Lambda | ✅ |
| Dashboard | ✅ Custom Flask UI | ✅ Full SaaS |
| Multi-account | Manual (c7n-org) | Built-in |
| Cost | ~$10/month | $$$$/ month |
| Customization | Full control | Limited |
| Setup time | ~2 hours | Minutes |
| Self-hosted | ✅ | ❌ |
| Open source | ✅ Apache 2.0 | ❌ |

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Dashboard shows empty | Check S3 has results: `aws s3 ls s3://bucket/policies/` |
| Lambda not triggering | Verify CloudTrail is enabled + EventBridge rules exist |
| Permission denied | Check IAM role permissions |
| Dashboard not updating | `sudo systemctl restart custodian-dashboard` |
| Stale results after tagging | Wait 5 min for scheduled scan or invoke Lambda manually |
| GitHub Action SSH fails | Verify `EC2_SSH_KEY` has full PEM content including headers |
| Terraform state error | Check S3 backend bucket region in `main.tf` |
| `custodian validate` fails | Ensure YAML uses spaces (not tabs) and descriptions are quoted |

---

## 🔮 Future Enhancements

- Slack/Email notifications via `c7n-mailer`
- Multi-account support with `c7n-org`
- More policies (security groups, public RDS, unused ELBs)
- User authentication on dashboard
- Historical compliance trends and graphs
- Cost optimization reporting

---

## 📚 References

- [Cloud Custodian GitHub](https://github.com/cloud-custodian/cloud-custodian)
- [Cloud Custodian Docs](https://cloudcustodian.io/docs/)
- [AWS CloudTrail Pricing](https://aws.amazon.com/cloudtrail/pricing/)
- [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [CNCF Cloud Custodian](https://www.cncf.io/projects/cloud-custodian/)

---

## 📄 License

This project is licensed under the Apache 2.0 License.
