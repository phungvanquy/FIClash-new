#!/usr/bin/env python3
import argparse
import concurrent.futures
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[1]


def prepare(version, artifact, cache):
    directory = cache / version
    directory.mkdir(parents=True, exist_ok=True)
    archive = directory / 'xray.zip'
    if archive.exists():
        payload = archive.read_bytes()
    else:
        with urllib.request.urlopen(artifact['url'], timeout=60) as response:
            payload = response.read()
    if hashlib.sha256(payload).hexdigest() != artifact['sha256']:
        raise RuntimeError(f'Xray {version}: archive checksum mismatch')
    if not archive.exists():
        temporary = archive.with_name(f'xray.{os.getpid()}.zip.tmp')
        temporary.write_bytes(payload)
        temporary.replace(archive)
    with zipfile.ZipFile(io.BytesIO(payload)) as bundle:
        binary = directory / 'xray'
        payload = bundle.read('xray')
        if not binary.exists() or binary.read_bytes() != payload:
            temporary = binary.with_name(f'xray.{os.getpid()}.tmp')
            temporary.write_bytes(payload)
            temporary.chmod(0o755)
            temporary.replace(binary)
        binary.chmod(0o755)
    result = subprocess.run(
        [str(binary), 'version'], check=True, capture_output=True,
        text=True, timeout=10,
    )
    if version not in result.stdout.splitlines()[0]:
        raise RuntimeError(f'Xray {version}: unexpected binary version')
    print(result.stdout.splitlines()[0], flush=True)


def main():
    parser = argparse.ArgumentParser(description='Run pinned local Xray interoperability tests')
    parser.add_argument('--versions', nargs='+')
    parser.add_argument('--baseline', action='store_true')
    parser.add_argument('--download-only', action='store_true')
    parser.add_argument('--run', default='TestXray')
    args = parser.parse_args()
    architecture = {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(platform.machine())
    if platform.system() != 'Linux' or architecture is None:
        parser.error('the pinned harness requires Linux amd64 or arm64')
    releases = json.loads((ROOT / 'core/testdata/xray/releases.json').read_text())
    versions = args.versions or list(releases)
    if any(version not in releases for version in versions):
        parser.error('requested version is not pinned in releases.json')
    cache = ROOT / '.dart_tool/xray-interop'
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(prepare, version, releases[version][architecture], cache)
                   for version in versions]
        for future in futures:
            future.result()
    if args.download_only:
        return
    env = dict(os.environ, XRAY_INTEROP_DIR=str(cache),
               XRAY_INTEROP_VERSIONS=','.join(versions),
               XRAY_INTEROP_BASELINE='1' if args.baseline else '0',
               CGO_ENABLED='0')
    subprocess.run(
        ['go', 'test', '-tags=xrayinterop', '-count=1', '-timeout=20m',
         '-v', '-run', args.run, '.'],
        cwd=ROOT / 'core', env=env, check=True, timeout=1500,
    )


if __name__ == '__main__':
    main()
