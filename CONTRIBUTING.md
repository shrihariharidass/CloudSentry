# Contributing to CloudSentry

Thanks for your interest in contributing to CloudSentry! This document provides guidelines for contributing.

---

## How to Contribute

### Reporting Bugs

1. Check existing [issues](https://github.com/shrihariharidass/CloudSentry/issues) to avoid duplicates
2. Open a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Python version, Terraform version)

### Suggesting Features

1. Open an issue with the `enhancement` label
2. Describe the use case and expected behavior
3. If possible, include a rough implementation idea

### Submitting Code

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test locally (see below)
5. Commit with clear messages: `git commit -m "Add: description of change"`
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request against `main`

---

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/CloudSentry.git
cd CloudSentry

# Create virtual environment
python3 -m venv custodian
source custodian/bin/activate

# Install dependencies
pip install c7n
pip install -r frontend/requirements.txt

# Run dashboard locally
cd frontend
C7N_LOCAL_OUTPUT="../output" python app.py
```

---

## Testing

### Validate Policies

```bash
custodian validate policy.yml
custodian validate backend/policies/*.yml
```

### Dry Run

```bash
custodian run --dryrun -s output --cache-period 0 policy.yml
```

### Run Dashboard Locally

```bash
cd frontend
C7N_LOCAL_OUTPUT="../output" python app.py
# Visit http://localhost:5000
```

---

## Code Style

- Python: Follow PEP 8
- YAML: 2-space indentation, quote strings with colons
- Terraform: Use `terraform fmt` before committing
- Commit messages: Use prefixes (`Add:`, `Fix:`, `Update:`, `Remove:`)

---

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Update documentation if behavior changes
- Add comments for complex logic
- Ensure all policies validate before submitting
- Test the dashboard locally if frontend changes are made

---

## Areas for Contribution

- New Cloud Custodian policies (security, cost, compliance)
- Dashboard UI improvements
- Multi-cloud support (Azure, GCP)
- Notification integrations (Slack, email, PagerDuty)
- Documentation improvements
- Docker/Kubernetes deployment options
- Unit tests

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

---

## Questions?

Open an issue or start a discussion. We're happy to help!
