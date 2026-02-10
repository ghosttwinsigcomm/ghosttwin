from scapy.all import *
from scapy.fields import *
from collections import defaultdict
import threading
import argparse
import time
import os
import paramiko
import logging
import getpass
from datetime import datetime

# ============================================================
# Logging
# ============================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("log.log")
    ]
)

logger = logging.getLogger("showInfo")

# ============================================================
# Remote configuration
# ============================================================

REMOTE_HOST = "192.168.102.2"
REMOTE_USER = "ubuntu"
REMOTE_SCRIPT = "/home/ubuntu/digital-twin/generate_topology_txt.py"

sudo_password = None

# ============================================================
# Custom Headers
# ============================================================

class MonitorInst(Packet):
    name = "MonitorInst"
    fields_desc = [
        IntField("index_flow", 0),
        IntField("index_port", 0),
        BitField("port", 0, 9),
        BitField("padding", 0, 7)
    ]


class Monitor(Packet):
    name = "Monitor"
    fields_desc = [
        LongField("bytes_flow", 0),
        LongField("bytes_port", 0),
        BitField("timestamp", 0, 48),
        BitField("port", 0, 9),
        BitField("padding", 0, 7),
        ShortField("pktLen", 0),
        IntField("qID_port", 0),
        IntField("qDepth_port", 0),
        IntField("qTime_port", 0),
        IntField("qID_flow", 0),
        IntField("qDepth_flow", 0),
        IntField("qTime_flow", 0)
    ]


bind_layers(Ether, MonitorInst, type=0x1234)
bind_layers(MonitorInst, Monitor)

# ============================================================
# Shared state
# ============================================================

lock = threading.Lock()

prev_state = {
    "flow": defaultdict(lambda: {"bytes": 0, "ts": 0}),
    "port": defaultdict(lambda: {"bytes": 0, "ts": 0})
}

throughput_mbps = {
    "flow": defaultdict(float),
    "port": defaultdict(float)
}

last_seen = {
    "flow": defaultdict(float),
    "port": defaultdict(float)
}

# ============================================================
# Helpers
# ============================================================

def wallclock():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]


def compute_mbps(delta_bytes, delta_time_ns):
    if delta_time_ns <= 0:
        return 0.0
    return (delta_bytes * 8) / (delta_time_ns / 1e9) / 1e6


# ============================================================
# Packet processing
# ============================================================

def process_packet(pkt):
    if Monitor not in pkt:
        return

    inst = pkt[MonitorInst]
    mon = pkt[Monitor]

    now = time.time()

    flow_id = inst.index_flow
    port_id = inst.index_port

    with lock:
        # ---------------- FLOW ----------------
        if flow_id != 0:
            prev = prev_state["flow"][flow_id]
            mbps = compute_mbps(
                mon.bytes_flow - prev["bytes"],
                mon.timestamp - prev["ts"]
            )

            throughput_mbps["flow"][flow_id] = mbps
            prev_state["flow"][flow_id] = {
                "bytes": mon.bytes_flow,
                "ts": mon.timestamp
            }
            last_seen["flow"][flow_id] = now

        # ---------------- PORT ----------------
        if port_id != 0:
            prev = prev_state["port"][port_id]
            mbps = compute_mbps(
                mon.bytes_port - prev["bytes"],
                mon.timestamp - prev["ts"]
            )

            throughput_mbps["port"][port_id] = mbps
            prev_state["port"][port_id] = {
                "bytes": mon.bytes_port,
                "ts": mon.timestamp
            }
            last_seen["port"][port_id] = now

        # ---------------- LOG PER PACKET ----------------
        logger.info(
            "PKT flow=%d port=%d "
            "bytes_flow=%d bytes_port=%d "
            "qDepth_flow=%d qDepth_port=%d "
            "flow_mbps=%.2f port_mbps=%.2f",
            flow_id,
            port_id,
            mon.bytes_flow,
            mon.bytes_port,
            mon.qDepth_flow,
            mon.qDepth_port,
            throughput_mbps["flow"].get(flow_id, 0.0),
            throughput_mbps["port"].get(port_id, 0.0)
        )

# ============================================================
# Remote topology update
# ============================================================

def update_topology(client, mbps, latency=0, jitter=0, loss=0):
    content = f"s1 s2 {int(mbps)} {latency} {jitter} {loss}"
    cmd = f"sudo python3 {REMOTE_SCRIPT} change {content}"

    stdin, stdout, stderr = client.exec_command(cmd)
    if sudo_password:
        stdin.write(sudo_password + "\n")
        stdin.flush()

    err = stderr.read().decode().strip()
    if err and "password" not in err.lower():
        logger.error(f"Topology update failed: {err}")
        return

    logger.info(f"Topology updated: {content}")

# ============================================================
# Display + control loop
# ============================================================

def control_loop(client):
    try:
        client.connect(REMOTE_HOST, username=REMOTE_USER)
        logger.info("SSH connected")
    except Exception as e:
        logger.error(f"SSH failed: {e}")
        return

    last_update = 0

    while True:
        time.sleep(1)
        os.system("clear")
        now = time.time()

        with lock:
            print("\n=== Throughput ===")

            for pid, mbps in throughput_mbps["port"].items():
                if now - last_seen["port"][pid] <= 1:
                    print(f"Port {pid}: {mbps:.2f} Mbps")

                    if now - last_update >= 2:
                        update_topology(client, mbps)
                        last_update = now

    client.close()

# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iface", default="enp6s0f0")
    parser.add_argument("--sudo-password", default="123asd987lkj")
    args = parser.parse_args()
    global sudo_password
    sudo_password = args.sudo_password or getpass.getpass("Remote sudo password (Enter if none): ")
    if sudo_password == "":
        sudo_password = None

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    threading.Thread(
        target=control_loop,
        args=(client,),
        daemon=True
    ).start()

    logger.info(f"Sniffing on {args.iface}")
    sniff(
        iface=args.iface,
        filter="ether proto 0x1234",
        prn=process_packet
    )


if __name__ == "__main__":
    main()
