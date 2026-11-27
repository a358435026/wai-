"""Personal, bounded Qwen 3.8 translation probe. Credentials stay in process memory."""
import asyncio
import base64
import contextlib
import getpass
import io
import json
import re
import socket
import sys
import wave
from collections import Counter
from datetime import datetime
from pathlib import Path
from urllib.parse import urlsplit

import websockets

MODEL = "qwen3.8-livetranslate-flash-realtime"


def normalize_host(value):
    value = value.strip()
    if "://" in value:
        value = urlsplit(value).hostname or ""
    value = value.rstrip("/").lower()
    if not re.fullmatch(r"[a-z0-9-]+\.cn-beijing\.maas\.aliyuncs\.com", value):
        raise ValueError("请复制北京业务空间的 API Host，形如 实际空间ID.cn-beijing.maas.aliyuncs.com；不是账号ID或API Key。")
    if value.startswith(("workspaceid.", "yourworkspaceid.")):
        raise ValueError("这是文档占位符，请复制你自己的业务空间 API Host。")
    return value


def read_sample(path):
    with wave.open(str(path), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getcomptype()) != (1, 2, 16000, "NONE"):
            raise ValueError("测试音频需要16kHz、单声道、PCM16 WAV。")
        return wav.readframes(16000 * 12)


def proxy_tunnel(host):
    # Reuse the user's existing HTTP proxy, never change Windows/VPN settings.
    tunnel = socket.create_connection(("127.0.0.1", 10809), timeout=15)
    try:
        tunnel.sendall(f"CONNECT {host}:443 HTTP/1.1\r\nHost: {host}:443\r\n\r\n".encode("ascii"))
        reply = bytearray()
        while not reply.endswith(b"\r\n\r\n"):
            chunk = tunnel.recv(1)
            if not chunk or len(reply) > 16384:
                raise RuntimeError("现有代理未完成连接，请保持VPN开启。")
            reply.extend(chunk)
        if b" 200 " not in reply.split(b"\r\n", 1)[0]:
            raise RuntimeError("现有代理拒绝建立连接；没有改动VPN。")
        tunnel.setblocking(False)
        return tunnel
    except BaseException:
        tunnel.close()
        raise


async def run_session(ws, pcm, result, audio, log=print, pace=0.08, target="en", speech=True):
    sources, translations = {}, {}
    counts = Counter()

    async def receive():
        event = json.loads(await asyncio.wait_for(ws.recv(), timeout=30))
        kind = event.get("type", "unknown")
        counts[kind] += 1
        if kind == "error" or kind.endswith("transcription.failed"):
            error = event.get("error", {})
            raise RuntimeError(f"服务错误 {error.get('code', 'unknown')}: {error.get('message', '')}")
        item = event.get("item_id") or event.get("response_id") or "default"
        if kind == "conversation.item.input_audio_transcription.delta":
            sources[item] = sources.get(item, "") + event.get("delta", "")
        elif kind == "conversation.item.input_audio_transcription.completed":
            sources[item] = event.get("transcript", sources.get(item, ""))
        elif kind in ("response.audio_transcript.delta", "response.text.delta"):
            translations[item] = translations.get(item, "") + event.get("delta", "")
        elif kind == "response.audio.delta":
            audio.extend(base64.b64decode(event["delta"], validate=True))
            if len(audio) > 32 * 1024 * 1024:
                raise RuntimeError("返回音频超出短测上限，已停止。")
        result.update(events=dict(counts), source="\n".join(sources.values()),
                      translation="\n".join(translations.values()), audio_bytes=len(audio))
        return kind

    async def wait_for(kind):
        async with asyncio.timeout(30):
            while await receive() != kind:
                pass

    await wait_for("session.created")
    log("已连接；正在验证模型权限和会话配置……", flush=True)
    await ws.send(json.dumps({"type": "session.update", "session": {
        "input_modalities": ["audio"], "output_modalities": ["text", "audio"] if speech else ["text"],
        "audio": {"input": {"format": {"type": "pcm", "sample_rate": 16000},
                            "turn_detection": {"type": "speaker_detection", "threshold": 0.5}},
                  "output": {"voice": "Tina"}},
        "enable_voice_clone": False, "translation": {"language": target}}}))
    await wait_for("session.updated")
    log("配置已确认；上传最多12秒测试音频，不使用麦克风……", flush=True)

    async def send_audio():
        payload = pcm + bytes(16000)  # 0.5 seconds of trailing silence.
        for offset in range(0, len(payload), 2560):
            await ws.send(json.dumps({"type": "input_audio_buffer.append",
                                      "audio": base64.b64encode(payload[offset:offset + 2560]).decode("ascii")}))
            result["packets_sent"] += 1
            await asyncio.sleep(pace)
        await ws.send(json.dumps({"type": "session.finish"}))

    sender = asyncio.create_task(send_audio())
    try:
        async with asyncio.timeout(90):
            await wait_for("session.finished")
        await sender
        result["session_finished"] = True
    finally:
        sender.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await sender
    result["ok"] = bool(result["source"].strip() and result["translation"].strip() and
                        (bool(audio) if speech else not audio) and result["session_finished"])
    if not result["ok"]:
        raise RuntimeError("连接已结束，但原文/译文/译音不完整，不能算测试通过。")


def write_audio(path, audio):
    if not audio:
        return
    if audio[:4] == b"RIFF":
        with wave.open(io.BytesIO(audio), "rb") as wav:
            if wav.getnframes() == 0:
                raise ValueError("返回的WAV音频为空。")
        path.write_bytes(audio)
    else:
        with wave.open(str(path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(24000)
            wav.writeframes(audio)


async def probe(host, key, sample, result, audio, target="en", speech=True):
    url = f"wss://{host}/api-ws/v1/realtime?model={MODEL}"
    tunnel = await asyncio.to_thread(proxy_tunnel, host)
    try:
        async with websockets.connect(url, sock=tunnel,
                extra_headers={"Authorization": "Bearer " + key},
                open_timeout=20, close_timeout=3, max_size=4 * 1024 * 1024) as ws:
            await run_session(ws, sample, result, audio, target=target, speech=speech)
    finally:
        tunnel.close()


def main():
    print("百炼实时同传短测：中文样例 → 英文字幕和英文语音。\n最多上传12秒；会产生少量模型调用费用。不会修改VPN、不会读取麦克风、不会保存Key。\n")
    folder = Path(__file__).resolve().parent
    try:
        host_file = folder / "bailian-host.txt"
        if host_file.exists():
            host = normalize_host(host_file.read_text(encoding="utf-8-sig"))
            print("业务空间地址已配置：", host)
        else:
            host = normalize_host(input("粘贴北京业务空间 API Host，再回车：\n> "))
        key = getpass.getpass("粘贴完整 API Key，再回车（不回显属正常）：\n> ").strip()
        if not key.startswith("sk-") or "*" in key or any(c.isspace() for c in key):
            raise ValueError("需要完整的百炼Key，截图或带星号的脱敏值不能使用。")
        sample = read_sample(folder / "test_audio.wav")
    except (ValueError, OSError, EOFError) as exc:
        print(str(exc))
        return 2
    output = folder / ("结果-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    output.mkdir()
    result = {"ok": False, "model": MODEL, "packets_sent": 0, "session_finished": False,
              "source": "", "translation": "", "audio_bytes": 0, "events": {}}
    audio = bytearray()
    try:
        asyncio.run(probe(host, key, sample, result, audio))
        write_audio(output / "translation.wav", audio)
    except Exception as exc:
        result["ok"] = False
        result["error"] = (str(exc) or type(exc).__name__).replace(key, "[已隐藏密钥]")
    finally:
        key = ""
    (output / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print("\n" + ("测试通过：原文、英文译文、译音和正常结束均已收到。" if result["ok"] else "测试未通过：" + result.get("error", "结果不完整")))
    print("原文：", result["source"])
    print("译文：", result["translation"])
    print("结果目录：", output)
    if result["ok"]:
        try:
            import winsound
            winsound.PlaySound(str(output / "translation.wav"), winsound.SND_FILENAME)
        except Exception:
            print("自动播放失败，可打开 translation.wav 检查译音。")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
