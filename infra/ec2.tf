# Dashboard EC2 Instance
resource "aws_instance" "dashboard" {
  ami                    = "ami-091138d0f0d41ff90" # Ubuntu 24.04 LTS us-east-1
  instance_type          = "t3.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.dashboard.id]
  iam_instance_profile   = aws_iam_instance_profile.dashboard.name
  subnet_id              = var.subnet_id

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update -y
    apt-get install -y python3 python3-venv python3-pip git

    # Setup app directory
    cd /home/ubuntu
    git clone https://github.com/shrihariharidass/cloudcustodian-UI.git
    cd cloudcustodian-UI

    # Create virtual environment and install dependencies
    python3 -m venv custodian
    source custodian/bin/activate
    pip install c7n
    pip install -r frontend/requirements.txt

    # Create systemd service for dashboard
    cat > /etc/systemd/system/custodian-dashboard.service <<UNIT
    [Unit]
    Description=Cloud Custodian Dashboard
    After=network.target

    [Service]
    Type=simple
    User=ubuntu
    WorkingDirectory=/home/ubuntu/cloudcustodian-UI/frontend
    Environment=C7N_S3_BUCKET=custodian-results-${var.account_id}
    Environment=C7N_S3_PREFIX=policies/
    Environment=C7N_LOCAL_OUTPUT=../output
    Environment=AWS_REGION=${var.aws_region}
    ExecStart=/home/ubuntu/cloudcustodian-UI/custodian/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable custodian-dashboard
    systemctl start custodian-dashboard

    # Fix ownership
    chown -R ubuntu:ubuntu /home/ubuntu/cloudcustodian-UI
  EOF

  tags = {
    Name        = "${var.project_name}-dashboard"
    Environment = var.environment
    Project     = var.project_name
    Owner       = "Shrihari"
  }
}

# Security Group for Dashboard
resource "aws_security_group" "dashboard" {
  name        = "${var.project_name}-dashboard-sg"
  description = "Security group for Cloud Custodian Dashboard"
  vpc_id      = var.vpc_id

  # SSH access from your IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Dashboard UI
  ingress {
    description = "Dashboard HTTP"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-dashboard-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
