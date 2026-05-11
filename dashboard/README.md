# Cloud Custodian Dashboard

A lightweight web UI to visualize Cloud Custodian policy results.

## Setup

```bash
# From the project root
source custodian/bin/activate
pip install flask

# Run the dashboard
cd dashboard
python app.py
```

Open http://localhost:5000 in your browser.

## Configuration

Set the output directory path via environment variable:

```bash
export C7N_OUTPUT_DIR="../output"
```

## How it works

1. You run `custodian run --dryrun -s output policy.yml`
2. The dashboard reads the `output/` directory
3. It displays compliance status for each policy with resource details
```
