"""
Cloud Custodian Dashboard - Flask app that reads policy results from S3.
"""

import json
import os
from datetime import datetime

import boto3
from flask import Flask, jsonify, render_template

app = Flask(__name__)

S3_BUCKET = os.environ.get("C7N_S3_BUCKET", "custodian-results-858688858026")
S3_PREFIX = os.environ.get("C7N_S3_PREFIX", "policies/")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
LOCAL_OUTPUT = os.environ.get("C7N_LOCAL_OUTPUT", "")  # Fallback to local output dir

s3_client = boto3.client("s3", region_name=AWS_REGION)


def load_results_from_s3():
    """Load policy results from S3 bucket."""
    results = []
    try:
        response = s3_client.list_objects_v2(
            Bucket=S3_BUCKET, Prefix=S3_PREFIX, Delimiter="/"
        )

        prefixes = response.get("CommonPrefixes", [])
        for prefix in prefixes:
            policy_name = prefix["Prefix"].replace(S3_PREFIX, "").strip("/")
            resources_key = f"{prefix['Prefix']}resources.json"

            try:
                obj = s3_client.get_object(Bucket=S3_BUCKET, Key=resources_key)
                resources = json.loads(obj["Body"].read().decode("utf-8"))
                last_modified = obj["LastModified"].isoformat()
            except s3_client.exceptions.NoSuchKey:
                resources = []
                last_modified = None
            except Exception:
                resources = []
                last_modified = None

            results.append(
                {
                    "name": policy_name,
                    "resources": resources,
                    "resource_count": len(resources),
                    "last_updated": last_modified,
                }
            )
    except Exception as e:
        # Fallback to local output if S3 fails
        if LOCAL_OUTPUT:
            return load_results_from_local()
        return [{"error": str(e)}]

    return results


def load_results_from_local():
    """Fallback: Load results from local output directory."""
    from pathlib import Path

    results = []
    output_path = Path(LOCAL_OUTPUT)

    if not output_path.exists():
        return results

    for policy_dir in sorted(output_path.iterdir()):
        if not policy_dir.is_dir():
            continue

        resources_file = policy_dir / "resources.json"
        policy_data = {
            "name": policy_dir.name,
            "resources": [],
            "resource_count": 0,
            "last_updated": None,
        }

        if resources_file.exists():
            with open(resources_file) as f:
                resources = json.load(f)
                policy_data["resources"] = resources
                policy_data["resource_count"] = len(resources)
                policy_data["last_updated"] = datetime.fromtimestamp(
                    resources_file.stat().st_mtime
                ).isoformat()

        results.append(policy_data)

    return results


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/results")
def api_results():
    if LOCAL_OUTPUT:
        results = load_results_from_local()
    else:
        results = load_results_from_s3()

    summary = {
        "total_policies": len(results),
        "total_violations": sum(r.get("resource_count", 0) for r in results),
        "compliant_policies": sum(
            1 for r in results if r.get("resource_count", 0) == 0
        ),
        "non_compliant_policies": sum(
            1 for r in results if r.get("resource_count", 0) > 0
        ),
    }
    return jsonify({"summary": summary, "policies": results})


@app.route("/api/cloudtrail-events")
def cloudtrail_events():
    """Fetch recent CloudTrail events related to resource creation."""
    try:
        ct_client = boto3.client("cloudtrail", region_name=AWS_REGION)
        response = ct_client.lookup_events(
            LookupAttributes=[
                {"AttributeKey": "ReadOnly", "AttributeValue": "false"}
            ],
            MaxResults=20,
        )

        events = []
        for event in response.get("Events", []):
            events.append(
                {
                    "event_name": event.get("EventName"),
                    "event_time": event.get("EventTime", "").isoformat()
                    if event.get("EventTime")
                    else None,
                    "username": event.get("Username"),
                    "resources": [
                        {"type": r.get("ResourceType"), "name": r.get("ResourceName")}
                        for r in event.get("Resources", [])
                    ],
                    "event_source": event.get("EventSource"),
                }
            )

        return jsonify({"events": events})
    except Exception as e:
        return jsonify({"error": str(e), "events": []})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(debug=True, host="0.0.0.0", port=port)
