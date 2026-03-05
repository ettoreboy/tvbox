#!/usr/bin/env python3
"""
CEC channel switcher daemon: listen to TV remote (cec-client), switch Wayland
focus to the configured channel (app_id) via wlrctl. Runs in the user session.
"""
import os
import re
import shutil
import subprocess
import sys
import threading
import time

CONFIG_DIR = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")) + "/tvbox"
CONFIG_FILE = f"{CONFIG_DIR}/channel-config"
CEC_PARSER_VERSION = "2025-03-python"


def log(msg: str) -> None:
    print(msg, flush=True)


def load_config() -> tuple[dict, dict, dict, dict, int]:
    """Load channel-config. Returns (channel_app, channel_start, channel_left, channel_right, max_channel)."""
    channel_app = {}
    channel_start = {}
    channel_left = {}
    channel_right = {}
    max_channel = 0

    if not os.path.isfile(CONFIG_FILE):
        return channel_app, channel_start, channel_left, channel_right, max_channel

    with open(CONFIG_FILE) as f:
        for raw in f:
            line = raw.split("#")[0].strip()
            if not line or "=" not in line:
                continue
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip()

            if re.match(r"^\d+$", key):
                n = int(key)
                channel_app[key] = val
                max_channel = max(max_channel, n)
            elif m := re.match(r"^(\d+)_start$", key):
                channel_start[m.group(1)] = val
            elif m := re.match(r"^(\d+)_left$", key):
                channel_left[m.group(1)] = val
            elif m := re.match(r"^(\d+)_right$", key):
                channel_right[m.group(1)] = val

    if max_channel == 0 and "1" in channel_app:
        max_channel = 1

    return channel_app, channel_start, channel_left, channel_right, max_channel


def show_channel_osd(num: str, app_id: str) -> None:
    if shutil.which("notify-send"):
        subprocess.run(
            ["notify-send", "-t", "1500", "-h", "string:x-canonical-private-synchronous:cec-channel", f"Channel {num}", app_id],
            capture_output=True,
            timeout=2,
        )


def focus_channel(
    num: str,
    channel_app: dict,
    channel_start: dict,
) -> bool:
    app_id = channel_app.get(num)
    if not app_id:
        return False

    start_cmd = channel_start.get(num)

    if shutil.which("wlrctl"):
        # When switching to picframe, minimize chromium so it doesn't stay on top
        if app_id == "picframe":
            subprocess.run(
                ["wlrctl", "window", "minimize", "app_id:chromium"],
                capture_output=True,
                timeout=2,
            )
        selectors = [f"app_id:{app_id}", f"title:{app_id}"]
        if app_id == "picframe":
            selectors.extend(["app_id:python3.13", "app_id:python3"])  # fallback: pi3d reports python
        if app_id == "chromium":
            selectors.extend(["app_id:Chromium"])  # case variant
        for selector in selectors:
            r = subprocess.run(["wlrctl", "window", "focus", selector], capture_output=True, timeout=2)
            if r.returncode == 0:
                show_channel_osd(num, app_id)
                log(f"channel {num}: {app_id} (ok)")
                return True
        log(f"channel {num}: {app_id} (no window)")
    else:
        log(f"channel {num}: {app_id} (wlrctl not found)")

    if start_cmd:

        def run_start():
            subprocess.Popen(start_cmd, shell=True)
            time.sleep(2)
            if shutil.which("wlrctl"):
                selectors = [f"app_id:{app_id}", f"title:{app_id}"]
                if app_id == "picframe":
                    selectors.extend(["app_id:python3.13", "app_id:python3"])
                if app_id == "chromium":
                    selectors.extend(["app_id:Chromium"])
                for selector in selectors:
                    r = subprocess.run(["wlrctl", "window", "focus", selector], capture_output=True, timeout=2)
                    if r.returncode == 0:
                        show_channel_osd(num, app_id)
                        break

        log(f"channel {num}: starting {start_cmd}")
        threading.Thread(target=run_start, daemon=True).start()

    return False


def parse_key_line(line: str) -> str | None:
    """Parse cec-client output. Returns key string or None."""
    line = line.replace("\r", "")
    if "key pressed:" not in line:
        return None

    # Directional / special keys
    if "key pressed: channel up" in line:
        return "channelup"
    if "key pressed: channel down" in line:
        return "channeldown"
    if "key pressed: left" in line:
        return "left"
    if "key pressed: right" in line:
        return "right"
    if "key pressed: up" in line:
        return "up"
    if "key pressed: down" in line:
        return "down"

    # Digits 0-9 (cec-client format: "key pressed: 2 (22, 0)" or "key pressed: 1 (21)")
    for n in "1", "2", "3", "4", "5", "6", "7", "8", "9", "0":
        if f"key pressed: {n} " in line or f"key pressed: {n}(" in line or f"key pressed: {n} (" in line:
            return n

    return None


def main() -> None:
    log(f"started (parser {CEC_PARSER_VERSION})")

    channel_app, channel_start, channel_left, channel_right, max_channel = load_config()
    if max_channel == 0:
        print(f"error: no channels in {CONFIG_FILE}", file=sys.stderr)
        sys.exit(1)

    current_channel = "1"
    osd_name = os.environ.get("CEC_OSD_NAME") or (os.uname().nodename if hasattr(os, "uname") else "tvbox")
    osd_name = (osd_name or "tvbox")[:14]

    log(f"listening (channels 1-{max_channel}, OSD: {osd_name})")
    if os.environ.get("CEC_DEBUG"):
        log(f"debug mode on (CEC_DEBUG={os.environ.get('CEC_DEBUG')}): unparsed key lines will be logged")

    # On boot: focus channel 1 (picframe) so it's visible, not whatever else might be on top
    time.sleep(8)  # wait for labwc + picframe to be ready
    focus_channel("1", channel_app, channel_start)
    log("boot: focused channel 1")

    if not shutil.which("cec-client"):
        print("error: cec-client not found", file=sys.stderr)
        sys.exit(1)

    last_key = None
    last_key_time = 0.0

    while True:
        proc = None
        try:
            proc = subprocess.Popen(
                ["cec-client", "-o", osd_name],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            # Keep stdin open (never close) so cec-client doesn't exit on EOF
            assert proc.stdin is not None

            for line in proc.stdout or []:
                line = line.rstrip("\n").replace("\r", "")
                if "physical address" in line and "invalid" in line:
                    log("cec: physical address invalid (TV may not send keys)")

                key = parse_key_line(line)
                if key:
                    now = time.time()
                    if key == last_key and (now - last_key_time) < 0.5:
                        continue  # debounce duplicate key presses

                    last_key = key
                    last_key_time = now
                    log(f"key: {key}")
                    current_channel = on_key(
                        key,
                        current_channel,
                        max_channel,
                        channel_app,
                        channel_start,
                        channel_left,
                        channel_right,
                    )
                elif os.environ.get("CEC_DEBUG") and "key" in line and "press" in line:
                    log(f"unparsed: {line[:100]}")

        except Exception as e:
            log(f"cec-client error: {e}")
        finally:
            if proc:
                try:
                    proc.terminate()
                    proc.wait(timeout=5)
                except Exception:
                    pass

        log("cec-client exited, retry in 15s")
        time.sleep(15)


def on_key(
    key: str,
    current_channel: str,
    max_channel: int,
    channel_app: dict,
    channel_start: dict,
    channel_left: dict,
    channel_right: dict,
) -> str:
    """Handle key. Returns new current_channel."""
    if key in "123456789":
        focus_channel(key, channel_app, channel_start)
        return key
    if key == "0":
        focus_channel("1", channel_app, channel_start)
        return "1"
    if key in ("channelup", "chup", "up"):
        n = int(current_channel)
        next_n = (n % max_channel) + 1
        focus_channel(str(next_n), channel_app, channel_start)
        return str(next_n)
    if key in ("channeldown", "chdown", "down"):
        n = int(current_channel)
        next_n = max_channel if n <= 1 else n - 1
        focus_channel(str(next_n), channel_app, channel_start)
        return str(next_n)
    if key == "left":
        cmd = channel_left.get(current_channel)
        if cmd:
            log(f"channel {current_channel}: left -> {cmd}")
            subprocess.Popen(cmd, shell=True)
    elif key == "right":
        cmd = channel_right.get(current_channel)
        if cmd:
            log(f"channel {current_channel}: right -> {cmd}")
            subprocess.Popen(cmd, shell=True)
    return current_channel


if __name__ == "__main__":
    main()
