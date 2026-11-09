#!/usr/bin/env sh
set -eu

# Accept the existing Docker environment variables as well as the parameter
# names used in app.yml. Pennsieve runtime versions have used both uppercase
# environment variables and PARAM_<NAME> for declared parameters.
ACTION="${DANDI_ACTION:-${ACTION:-${PARAM_ACTION:-${action:-}}}}"
OUTPUT_DIR="${OUTPUT_DIR:-${PARAM_OUTPUT_DIR:-${output_dir:-/output}}}"
INPUT_DIR="${INPUT_DIR:-${PARAM_INPUT_DIR:-${input_dir:-/input}}}"
UPLOAD_WORK_DIR="${UPLOAD_WORK_DIR:-${PARAM_UPLOAD_WORK_DIR:-${upload_work_dir:-/work}}}"
DATASET_ID="${DATASET_ID:-${DANDISET_ID:-${PARAM_DATASET_ID:-${dataset_id:-}}}}"
DANDI_INSTANCE="${DANDI_INSTANCE:-${PARAM_DANDI_INSTANCE:-${dandi_instance:-ember-dandi}}}"
DANDI_URL="${DANDI_URL:-${PARAM_DANDI_URL:-${dandi_url:-}}}"
DANDI_API_KEY="${DANDI_API_KEY:-${PARAM_DANDI_API_KEY:-${dandi_api_key:-}}}"
DANDISET_URL="${DANDISET_URL:-${PARAM_DANDISET_URL:-${dandiset_url:-}}}"
DESTINATION_PREFIX="${DESTINATION_PREFIX:-${PARAM_DESTINATION_PREFIX:-${destination_prefix:-inference-results}}}"
UPLOAD_VALIDATION="${UPLOAD_VALIDATION:-${PARAM_UPLOAD_VALIDATION:-${upload_validation:-require}}}"

export INPUT_DIR OUTPUT_DIR DATASET_ID DANDI_INSTANCE DANDI_API_KEY
export DESTINATION_PREFIX UPLOAD_VALIDATION

usage() {
    cat >&2 <<'EOF'
Set one action:
  DANDI_ACTION=download
  DANDI_ACTION=upload

Download:
  DANDI_URL=<DANDI URL or identifier>
  OUTPUT_DIR=<download destination directory, default: /output>

Upload:
  DATASET_ID=<DANDI/EMBER Dandiset identifier>
  INPUT_DIR=<source folder to organize, default: /input>
  DANDI_API_KEY=<token>

Optional:
  DANDISET_URL=https://dandi.emberarchive.org/dandiset/<DATASET_ID>/draft
  UPLOAD_WORK_DIR=/work
  DANDI_INSTANCE=ember-dandi
EOF
}

die() {
    echo "ERROR: $*" >&2
    usage
    exit 64
}

api_key_env_name() {
    printf '%s_API_KEY\n' "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

# DANDI CLI reads credentials from an instance-specific environment variable
# (for example, EMBER_DANDI_API_KEY). Make an optional token available for
# authenticated downloads as well as uploads; only uploads require one.
if [ -n "$DANDI_API_KEY" ]; then
    instance_api_key_env="$(api_key_env_name "$DANDI_INSTANCE")"
    export "$instance_api_key_env=$DANDI_API_KEY"
fi

case "$ACTION" in
    download)
        if [ -z "${DANDI_URL:-}" ]; then
            die "DANDI_URL is required for downloads"
        fi
        mkdir -p "$OUTPUT_DIR"
        cd "$OUTPUT_DIR"
        exec dandi download "$DANDI_URL"
        ;;
    upload)
        if [ -z "$DATASET_ID" ]; then
            die "DATASET_ID or DANDISET_ID is required for uploads"
        fi

        if [ -z "${DANDI_API_KEY:-}" ]; then
            die "DANDI_API_KEY is required for uploads"
        fi

        if [ ! -d "$INPUT_DIR" ]; then
            die "INPUT_DIR does not exist or is not a directory: $INPUT_DIR"
        fi

        exec python /usr/local/bin/dandi-upload-workflow.py
        ;;
    *)
        die "DANDI_ACTION must be download or upload"
        ;;
esac
