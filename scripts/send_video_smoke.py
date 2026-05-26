#!/usr/bin/env python3
"""Send a small HEVC test stream using the RoboMaster UDP video packet format."""

from __future__ import annotations

import argparse
import json
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SAMPLE = REPO_ROOT / "build" / "rm-video-smoke.hevc"
DEFAULT_WIN_FFMPEG_DIR = REPO_ROOT / "build" / "thirdparty" / "ffmpeg-n7.1-win64-gpl-shared" / "bin"


def default_tool(name: str) -> str:
    exe = DEFAULT_WIN_FFMPEG_DIR / f"{name}.exe"
    if exe.exists():
        return str(exe)
    return name


def run(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
    except FileNotFoundError:
        raise SystemExit(f"Tool not found: {cmd[0]}")
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.output)


def generate_sample(path: Path, ffmpeg: str, frames: int, fps: int, size: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            ffmpeg,
            "-hide_banner",
            "-y",
            "-f",
            "lavfi",
            "-i",
            f"testsrc=size={size}:rate={fps}",
            "-frames:v",
            str(frames),
            "-c:v",
            "libx265",
            "-preset",
            "ultrafast",
            "-x265-params",
            "repeat-headers=1:keyint=1",
            "-f",
            "hevc",
            str(path),
        ]
    )


def read_hevc_packets(path: Path, ffprobe: str) -> list[bytes]:
    data = path.read_bytes()
    output = run(
        [
            ffprobe,
            "-v",
            "error",
            "-show_packets",
            "-select_streams",
            "v:0",
            "-show_entries",
            "packet=pos,size",
            "-of",
            "json",
            str(path),
        ]
    )
    packets = json.loads(output).get("packets", [])
    frames: list[bytes] = []
    for packet in packets:
        pos = int(packet["pos"])
        size = int(packet["size"])
        frames.append(data[pos : pos + size])
    return frames or [data]


def send_frames(
    frames: list[bytes],
    host: str,
    port: int,
    packet_size: int,
    frame_delay: float,
    byte_order: str,
    loop: bool,
) -> None:
    fmt = "<HHI" if byte_order == "le" else ">HHI"
    addr = (host, port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    frame_id = 0
    sent_frames = 0
    sent_packets = 0
    started = time.time()

    print(f"Sending {len(frames)} HEVC frames to udp://{host}:{port} ({byte_order})")
    print("Press Ctrl+C to stop.")
    try:
        while True:
            for frame in frames:
                for shard_id, start in enumerate(range(0, len(frame), packet_size)):
                    chunk = frame[start : start + packet_size]
                    header = struct.pack(fmt, frame_id & 0xFFFF, shard_id & 0xFFFF, len(frame))
                    sock.sendto(header + chunk, addr)
                    sent_packets += 1
                    time.sleep(0.001)
                frame_id = (frame_id + 1) & 0xFFFF
                sent_frames += 1
                time.sleep(frame_delay)

                if sent_frames % 30 == 0:
                    elapsed = max(time.time() - started, 0.001)
                    print(f"sent_frames={sent_frames} sent_packets={sent_packets} fps={sent_frames / elapsed:.1f}")

            if not loop:
                break
    except KeyboardInterrupt:
        print()

    elapsed = max(time.time() - started, 0.001)
    print(f"done sent_frames={sent_frames} sent_packets={sent_packets} elapsed={elapsed:.1f}s")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3334)
    parser.add_argument("--input", type=Path, default=DEFAULT_SAMPLE)
    parser.add_argument("--ffmpeg", default=default_tool("ffmpeg"))
    parser.add_argument("--ffprobe", default=default_tool("ffprobe"))
    parser.add_argument("--frames", type=int, default=120)
    parser.add_argument("--fps", type=int, default=15)
    parser.add_argument("--size", default="640x360")
    parser.add_argument("--packet-size", type=int, default=1400)
    parser.add_argument("--frame-delay", type=float, default=1.0 / 15.0)
    parser.add_argument("--byte-order", choices=("le", "be"), default="le")
    parser.add_argument("--loop", action="store_true")
    parser.add_argument("--no-generate", action="store_true")
    args = parser.parse_args()

    if not args.input.exists():
        if args.no_generate:
            raise SystemExit(f"Input HEVC file does not exist: {args.input}")
        print(f"Generating HEVC sample: {args.input}")
        generate_sample(args.input, args.ffmpeg, args.frames, args.fps, args.size)

    frames = read_hevc_packets(args.input, args.ffprobe)
    if not frames or not any(frames):
        raise SystemExit(f"No HEVC frames found in {args.input}")

    send_frames(
        frames=frames,
        host=args.host,
        port=args.port,
        packet_size=args.packet_size,
        frame_delay=args.frame_delay,
        byte_order=args.byte_order,
        loop=args.loop,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
