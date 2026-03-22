# Cloud Build Tagging – No Local Docker Required

- In GCP Cloud Build workflows (gcloud builds submit), only the first --tag is pushed to GCR.
- Do NOT use local docker CLI commands (docker tag, docker push, etc.) in deployment scripts for serverless/cloud-native projects.
- Local Docker is NOT required and should NOT be assumed present for deployment automation.
- To ensure a tag exists in GCR, use gcloud builds submit with a single --tag for the desired tag (e.g., production).
- If multiple tags are needed, run gcloud builds submit separately for each tag, or retag in the registry using GCP tools—not local Docker.
- Deployment scripts must remain cloud-native and portable; never break this by requiring local Docker.

## Actionable Reminder
If you ever see a deploy script using local docker commands in a GCP Cloud Build workflow, REMOVE them and use only gcloud builds submit.
