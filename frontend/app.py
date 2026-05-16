"""
Cloud Custodian Dashboard - Flask app that reads policy results from S3.
Handles c7n's date-based S3 output structure with gzipped files.
Separates scheduled scans (current state) from real-time events (audit log).
"""

import gzip
import json
import os
from datetime import datetime

import boto3
from flask import Flask, jsonify, render_template

app = Flask(__name__)

S3_BUCKET = os.environ.get("C7N_S3_BUCKET", "custodian-results-858688858026")
S3_PREFIX = os.environ.get("C7N_S3_PREFIX", "policies/")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
LOCAL_OUTPUT = os.environ.get("C7N_LOCAL_OUTPUT", "")

s3_client = boto3.client("s3", region_name=AWS_REGION)

# Real-time policies are event-based (audit log), not current state
REALTIME_POLICIES = {"ec2-tag-enforcement-realtime", "s3-tag-enforcement-realtime"}


def find_latest_resources_key(policy_prefix):
    """Find the most recent resources.json.gz in date-based S3 structure."""
    try:
        response = s3_client.list_objects_v2(
            Bucket=S3_BUCKET, Prefix=policy_prefix
        )
        objects = response.get("Contents", [])
        resource_files = [
            obj for obj in objects if obj["Key"].endswith("resources.json.gz")
        ]
        if not resource_files:
            return None, None
        resource_files.sort(key=lambda x: x["LastModified"], reverse=True)
        latest = resource_files[0]
        return latest["Key"], latest["LastModified"]
    except Exception:
        return None, None


def load_policy_data(prefix):
    """Load a single policy's latest results from S3."""
    policy_name = prefix["Prefix"].replace(S3_PREFIX, "").strip("/")
    resources_key, last_modified = find_latest_resources_key(prefix["Prefix"])

    resources = []
    last_updated = None

    if resources_key:
        try:
            obj = s3_client.get_object(Bucket=S3_BUCKET, Key=resources_key)
            raw_data = obj["Body"].read()
            decompressed = gzip.decompress(raw_data)
            resources = json.loads(decompressed.decode("utf-8"))
            last_updated = last_modified.isoformat() if last_modified else None
        except Exception:
            resources = []
            last_updated = None

    return {
        "name": policy_name,
        "resources": resources,
        "resource_count": len(resources),
        "last_updated": last_updated,
    }


def load_results_from_s3():
    """Load policy results from S3, separating scheduled (current state) from real-time (events)."""
    scheduled_results = []
    realtime_events = []

    try:
        response = s3_client.list_objects_v2(
            Bucket=S3_BUCKET, Prefix=S3_PREFIX, Delimiter="/"
        )
        prefixes = response.get("CommonPrefixes", [])

        for prefix in prefixes:
            policy_name = prefix["Prefix"].replace(S3_PREFIX, "").strip("/")
            data = load_policy_data(prefix)

            if policy_name in REALTIME_POLICIES:
                realtime_events.append(data)
            else:
                scheduled_results.append(data)

    except Exception as e:
        if LOCAL_OUTPUT:
            return load_results_from_local(), []
        return [{"error": str(e)}], []

    return scheduled_results, realtime_events


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
    """Returns current compliance state from scheduled scans."""
    scheduled_results, realtime_events = load_results_from_s3()

    if not scheduled_results and LOCAL_OUTPUT:
        scheduled_results = load_results_from_local()

    summary = {
        "total_policies": len(scheduled_results),
        "total_violations": sum(r.get("resource_count", 0) for r in scheduled_results),
        "compliant_policies": sum(
            1 for r in scheduled_results if r.get("resource_count", 0) == 0
        ),
        "non_compliant_policies": sum(
            1 for r in scheduled_results if r.get("resource_count", 0) > 0
        ),
    }
    return jsonify({"summary": summary, "policies": scheduled_results})


@app.route("/api/realtime-events")
def realtime_events():
    """Returns real-time enforcement events (audit log)."""
    _, realtime_results = load_results_from_s3()

    total_events = sum(r.get("resource_count", 0) for r in realtime_results)
    return jsonify({"total_events": total_events, "policies": realtime_results})


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
