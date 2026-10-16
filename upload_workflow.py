"""Stage generic workflow files and verify their presence after CLI upload."""
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from uuid import uuid4


def stage_files(source, destination):
    excluded = {'.cache', '.ipynb_checkpoints', '__pycache__', '.DS_Store'}
    staged = []
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if any(part in excluded for part in relative.parts) or not path.is_file():
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        staged.append(target)
    if not staged:
        raise ValueError('INPUT_DIR contains no files to upload.')
    return staged


def main():
    from dandi.dandiapi import DandiAPIClient
    import yaml

    source = Path(os.environ.get('INPUT_DIR', '/input')).resolve()
    output = Path(os.environ.get('OUTPUT_DIR', '/output')).resolve()
    if source == output or source in output.parents:
        raise ValueError('OUTPUT_DIR must not be inside INPUT_DIR.')
    dataset_id = os.environ.get('DATASET_ID') or os.environ['DANDISET_ID']
    instance = os.environ.get('DANDI_INSTANCE') or 'ember-dandi'
    prefix = os.environ.get('DESTINATION_PREFIX') or 'workflow-results'
    prefix_path = PurePosixPath(prefix)
    if prefix_path.is_absolute() or '..' in prefix_path.parts or not prefix_path.parts:
        raise ValueError('DESTINATION_PREFIX must be a nonempty relative archive path.')
    validation = os.environ.get('UPLOAD_VALIDATION') or 'require'
    if validation not in {'require', 'skip', 'ignore'}:
        raise ValueError('UPLOAD_VALIDATION must be require, skip, or ignore.')
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid4().hex
    remote_prefix = prefix_path / run_id
    key = os.environ['DANDI_API_KEY']
    with DandiAPIClient.for_dandi_instance(instance) as client:
        client.authenticate(key)
        dandiset = client.get_dandiset(dataset_id, 'draft')
        # Fetch only destination metadata, never its existing assets.
        metadata = dandiset.get_raw_metadata()
        with tempfile.TemporaryDirectory(prefix='dandi-upload-') as temporary:
            root = Path(temporary)
            (root / 'dandiset.yaml').write_text(yaml.safe_dump(metadata))
            payload = root / remote_prefix
            files = stage_files(source, payload)
            env = os.environ.copy()
            env['DANDI_DEVEL'] = '1'  # Enables generic-file support in the CLI.
            env[instance.upper().replace('-', '_') + '_API_KEY'] = key
            subprocess.run([
                'dandi', 'upload', '-i', instance, '--allow-any-path',
                '--existing', 'error', '--validation', validation, str(payload),
            ], cwd=root, env=env, check=True)
            # A successful CLI exit alone can conceal skipped/unsupported files.
            remote = {asset.path: asset for asset in
                      dandiset.get_assets_with_path_prefix(str(remote_prefix) + '/')}
            receipt_files = []
            for path in files:
                archive_path = path.relative_to(root).as_posix()
                asset = remote.get(archive_path)
                if asset is None or asset.size != path.stat().st_size:
                    raise RuntimeError(f'Upload verification failed: {archive_path}')
                receipt_files.append({'path': archive_path, 'asset_id': asset.identifier,
                                      'size': asset.size})
            output.mkdir(parents=True, exist_ok=True)
            (output / 'upload-receipt.json').write_text(json.dumps({
                'status': 'uploaded', 'instance': instance, 'dandiset_id': dataset_id,
                'version': 'draft', 'prefix': str(remote_prefix),
                'verification': 'remote presence and file size', 'files': receipt_files,
            }, indent=2) + '\n')
            print(f'Verified {len(files)} uploaded files in {dataset_id}/{remote_prefix}', flush=True)


if __name__ == '__main__':
    main()
