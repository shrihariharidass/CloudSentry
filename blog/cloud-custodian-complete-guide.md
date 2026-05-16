# Building an Open-Source Cloud Governance Dashboard with Cloud Custodian

> A Stacklet-like real-time compliance monitoring platform using Cloud Custodian, AWS Lambda, CloudTrail, and a custom Flask dashboard — fully open source.

---

## What is Cloud Custodian?

Cloud Custodian (c7n) is a CNCF Incubating open-source project. It's a rules engine that lets you write cloud governance policies in simple YAML. Think of it as "compliance as code" — you define what's allowed, and custodian enforces it automatically.

Stacklet (now Firefly) built a commercial platform on top of it. We're building our own open-source version.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Account                                     │
│                                                                              │
│  ┌──────────┐     ┌────────────┐     ┌──────────────┐     ┌──────────────┐ │
│  │  User     │────▶│ CloudTrail │────▶│  EventBridge │────▶│   Lambda     │ │
│  │ (Creates  │     │ (Logs API  │     │  (Rules for  │     │ (Runs c7n    │ │
│  │  EC2/S3)  │     │  calls)    │     │  RunInstances│     │  policies)   │ │
│  └──────────┘     └────────────┘     │  CreateTags  │     └──────┬───────┘ │
│                                       │  DeleteTags  │            │          │
│                                       │  CreateBucket│            ▼          │
│                                       └──────────────┘     ┌──────────────┐ │
│                                                            │  S3 Bucket   │ │
│  ┌──────────────┐     ┌──────────────┐                     │  (Results +  │ │
│  │  Dashboard   │◀────│  Auto-refresh│◀────────────────────│   Logs)      │ │
│  │  (Flask on   │     │  every 30s   │                     └──────────────┘ │
│  │   EC2)       │     └──────────────┘                                      │
│  └──────────────┘                                                           │
│         ▲                                                                    │
│         │                                                                    │
│  ┌──────────────┐                                                           │
│  │ GitHub Actions│ ── Deploys policies (Lambda) + Dashboard (EC2)           │
│  └──────────────┘                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Features

| Feature | Description |
|---|---|
| Real-time detection | CloudTrail + EventBridge triggers Lambda within 2-5 min of resource creation |
| Tag compliance | Detects missing `Environment` and `Owner` tags on EC2 and S3 |
| Auto-remediation | Tags non-compliant resources with `custodian-compliance: non-compliant-missing-tags` |
| Scheduled scans | Every 5 minutes for near real-time compliance status |
| Tag change detection | Detects both `CreateTags` and `DeleteTags` events |
| Web dashboard | Flask UI with auto-refresh, shows current compliance + audit log |
| CloudTrail viewer | See recent write events directly in the dashboard |
| CI/CD pipeline | GitHub Actions auto-deploys policies and dashboard on push |
| Infrastructure as Code | Full Terraform setup for all AWS resources |
| S3-backed results | All scan results stored in S3 with lifecycle policies |

---

## AWS Resources Used

| Resource | Purpose | Pricing |
|---|---|---|
| CloudTrail | Captures all API calls (management events) | Free (1 trail, management events) |
| EventBridge | Routes CloudTrail events to Lambda | Free (AWS service events) |
| Lambda (x6 functions) | Runs c7n policies | Free tier: 1M requests/month + 400K GB-seconds. ~$0.20/month after |
| S3 (results bucket) | Stores policy scan results | ~$0.023/GB/month. Minimal for JSON files (~$0.01/month) |
| S3 (CloudTrail logs) | Stores CloudTrail logs | ~$0.023/GB/month (~$0.50-1/month) |
| EC2 t3.micro (dashboard) | Hosts the Flask dashboard | ~$8.50/month (or free tier eligible) |
| IAM | Roles and policies | Free |
| CloudWatch Logs | Lambda execution logs | Free tier: 5GB. ~$0.50/GB after |

### Estimated Monthly Cost

| Scenario | Cost |
|---|---|
| Free tier (first 12 months) | ~$0 - $1/month |
| After free tier | ~$10 - $12/month |
| Production (larger instance) | ~$20 - $30/month |

CloudTrail management events are free for the first trail. Lambda free tier covers most demo/small workloads easily.

---

## Security Posture

| Layer | Implementation |
|---|---|
| IAM Least Privilege | Separate roles for Lambda, Dashboard, and GitHub Actions deploy user |
| S3 Encryption | AES-256 server-side encryption on all buckets |
| S3 Public Access | Blocked on all buckets |
| EC2 Instance Profile | Dashboard uses IAM role (no hardcoded credentials) |
| Security Group | Port 5000 (dashboard) + Port 22 (SSH) only |
| GitHub Secrets | AWS keys and SSH keys stored as encrypted secrets |
| No Admin Access | All users/roles have scoped permissions |
| Versioned S3 | Results bucket has versioning enabled |
| Lifecycle Policies | Auto-expire old results after 90 days |

---

## Project Structure

```
cloudcustodian-UI/
├── frontend/                    # Dashboard UI
│   ├── app.py                   # Flask app (reads S3 + CloudTrail)
│   ├── templates/
│   │   └── index.html           # Dark-themed dashboard UI
│   ├── Dockerfile               # Container deployment option
│   └── requirements.txt
├── backend/                     # Cloud Custodian policies
│   └── policies/
│       ├── realtime-tag-enforcement.yml   # Triggers on RunInstances/CreateBucket
│       ├── tag-change-rescan.yml          # Triggers on CreateTags/DeleteTags
│       └── scheduled-scan.yml             # Runs every 5 minutes
├── infra/                       # Terraform
│   ├── main.tf                  # Provider + backend config
│   ├── variables.tf             # Configurable variables
│   ├── iam.tf                   # IAM roles and policies
│   ├── s3.tf                    # S3 buckets (results + CloudTrail)
│   ├── cloudtrail.tf            # CloudTrail + EventBridge rules
│   ├── ec2.tf                   # Dashboard EC2 instance
│   └── outputs.tf               # Terraform outputs
├── .github/workflows/           # CI/CD
│   ├── deploy-policies.yml      # Auto-deploy Lambda policies
│   ├── deploy-dashboard.yml     # Auto-deploy dashboard to EC2
│   └── validate-pr.yml          # PR validation
├── policy.yml                   # Local testing policies
└── README.md
```

---

## Step-by-Step Setup

### Prerequisites

- AWS Account
- Terraform installed locally
- Python 3.8+
- GitHub account
- AWS CLI configured with admin access (for initial setup)

---

### Step 1: Clone the Repository

```bash
git clone https://github.com/shrihariharidass/cloudcustodian-UI.git
cd cloudcustodian-UI
```

---

### Step 2: Create IAM Users and Roles

#### 2.1 GitHub Actions Deploy User

Create a user `custodian-github-deploy` with this policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LambdaFullAccess",
            "Effect": "Allow",
            "Action": "lambda:*",
            "Resource": "arn:aws:lambda:us-east-1:<ACCOUNT_ID>:function:custodian-*"
        },
        {
            "Sid": "IAMPassRole",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::<ACCOUNT_ID>:role/CloudCustodianLambdaRole"
        },
        {
            "Sid": "EventBridge",
            "Effect": "Allow",
            "Action": "events:*",
            "Resource": "arn:aws:events:us-east-1:<ACCOUNT_ID>:rule/custodian-*"
        },
        {
            "Sid": "S3Access",
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
            "Resource": [
                "arn:aws:s3:::custodian-results-<ACCOUNT_ID>",
                "arn:aws:s3:::custodian-results-<ACCOUNT_ID>/*"
            ]
        },
        {
            "Sid": "EC2Describe",
            "Effect": "Allow",
            "Action": "ec2:DescribeInstances",
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchLogs",
            "Effect": "Allow",
            "Action": ["logs:CreateLogGroup", "logs:DescribeLogGroups"],
            "Resource": "*"
        }
    ]
}
```

Create access keys for this user.

#### 2.2 Lambda Execution Role (created by Terraform)

The `CloudCustodianLambdaRole` is created by Terraform with:
- EC2 Describe + CreateTags
- S3 Read + Write (results bucket)
- CloudTrail Read
- CloudWatch Logs
- EBS Describe
- IAM Read
- Tag operations

#### 2.3 Dashboard Role (created by Terraform)

The `CloudCustodianDashboardRole` is created by Terraform with:
- S3 Read (results bucket)
- CloudTrail LookupEvents (read-only)

Attach `AmazonS3ReadOnlyAccess` managed policy for broader S3 read access.

---

### Step 3: Deploy Infrastructure with Terraform

```bash
cd infra

# Update variables.tf with your values:
# - account_id
# - vpc_id
# - subnet_id
# - key_name (your EC2 key pair)

terraform init
terraform plan
terraform apply
```

Terraform creates:
- S3 bucket for results (`custodian-results-<account_id>`)
- S3 bucket for CloudTrail logs
- CloudTrail trail (write events only)
- EventBridge rule for EC2 launches
- IAM roles (Lambda + Dashboard)
- EC2 instance with security group
- Instance profile for dashboard

Save the outputs:
```
dashboard_url = "http://<ip>:5000"
lambda_role_arn = "arn:aws:iam::<id>:role/CloudCustodianLambdaRole"
s3_results_bucket = "custodian-results-<id>"
```

---

### Step 4: Setup EC2 Dashboard

SSH into the new EC2:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<dashboard_public_ip>
```

Run the setup:

```bash
# Install dependencies
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip git

# Clone repo
cd /home/ubuntu
git clone https://<github-token>@github.com/shrihariharidass/cloudcustodian-UI.git
cd cloudcustodian-UI

# Create venv and install
python3 -m venv custodian
source custodian/bin/activate
pip install c7n
pip install -r frontend/requirements.txt

# Create systemd service
sudo tee /etc/systemd/system/custodian-dashboard.service << 'EOF'
[Unit]
Description=Cloud Custodian Dashboard
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/cloudcustodian-UI/frontend
Environment=C7N_S3_BUCKET=custodian-results-<ACCOUNT_ID>
Environment=C7N_S3_PREFIX=policies/
Environment=C7N_LOCAL_OUTPUT=../output
Environment=AWS_REGION=us-east-1
ExecStart=/home/ubuntu/cloudcustodian-UI/custodian/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start
sudo systemctl daemon-reload
sudo systemctl enable custodian-dashboard
sudo systemctl start custodian-dashboard
```

Dashboard is now live at `http://<ip>:5000`

---

### Step 5: Configure GitHub Secrets

Go to **GitHub repo → Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Deploy user access key |
| `AWS_SECRET_ACCESS_KEY` | Deploy user secret key |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `EC2_SSH_KEY` | Full contents of your .pem private key |
| `GH_USERNAME` | Your GitHub username |
| `GH_TOKEN` | GitHub Personal Access Token |

---

### Step 6: Deploy Policies via GitHub Actions

Push to `backend/policies/` or manually trigger:

**GitHub → Actions → Deploy Cloud Custodian Policies → Run workflow**

This deploys 6 Lambda functions:
- `custodian-ec2-tag-enforcement-realtime` (triggers on RunInstances)
- `custodian-s3-tag-enforcement-realtime` (triggers on CreateBucket)
- `custodian-ec2-compliance-rescan-on-tag` (triggers on CreateTags/DeleteTags)
- `custodian-ec2-missing-tags-scheduled` (every 5 min)
- `custodian-s3-encryption-check-scheduled` (every 6 hours)
- `custodian-ebs-unused-volumes-scheduled` (every 12 hours)

---

### Step 7: Test the Flow

1. **Create an EC2 instance without `Environment` and `Owner` tags**
2. Wait 2-5 minutes
3. Refresh dashboard → shows non-compliant
4. **Add the missing tags** to the instance
5. Wait 5 minutes (scheduled scan)
6. Refresh dashboard → shows compliant

---

## Dashboard Features

### Tab 1: Compliance Status
- Shows current state from scheduled scans
- Summary cards: Total policies, Compliant, Non-compliant, Violations
- Expandable policy cards with resource details
- Auto-refreshes every 30 seconds

### Tab 2: Real-time Events
- Audit log of resources caught at creation time
- Historical record (doesn't change when remediated)
- Shows what was non-compliant and when

### Tab 3: CloudTrail Events
- Recent write events (resource changes)
- Shows who did what and when
- Useful for debugging and auditing

---

## How It Works (Flow)

### Detection Flow (Resource Created Without Tags)

```
1. User creates EC2 without Environment/Owner tags
2. CloudTrail logs the RunInstances API call (~1-2 min)
3. EventBridge rule matches the event
4. Lambda function triggered (custodian-ec2-tag-enforcement-realtime)
5. c7n evaluates the instance against filters
6. Instance matches (tags absent) → tagged as non-compliant
7. Results written to S3 (resources.json.gz)
8. Dashboard reads from S3 on next refresh (30s)
9. Dashboard shows violation
```

### Remediation Flow (Tags Added)

```
1. User adds Environment and Owner tags
2. CloudTrail logs the CreateTags API call
3. EventBridge triggers rescan Lambda
4. Scheduled scan also runs every 5 min
5. c7n evaluates → instance now has tags → no match
6. Empty results written to S3 ([])
7. Dashboard shows compliant
```

---

## Policies Explained

### Real-time Tag Enforcement
```yaml
policies:
  - name: ec2-tag-enforcement-realtime
    resource: aws.ec2
    mode:
      type: cloudtrail
      events:
        - RunInstances
    filters:
      - or:
        - "tag:Environment": absent
        - "tag:Owner": absent
    actions:
      - type: tag
        key: custodian-compliance
        value: "non-compliant-missing-tags"
```

**What it does:** When a new EC2 is launched, if it's missing `Environment` OR `Owner` tag, it gets tagged as non-compliant.

### Scheduled Scan
```yaml
policies:
  - name: ec2-missing-tags-scheduled
    resource: aws.ec2
    mode:
      type: periodic
      schedule: "rate(5 minutes)"
    filters:
      - State.Name: running
      - or:
        - "tag:Environment": absent
        - "tag:Owner": absent
```

**What it does:** Every 5 minutes, scans all running EC2 instances. Any missing required tags get reported. This is the source of truth for the dashboard's compliance status.

### Tag Change Rescan
```yaml
policies:
  - name: ec2-compliance-rescan-on-tag
    resource: aws.ec2
    mode:
      type: cloudtrail
      events:
        - source: ec2.amazonaws.com
          event: CreateTags
          ids: "requestParameters.resourcesSet.items[].resourceId"
        - source: ec2.amazonaws.com
          event: DeleteTags
          ids: "requestParameters.resourcesSet.items[].resourceId"
    filters:
      - State.Name: running
      - or:
        - "tag:Environment": absent
        - "tag:Owner": absent
```

**What it does:** When tags are added or removed from an EC2 instance, it re-evaluates compliance immediately.

---

## CI/CD Pipeline

| Workflow | Trigger | Action |
|---|---|---|
| Deploy Policies | Push to `backend/policies/` | Deploys Lambda functions via c7n |
| Deploy Dashboard | Push to `frontend/` | SSH into EC2, git pull, restart service |
| Validate PR | PR touching policies | Validates YAML syntax + dry run |

All workflows use `workflow_dispatch` so you can trigger them manually from the Actions tab.

---

## Useful Commands

```bash
# Validate policies locally
custodian validate policy.yml

# Dry run (no changes, just scan)
custodian run --dryrun -s output --cache-period 0 policy.yml

# Invoke Lambda manually
aws lambda invoke --function-name custodian-ec2-missing-tags-scheduled \
  --invocation-type Event /dev/null

# Check S3 results
aws s3 ls s3://custodian-results-<account_id>/policies/ --recursive

# Download and read results
aws s3 cp s3://custodian-results-<id>/policies/ec2-missing-tags-scheduled/2026/05/16/08/resources.json.gz /tmp/r.gz
gunzip /tmp/r.gz && cat /tmp/r

# Restart dashboard
sudo systemctl restart custodian-dashboard

# Check dashboard logs
sudo journalctl -u custodian-dashboard --no-pager -n 30
```

---

## Extending This Project

Ideas for next steps:

- **Slack/Email notifications** — Use `c7n-mailer` to send alerts on violations
- **Multi-account** — Use `c7n-org` to scan across AWS accounts
- **More policies** — Security groups, public RDS, unused ELBs, etc.
- **User authentication** — Add login to the dashboard
- **Historical trends** — Store results over time and show compliance graphs
- **Terraform drift detection** — Compare actual state vs desired state
- **Cost optimization** — Find and report unused resources

---

## Comparison: This Project vs Stacklet

| Feature | This Project (Open Source) | Stacklet (Commercial) |
|---|---|---|
| Policy engine | Cloud Custodian (same) | Cloud Custodian |
| Real-time detection | CloudTrail + Lambda | CloudTrail + Lambda |
| Dashboard | Custom Flask UI | Full SaaS platform |
| Multi-account | Manual (c7n-org) | Built-in |
| Cost | ~$10/month | $$$$/month |
| Customization | Full control | Limited |
| Setup effort | ~2 hours | Minutes |
| Notifications | DIY (c7n-mailer) | Built-in |
| RBAC | None (add yourself) | Built-in |

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Dashboard shows empty | Check if S3 has results: `aws s3 ls s3://bucket/policies/` |
| Lambda not triggering | Check CloudTrail is enabled and EventBridge rules exist |
| Permission denied | Check IAM role has required permissions |
| Dashboard not updating | Restart service: `sudo systemctl restart custodian-dashboard` |
| Stale results after tagging | Use `--cache-period 0` or wait for scheduled scan (5 min) |
| GitHub Action fails SSH | Verify `EC2_SSH_KEY` secret has full PEM content |
| Terraform state error | Check S3 backend bucket region matches config |

---

## Links

- [Cloud Custodian GitHub](https://github.com/cloud-custodian/cloud-custodian)
- [Cloud Custodian Docs](https://cloudcustodian.io/docs/)
- [This Project's Repo](https://github.com/shrihariharidass/cloudcustodian-UI)
- [CNCF Project Page](https://www.cncf.io/projects/cloud-custodian/)
