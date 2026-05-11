    # Cloud Custodian — Setup & Demo Guide

    > Cloud Custodian (c7n) is an open-source, CNCF Incubating project. It's a rules engine for managing cloud resources using simple YAML policies. Think of it as "governance as code" for AWS, Azure, and GCP.

    ---

    ## Prerequisites

    | Requirement | Mac | EC2 Ubuntu |
    |---|---|---|
    | Python 3.8+ | Pre-installed (or `brew install python3`) | `sudo apt update && sudo apt install python3 python3-venv python3-pip -y` |
    | AWS CLI v2 | `brew install awscli` | See install steps below |
    | AWS Account | ✅ | ✅ |

    ---

    ## Step 1 — Create a Dedicated IAM User

    Don't use your root or admin account. Create a limited-permission user for Cloud Custodian.

    ### 1.1 Create IAM Policy

    Go to **AWS Console → IAM → Policies → Create Policy → JSON** and paste:

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "CustodianReadAccess",
                "Effect": "Allow",
                "Action": [
                    "ec2:Describe*",
                    "s3:GetBucket*",
                    "s3:ListAllMyBuckets",
                    "s3:ListBucket",
                    "iam:List*",
                    "iam:Get*",
                    "tag:GetResources",
                    "cloudwatch:PutMetricData",
                    "ebs:Describe*",
                    "rds:Describe*",
                    "elasticloadbalancing:Describe*",
                    "lambda:List*",
                    "lambda:GetFunction"
                ],
                "Resource": "*"
            }
        ]
    }
    ```

    Name it: `CloudCustodianReadOnly`

    ### 1.2 Create IAM User

    1. Go to **IAM → Users → Create User**
    2. User name: `custodian-demo`
    3. Attach the `CloudCustodianReadOnly` policy
    4. Go to **Security Credentials → Create Access Key**
    5. Choose **"Command Line Interface (CLI)"**
    6. Save the **Access Key ID** and **Secret Access Key**

    ---

    ## Step 2 — Install & Configure AWS CLI

    ### Mac

    ```bash
    brew install awscli
    ```

    ### EC2 Ubuntu

    ```bash
    sudo apt update && sudo apt install unzip curl -y
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```

    ### Configure the CLI

    ```bash
    aws configure --profile custodian-demo
    ```

    It will prompt you:

    ```
    AWS Access Key ID: <paste your access key>
    AWS Secret Access Key: <paste your secret key>
    Default region name: us-east-1
    Default output format: json
    ```

    Verify it works:

    ```bash
    aws sts get-caller-identity --profile custodian-demo
    ```

    You should see your account ID and the `custodian-demo` user ARN.

    ---

    ## Step 3 — Install Cloud Custodian (c7n)

    These steps are the same on both Mac and Ubuntu.

    ```bash
    # Create a virtual environment
    python3 -m venv custodian
    source custodian/bin/activate

    # Install c7n (includes AWS support)
    pip install c7n

    # Verify installation
    custodian version
    ```

    You should see something like: `0.9.50`

    ---

    ## Step 4 — Set the AWS Profile

    Tell Cloud Custodian to use your limited-permission user:

    ```bash
    export AWS_PROFILE=custodian-demo
    ```

    Or add it to your shell config (`~/.bashrc` or `~/.zshrc`) so it persists:

    ```bash
    echo 'export AWS_PROFILE=custodian-demo' >> ~/.zshrc
    source ~/.zshrc
    ```

    ---

    ## Step 5 — Write Your First Policy

    Create a file called `policy.yml`:

    ```yaml
    policies:
    # Policy 1: Find S3 buckets without encryption
    - name: find-unencrypted-s3
        description: Find S3 buckets without default encryption enabled
        resource: aws.s3
        filters:
        - type: bucket-encryption
            state: false

    # Policy 2: Find EC2 instances missing required tags
    - name: ec2-missing-tags
        description: Find running EC2 instances missing Environment and Owner tags
        resource: aws.ec2
        filters:
        - State.Name: running
        - "tag:Environment": absent
        - "tag:Owner": absent

    # Policy 3: Find publicly accessible S3 buckets
    - name: find-public-s3
        description: Detect S3 buckets with public access grants
        resource: aws.s3
        filters:
        - type: global-grants

    # Policy 4: Find unattached EBS volumes (cost optimization)
    - name: unused-ebs-volumes
        description: Find EBS volumes not attached to any instance
        resource: aws.ebs
        filters:
        - Attachments: []

    # Policy 5: Find EC2 instances without encrypted volumes
    - name: ec2-unencrypted-volumes
        description: Find EC2 instances with unencrypted EBS volumes
        resource: aws.ec2
        filters:
        - type: ebs
            key: Encrypted
            value: false
    ```

    ---

    ## Step 6 — Validate, Dry Run, and Execute

    ### Validate the policy syntax

    ```bash
    custodian validate policy.yml
    ```

    Expected output:
    ```
    Configuration valid: policy.yml
    ```

    ### Dry Run (safe — no changes made)

    ```bash
    custodian run --dryrun -s output policy.yml
    ```

    This scans your resources and shows what matches, without taking any action.

    ### Check Results

    ```bash
    # See matched resources for each policy
    cat output/find-unencrypted-s3/resources.json
    cat output/ec2-missing-tags/resources.json
    cat output/find-public-s3/resources.json
    cat output/unused-ebs-volumes/resources.json
    cat output/ec2-unencrypted-volumes/resources.json
    ```

    - `[]` = no resources matched (compliant)
    - `[{...}]` = resources found that violate the policy

    ### Run for Real (when ready)

    ```bash
    custodian run -s output policy.yml
    ```

    ---

    ## Useful Commands Reference

    | Command | What it does |
    |---|---|
    | `custodian validate policy.yml` | Check policy syntax |
    | `custodian run --dryrun -s output policy.yml` | Scan without taking action |
    | `custodian run -s output policy.yml` | Run policies and execute actions |
    | `custodian schema aws` | List all supported AWS resource types |
    | `custodian schema aws.ec2` | Show filters & actions for EC2 |
    | `custodian schema aws.s3.filters` | Show all S3 filters |
    | `custodian schema aws.ec2.actions` | Show all EC2 actions |
    | `custodian run -s output --metrics policy.yml` | Run with CloudWatch metrics |

    ---

    ## Example Output

    When `ec2-missing-tags` finds a non-compliant instance, the output looks like:

    ```json
    [
    {
        "InstanceId": "i-08409ea64ead6dbdc",
        "InstanceType": "t3.micro",
        "State": { "Name": "running" },
        "Tags": [
        { "Key": "Name", "Value": "Janhavi" }
        ],
        "c7n:MatchedFilters": [
        "tag:Environment",
        "tag:Owner"
        ]
    }
    ]
    ```

    The `c7n:MatchedFilters` field tells you exactly which filters triggered the match.

    ---

    ## Project Structure

    ```
    cloud-custodian-demo/
    ├── custodian/          # Python virtual environment
    ├── policy.yml          # Your policy definitions
    └── output/             # Generated after running policies
        ├── find-unencrypted-s3/
        │   └── resources.json
        ├── ec2-missing-tags/
        │   └── resources.json
        └── ...
    ```

    ---

    ## Cleanup

    To deactivate the virtual environment:

    ```bash
    deactivate
    ```

    To remove the IAM user when done:

    ```bash
    aws iam delete-access-key --user-name custodian-demo --access-key-id <KEY_ID>
    aws iam detach-user-policy --user-name custodian-demo --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/CloudCustodianReadOnly
    aws iam delete-user --user-name custodian-demo
    aws iam delete-policy --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/CloudCustodianReadOnly
    ```

    ---

    ## Resources

    - [Cloud Custodian GitHub](https://github.com/cloud-custodian/cloud-custodian)
    - [Official Docs](https://cloudcustodian.io/docs/)
    - [AWS Getting Started](https://cloudcustodian.io/docs/aws/gettingstarted.html)
    - [Policy Schema Explorer](https://cloudcustodian.io/docs/quickstart/index.html#explore-cloud-custodian)
