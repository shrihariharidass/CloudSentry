# Cloud Custodian UI - Open Source Governance Dashboard

A Stacklet-like open source dashboard for Cloud Custodian with real-time compliance monitoring via CloudTrail integration.

## Architecture

```
CloudTrail → EventBridge → Lambda (c7n) → S3 (results) → Dashboard (Flask)
```

## Project Structure

```
├── frontend/           # Flask dashboard UI
│   ├── app.py          # Flask app (reads from S3 or local output)
│   ├── templates/      # HTML templates
│   ├── Dockerfile
│   └── requirements.txt
├── backend/            # Cloud Custodian policies
│   └── policies/
│       ├── realtime-tag-enforcement.yml   # CloudTrail-triggered policies
│       └── scheduled-scan.yml             # Periodic scan policies
├── infra/              # Terraform infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── iam.tf          # IAM roles (Lambda + Dashboard)
│   ├── s3.tf           # Results bucket
│   ├── cloudtrail.tf   # CloudTrail + EventBridge
│   └── outputs.tf
├── policy.yml          # Local testing policies
└── cloud-custodian-setup-guide.md
```

## Quick Start (Local)

```bash
python3 -m venv custodian
source custodian/bin/activate
pip install c7n flask boto3

# Run policies locally
custodian run --dryrun -s output --cache-period 0 policy.yml

# Start dashboard (local mode)
cd frontend
C7N_LOCAL_OUTPUT="../output" python app.py
```

## Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Deploy Real-Time Policies

After Terraform creates the IAM role, deploy the Lambda-based policies:

```bash
# Replace {account_id} in policy files first
sed -i 's/{account_id}/858688858026/g' backend/policies/*.yml

# Deploy real-time policies (creates Lambda + EventBridge rules)
custodian run -s s3://custodian-results-858688858026/policies backend/policies/realtime-tag-enforcement.yml

# Deploy scheduled policies
custodian run -s s3://custodian-results-858688858026/policies backend/policies/scheduled-scan.yml
```

## Run Dashboard (Production)

```bash
cd frontend
export C7N_S3_BUCKET="custodian-results-858688858026"
export C7N_S3_PREFIX="policies/"
export AWS_REGION="us-east-1"
gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
```
