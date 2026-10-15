#!/usr/bin/env sh
set -eu

DANDI_RUNTIME_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dandi-runtime.XXXXXX")"
export XDG_STATE_HOME="$DANDI_RUNTIME_DIR/state"
export XDG_CACHE_HOME="$DANDI_RUNTIME_DIR/cache"
export XDG_CONFIG_HOME="$DANDI_RUNTIME_DIR/config"
export XDG_DATA_HOME="$DANDI_RUNTIME_DIR/data"
mkdir -p "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

ACTION="${DANDI_ACTION:-}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
INPUT_DIR="${INPUT_DIR:-/input}"
UPLOAD_WORK_DIR="${UPLOAD_WORK_DIR:-/work}"
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

        instance_api_key_env="$(api_key_env_name "$DANDI_INSTANCE")"
        export "$instance_api_key_env=$DANDI_API_KEY"

        dandiset_url="${DANDISET_URL:-https://dandi.emberarchive.org/dandiset/$DATASET_ID/draft}"
        mkdir -p "$UPLOAD_WORK_DIR"
        cd "$UPLOAD_WORK_DIR"

        dandi download "$dandiset_url"

        if [ -d "$DATASET_ID" ]; then
            cd "$DATASET_ID"
        else
            dandiset_yaml="$(find . -maxdepth 3 -name dandiset.yaml -type f | head -n 1 || true)"
            if [ -z "$dandiset_yaml" ]; then
                die "could not find downloaded dandiset.yaml for DATASET_ID=$DATASET_ID"
            fi
            cd "$(dirname "$dandiset_yaml")"
        fi

        dandi organize "$INPUT_DIR" -f dry
        dandi organize "$INPUT_DIR"
        dandi validate .
        exec dandi upload -i "$DANDI_INSTANCE"
        ;;
    *)
        die "DANDI_ACTION must be download or upload"
        ;;
esac
