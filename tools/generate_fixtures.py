"""Generate interoperability fixtures with the vendor's downloaded Python protobuf.

Usage: python tools/generate_fixtures.py path/to/official/python_protogen
Requires protobuf. No API key, network call, or user recording is used.
"""
import json
from pathlib import Path
import sys

sys.path.insert(0, sys.argv[1])
sys.path.insert(0, str(Path(sys.argv[1]).resolve().parent))
from products.understanding.ast.ast_service_pb2 import TranslateRequest, TranslateResponse

root = Path(__file__).resolve().parents[1] / 'Tests' / 'CoreTests' / 'Fixtures'
root.mkdir(parents=True, exist_ok=True)
start = TranslateRequest()
start.request_meta.SessionID = 'interop-session'
start.event = 100
start.source_audio.format = 'wav'
start.source_audio.codec = 'raw'
start.source_audio.rate = 16000
start.source_audio.bits = 16
start.source_audio.channel = 1
start.target_audio.format = 'pcm'
start.target_audio.rate = 16000
start.request.mode = 's2s'
start.request.source_language = 'zh'
start.request.target_language = 'en'
audio = TranslateRequest()
audio.request_meta.SessionID = 'interop-session'
audio.event = 200
audio.source_audio.binary_data = bytes([0, 0, 255, 127, 0, 128])
finish = TranslateRequest()
finish.request_meta.SessionID = 'interop-session'
finish.event = 102
response = TranslateResponse()
response.response_meta.SessionID = 'interop-session'
response.response_meta.StatusCode = 20000000
response.event = 654
response.text = 'Hello, ��á�'
response.data = audio.source_audio.binary_data
failure = TranslateResponse()
failure.event = 153
failure.response_meta.StatusCode = 11200
failure.response_meta.Message = 'Permission denied'
for name, message in dict(start=start, audio=audio, finish=finish, response=response, failure=failure).items():
    data = message.SerializeToString(deterministic=True)
    (root / f'{name}.hex').write_text(data.hex() + '\n', encoding='ascii')
    print(name, len(data), data.hex())
(root / 'provenance.json').write_text(json.dumps({
    'generator': 'official AST Python protobuf generated bindings',
    'source': 'https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh',
    'session': 'synthetic interop-session; no credentials or real recordings'
}, indent=2), encoding='utf-8')
