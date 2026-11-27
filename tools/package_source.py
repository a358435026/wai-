"""Package only reviewable source. Never include local downloads, builds or credentials."""
from pathlib import Path
import hashlib
import json
import zipfile

root = Path(__file__).resolve().parents[1]
allowed = ['Sources', 'Protocol', 'Tests', '.github', 'tools', 'replica']
files = [p for folder in allowed for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
files += [root / name for name in ['Package.swift', 'project.yml', '.gitignore', 'README.md', 'INSTALL.md', 'VALIDATION.md', 'DESIGN.md']]
output = root.parent / 'tongchuan-ios-source.zip'
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, 'tongchuan-ios/' + path.relative_to(root).as_posix())
    archive.writestr('tongchuan-ios/SOURCE-MANIFEST.json', json.dumps({
        p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)
    }, indent=2))
print(json.dumps({'path': str(output), 'source_files': len(files), 'bytes': output.stat().st_size,
                  'sha256': hashlib.sha256(output.read_bytes()).hexdigest()}, ensure_ascii=True))
