"""Verify the delivered binary's platform and minimum OS, not just project settings."""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import struct
import zipfile


def version(value):
    return tuple((list(map(int, value.split('.'))) + [0, 0])[:3])


def verify(path, maximum, expected):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, 'IPA ZIP checksum failure'
        plists = [name for name in archive.namelist()
                  if name.startswith('Payload/') and name.count('/') == 2 and name.endswith('/Info.plist')]
        assert len(plists) == 1, 'Expected one main application'
        plist_path = plists[0]
        info = plistlib.loads(archive.read(plist_path))
        assert info['CFBundleShortVersionString'] == expected, 'Unexpected release version'
        assert version(info['MinimumOSVersion']) <= version(maximum), 'Info.plist minimum OS too high'
        binary = archive.read(plist_path.rsplit('/', 1)[0] + '/' + info['CFBundleExecutable'])
        magic, cpu, _, _, commands = struct.unpack_from('<IIIII', binary)
        assert magic == 0xfeedfacf and cpu == 0x100000c, 'Expected thin ARM64 Mach-O'
        cursor = 32
        builds = []
        for _ in range(commands):
            command, length = struct.unpack_from('<II', binary, cursor)
            assert length >= 8 and cursor + length <= len(binary), 'Invalid load command'
            if command == 0x32:
                platform, minimum, sdk = struct.unpack_from('<III', binary, cursor + 8)
                minimum_text = f'{minimum >> 16}.{(minimum >> 8) & 255}.{minimum & 255}'
                assert platform == 2, 'Simulator/Catalyst binary is not an iPhone binary'
                assert version(minimum_text) <= version(maximum), 'Mach-O minimum OS too high'
                builds.append(minimum_text)
            cursor += length
        assert len(builds) == 1, 'Missing or ambiguous LC_BUILD_VERSION'
    return {'bundle_id': info['CFBundleIdentifier'], 'version': expected,
            'plist_minimum_ios': info['MinimumOSVersion'], 'macho_minimum_ios': builds[0],
            'target_device_ios': maximum, 'platform': 'iPhoneOS', 'architecture': 'arm64',
            'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--max-minimum-ios', required=True)
    parser.add_argument('--expected-version', required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.ipa, args.max_minimum_ios, args.expected_version), indent=2))
