# DANDI CLI for Pennsieve

Use this application twice: download -> workflow processor(s) -> upload.
Pennsieve supplies INPUT_DIR and OUTPUT_DIR. Standard CPU execution is sufficient
for transfers; the training application needs GPU capacity.

## Download

Set DANDI_ACTION=download and DANDI_URL to a Dandiset, folder, or asset URL.
Downloaded files go to OUTPUT_DIR. DANDISET_URL is retained in the manifest for
compatibility with old forms but is no longer used by the uploader.

## Upload

Set DANDI_ACTION=upload, DATASET_ID, DANDI_INSTANCE (default ember-dandi), and
provide DANDI_API_KEY through an appropriate secret/environment mechanism.
Do not commit the key or place it in release notes. The application manifest
does not expose the key as a regular parameter.

The uploader fetches only destination metadata, stages INPUT_DIR in a private
writable temporary directory, and preserves relative file paths beneath:

    DESTINATION_PREFIX/<timestamp-and-unique-id>/

DESTINATION_PREFIX defaults to workflow-results. Each execution uses a unique
folder, avoiding replacement of the original dataset. Files named .DS_Store and
contents of .cache, .ipynb_checkpoints, and __pycache__ are excluded. Staging
requires enough temporary disk space for a copy of the output being uploaded.

The CLI is invoked with generic-file support (--allow-any-path), existing-file
policy error, and UPLOAD_VALIDATION=require by default. No remote sync/deletion
is performed. The destination still decides which asset formats it accepts.
UPLOAD_VALIDATION also accepts skip or ignore if explicitly configured; keep
require for the initial run and inspect validation errors instead of changing
this setting preemptively.

After upload, the helper checks remote presence and file size for every staged
file and writes OUTPUT_DIR/upload-receipt.json with asset IDs and archive paths.
This is not a cryptographic content verification. A partial failed upload can
leave files in its run folder; it does not produce a success receipt.

## Bees pipeline into Dandiset 000598

Publish updated releases of both applications. Wire:

    DANDI download -> EMBER DLC training -> DANDI upload

Download parameters:

    DANDI_ACTION=download
    DANDI_URL=https://dandi.emberarchive.org/dandiset/000598/draft

Training parameters for an initial end-to-end smoke test:

    PROJECT_SUBDIR=000598/bees
    EPOCHS=1
    SAVE_EPOCHS=1
    BATCH_SIZE=1
    DEVICE=cuda:0

PROJECT_SUBDIR is relative to the trainer's INPUT_DIR. Confirm it matches the
successful download's output tree. Selecting just this project is necessary
when previous runs add further config.yaml files to the same Dandiset.

Upload parameters:

    DANDI_ACTION=upload
    DATASET_ID=000598
    DANDI_INSTANCE=ember-dandi
    DESTINATION_PREFIX=training-results
    UPLOAD_VALIDATION=require

Supply DANDI_API_KEY to the upload container. If the Pennsieve form still
requires the unused URL fields, use the 000598 draft URL for both. The upload
helper selects its destination using DATASET_ID and DANDI_INSTANCE.

The final uploader can connect to a Pennsieve Dataset target if you want its
receipt saved there. Training artifacts themselves are uploaded to EMBER.
Downloading the full Dandiset on subsequent runs also downloads previous
results; PROJECT_SUBDIR keeps training focused on the original bees project.

## Local verification

With dandi installed:

    python -m unittest -v test_upload_workflow.py
    sh -n entrypoint.sh

The tests mock archive calls; they do not prove a remote upload or GPU run.
