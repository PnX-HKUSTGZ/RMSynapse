#!/usr/bin/env python3
"""Send HUD receive topics through RMRefService and verify Godot HudDataBridge updates."""

from __future__ import annotations

import argparse
import base64
import json
import os
import queue
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
GODOT_PROJECT = REPO_ROOT / "rm_synapse"

GODOT_SCENE = "net/mqtt/tests/hud_api_receive_scene_test.tscn"

# 测试超参：每个 HUD topic 测试之间的等待时间，单位为秒。
TEST_INTERVAL_SEC = 0.5

TOPIC_TEST_DESCRIPTIONS = {
    "GameStatus": "比赛状态更新",
    "GlobalUnitStatus": "全局单位状态更新",
    "GlobalLogisticsStatus": "全局经济与科技状态更新",
    "GlobalSpecialMechanism": "全局特殊机制状态更新",
    "Event": "裁判系统事件更新",
    "RobotInjuryStat": "机器人伤害统计更新",
    "RobotRespawnStatus": "机器人复活状态更新",
    "RobotStaticStatus": "机器人静态属性更新",
    "RobotDynamicStatus": "机器人动态属性更新",
    "RobotModuleStatus": "机器人模块状态更新",
    "RobotPosition": "机器人位置姿态更新",
    "Buff": "机器人增益状态更新",
    "PenaltyInfo": "判罚信息更新",
    "RobotPathPlanInfo": "机器人路径规划信息更新",
    "RadarInfoToClient": "雷达目标信息更新",
    "RobotPerformanceSelectionSync": "机器人性能选择同步更新",
    "DeployModeStatusSync": "部署模式状态同步更新",
    "TechCoreMotionStateSync": "技术核心运动状态同步更新",
    "RuneStatusSync": "符文状态同步更新",
    "SentryStatusSync": "哨兵状态同步更新",
    "DartSelectTargetStatusSync": "飞镖目标选择状态同步更新",
    "SentryCtrlResult": "哨兵控制结果更新",
    "AirSupportStatusSync": "空中支援状态同步更新",
    "CustomByteBlock": "自定义字节块更新",
}

HUD_TOPICS = [
    "GameStatus",
    "GlobalUnitStatus",
    "GlobalLogisticsStatus",
    "GlobalSpecialMechanism",
    "Event",
    "RobotInjuryStat",
    "RobotRespawnStatus",
    "RobotStaticStatus",
    "RobotDynamicStatus",
    "RobotModuleStatus",
    "RobotPosition",
    "Buff",
    "PenaltyInfo",
    "RobotPathPlanInfo",
    "RadarInfoToClient",
    "RobotPerformanceSelectionSync",
    "DeployModeStatusSync",
    "TechCoreMotionStateSync",
    "RuneStatusSync",
    "SentryStatusSync",
    "DartSelectTargetStatusSync",
    "SentryCtrlResult",
    "AirSupportStatusSync",
    "CustomByteBlock",
]

PAYLOAD_PATCHES: dict[str, dict[str, Any]] = {
    "GameStatus": {
        "current_round": 2,
        "total_rounds": 5,
        "red_score": 3,
        "blue_score": 4,
        "current_stage": 4,
        "stage_countdown_sec": 345,
        "stage_elapsed_sec": 75,
        "is_paused": True,
    },
    "GlobalUnitStatus": {
        "base_health": 4200,
        "base_status": 2,
        "base_shield": 350,
        "outpost_health": 1450,
        "outpost_status": 1,
        "enemy_base_health": 3900,
        "enemy_base_status": 1,
        "enemy_base_shield": 250,
        "enemy_outpost_health": 1250,
        "enemy_outpost_status": 2,
        "robot_health": [2000, 400, 380, 0, 530, 1800, 0, 1200, 0, 900],
        "robot_bullets": [50, 20, 18, 0, 8, 45, 0, 25, 0, 12],
        "total_damage_ally": 1260,
        "total_damage_enemy": 980,
    },
    "GlobalLogisticsStatus": {
        "remaining_economy": 1260,
        "total_economy_obtained": 3400,
        "tech_level": 2,
        "encryption_level": 5,
    },
    "GlobalSpecialMechanism": {
        "mechanism_id": [1, 2],
        "mechanism_time_sec": [45, 30],
    },
    "Event": {"event_id": 16, "param": "1"},
    "RobotInjuryStat": {
        "total_damage": 250,
        "collision_damage": 10,
        "small_projectile_damage": 80,
        "large_projectile_damage": 90,
        "dart_splash_damage": 20,
        "module_offline_damage": 15,
        "offline_damage": 5,
        "penalty_damage": 12,
        "server_kill_damage": 18,
        "killer_id": 103,
    },
    "RobotRespawnStatus": {
        "is_pending_respawn": True,
        "total_respawn_progress": 100,
        "current_respawn_progress": 35,
        "can_free_respawn": True,
        "gold_cost_for_respawn": 120,
        "can_pay_for_respawn": True,
    },
    "RobotStaticStatus": {
        "connection_state": 1,
        "field_state": 1,
        "alive_state": 1,
        "robot_id": 1,
        "robot_type": 1,
        "performance_system_shooter": 2,
        "performance_system_chassis": 1,
        "level": 2,
        "max_health": 4500,
        "max_heat": 250,
        "heat_cooldown_rate": 12.5,
        "max_power": 120,
        "max_buffer_energy": 60,
        "max_chassis_energy": 150,
    },
    "RobotDynamicStatus": {
        "current_health": 3980,
        "current_heat": 120.5,
        "last_projectile_fire_rate": 8.0,
        "current_chassis_energy": 90,
        "current_buffer_energy": 45,
        "current_experience": 850,
        "experience_for_upgrade": 1000,
        "total_projectiles_fired": 36,
        "remaining_ammo": 42,
        "is_out_of_combat": False,
        "out_of_combat_countdown": 0,
        "can_remote_heal": True,
        "can_remote_ammo": False,
    },
    "RobotModuleStatus": {
        "power_manager": 1,
        "rfid": 1,
        "light_strip": 1,
        "small_shooter": 1,
        "big_shooter": 0,
        "uwb": 1,
        "armor": 2,
        "video_transmission": 1,
        "capacitor": 1,
        "main_controller": 1,
        "laser_detection_module": 1,
    },
    "RobotPosition": {"x": 12.5, "y": 4.75, "z": 0.25, "yaw": 135.0},
    "Buff": {
        "robot_id": 1,
        "buff_type": 3,
        "buff_level": 2,
        "buff_max_time": 60,
        "buff_left_time": 42,
    },
    "PenaltyInfo": {"penalty_type": 2, "penalty_effect_sec": 15, "total_penalty_num": 3},
    "RobotPathPlanInfo": {
        "intention": 2,
        "start_pos_x": 100,
        "start_pos_y": 200,
        "offset_x": [10, 20, -5],
        "offset_y": [5, -10, 15],
        "sender_id": 7,
    },
    "RadarInfoToClient": {
        "target_robot_id": 101,
        "target_pos_x": 8.5,
        "target_pos_y": 6.25,
        "torward_angle": 90.0,
        "is_high_light": 1,
    },
    "RobotPerformanceSelectionSync": {"shooter": 2, "chassis": 1, "sentry_control": 1},
    "DeployModeStatusSync": {"status": 1},
    "TechCoreMotionStateSync": {
        "maximum_difficulty_level": 3,
        "status": 2,
        "enemy_core_status": 1,
        "remain_time_all": 120,
        "remain_time_step": 30,
    },
    "RuneStatusSync": {"rune_status": 1, "activated_arms": 4, "average_rings": 8},
    "SentryStatusSync": {"posture_id": 8, "is_weakened": True},
    "DartSelectTargetStatusSync": {"target_id": 2, "open": 1},
    "SentryCtrlResult": {"command_id": 8, "result_code": 1},
    "AirSupportStatusSync": {
        "airsupport_status": 2,
        "left_time": 18,
        "cost_coins": 300,
        "is_being_targeted": 1,
        "shooter_status": 2,
    },
    "CustomByteBlock": {"data": base64.b64encode(bytes([1, 2, 3, 254])).decode("ascii")},
}


def request_json(method: str, base_url: str, path: str, body: dict[str, Any] | None = None) -> Any:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        payload = response.read()
    if not payload:
        return None
    return json.loads(payload.decode("utf-8"))


def build_payloads(base_url: str) -> dict[str, dict[str, Any]]:
    protocol = request_json("GET", base_url, "/api/protocol")
    defaults = protocol.get("defaults", {})
    payloads: dict[str, dict[str, Any]] = {}
    missing = [topic for topic in HUD_TOPICS if topic not in defaults]
    if missing:
        raise RuntimeError(
            f"RMRefService protocol missing HUD topics: {', '.join(missing)}")
    for topic in HUD_TOPICS:
        payload = dict(defaults[topic])
        payload.update(PAYLOAD_PATCHES[topic])
        payloads[topic] = payload
    return payloads


def enqueue_output(process: subprocess.Popen[str], output: queue.Queue[str]) -> None:
    assert process.stdout is not None
    for line in process.stdout:
        output.put(line.rstrip("\n"))


def wait_for_ready(process: subprocess.Popen[str], output: queue.Queue[str], timeout: float) -> list[str]:
    deadline = time.monotonic() + timeout
    lines: list[str] = []
    while time.monotonic() < deadline:
        if process.poll() is not None:
            break
        try:
            line = output.get(timeout=0.1)
        except queue.Empty:
            continue
        lines.append(line)
        print(line)
        if line.strip() == "HUD_API_RECEIVE_READY":
            return lines
    raise RuntimeError(
        "Godot HUD API receive scene did not become ready before timeout")


def drain_output(output: queue.Queue[str]) -> list[str]:
    lines: list[str] = []
    while True:
        try:
            line = output.get_nowait()
        except queue.Empty:
            break
        lines.append(line)
        print(line)
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--api-base", default=os.environ.get("RMREF_API_BASE", "http://127.0.0.1:8000"))
    parser.add_argument(
        "--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--project", default=str(GODOT_PROJECT))
    parser.add_argument("--ready-timeout", type=float, default=12.0)
    parser.add_argument("--finish-timeout", type=float, default=20.0)
    parser.add_argument("--post-ready-delay", type=float, default=1.0)
    # parser.add_argument("--send-delay", type=float, default=0.05)
    args = parser.parse_args()

    payloads = build_payloads(args.api_base)
    try:
        request_json("POST", args.api_base, "/api/senders/stop-all", {})
    except (urllib.error.URLError, TimeoutError):
        pass

    command = [
        args.godot,
        "--headless",
        "--path",
        args.project,
        "--scene",
        GODOT_SCENE,
    ]
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    output: queue.Queue[str] = queue.Queue()
    thread = threading.Thread(target=enqueue_output,
                              args=(process, output), daemon=True)
    thread.start()

    all_lines: list[str] = []
    try:
        all_lines.extend(wait_for_ready(process, output, args.ready_timeout))
        time.sleep(args.post_ready_delay)
        for index, topic in enumerate(HUD_TOPICS, start=1):
            description = TOPIC_TEST_DESCRIPTIONS.get(topic, topic)
            print(f"测试 {index}/{len(HUD_TOPICS)}：{description}（topic={topic}）")
            request_json(
                "POST",
                args.api_base,
                f"/api/topics/{topic}/send",
                {"payload": payloads[topic], "qos": 0, "retain": False},
            )
            print(f"API_SENT {topic}：已发送测试数据，等待 {TEST_INTERVAL_SEC:.2f} 秒后进入下一个测试")
            time.sleep(TEST_INTERVAL_SEC)
        return_code = process.wait(timeout=args.finish_timeout)
        all_lines.extend(drain_output(output))
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
        all_lines.extend(drain_output(output))
        raise
    finally:
        try:
            request_json("POST", args.api_base, "/api/senders/stop-all", {})
        except (urllib.error.URLError, TimeoutError):
            pass

    received = {
        json.loads(line.split(" ", 1)[1])["topic"]
        for line in all_lines
        if line.startswith("HUD_API_RECV ")
    }
    missing = [topic for topic in HUD_TOPICS if topic not in received]
    if return_code != 0:
        print(f"Godot exited with {return_code}", file=sys.stderr)
        return return_code or 1
    if missing:
        print(
            f"Missing HudDataBridge updates: {', '.join(missing)}", file=sys.stderr)
        return 1
    print("HUD_API_RECEIVE_TEST_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
