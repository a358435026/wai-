"""Choose an installed iPhone runtime supported by the active Xcode SDK."""
import json
import sys


def version(text):
    return tuple((list(map(int, text.replace('-', '.').split('.'))) + [0, 0])[:3])


def select(inventory, sdk):
    candidates = []
    for runtime, devices in inventory['devices'].items():
        prefix = 'com.apple.CoreSimulator.SimRuntime.iOS-'
        if not runtime.startswith(prefix):
            continue
        release = version(runtime[len(prefix):])
        if not (version('15.0') <= release <= version(sdk)):
            continue
        for device in devices:
            if device.get('isAvailable') and device['name'].startswith('iPhone'):
                candidates.append((release, runtime, device))
    if not candidates:
        raise RuntimeError(f'No installed iPhone runtime compatible with SDK {sdk}')
    return max(candidates, key=lambda entry: entry[0])


if __name__ == '__main__':
    with open(sys.argv[1], encoding='utf-8') as file:
        _, runtime, device = select(json.load(file), sys.argv[2])
    print('SIMULATOR_ID=' + device['udid'])
    print('SIMULATOR_RUNTIME=' + runtime)
