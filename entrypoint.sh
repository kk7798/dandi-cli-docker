#!/usr/bin/env sh
set -eu

# Pennsieve may run with an unprivileged UID whose home resolves to /.
# Keep CLI logs and caches in a private writable directory instead of /.local.
DANDI_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dandi-runtime.XXXXXX")"
export XDG_STATE_HOME="$DANDI_RUNTIME_DIR/state"
export XDG_CACHE_HOME="$DANDI_RUNTIME_DIR/cache"
export XDG_CONFIG_HOME="$DANDI_RUNTIME_DIR/config"
export XDG_DATA_HOME="$DANDI_RUNTIME_DIR/data"
mkdir -p "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

ACTION="${DANDI_ACTION:-}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
INPUT_DIR="${INPUT_DIR:-/input}"
DATASET_ID="${DATASET_ID:-${DANDISET_ID:-}}"
DANDI_INSTANCE="${DANDI_INSTANCE:-ember-dandi}"

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
  INPUT_DIR=<workflow output folder to upload, default: /input>
  DANDI_API_KEY=<token>

Optional:
  DESTINATION_PREFIX=workflow-results
  UPLOAD_VALIDATION=require
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

if [ -n "${DANDI_API_KEY:-}" ]; then
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
