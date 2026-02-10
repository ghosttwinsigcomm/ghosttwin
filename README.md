# GhostTwin

> GhostTwin is a digital-twin framework designed to operate on the NVIDIA BlueField-2 (BF2) platform and interface with a P4-programmable Tofino data plane. The framework provides automation scripts and reference P4 programs that enable the creation and control of network topologies, execution of monitoring workflows, and generation of a Digital Twin.

## Table of contents
- What is GhostTwin?
- Requirements
- HowTo (quick start) — primary section
  - Prepare the BF2 environment
  - Run Tofino / P4 components
  - Host-side traffic and monitoring
- Repository layout
- Troubleshooting
- Contributing

## What is GhostTwin?

GhostTwin is a framework for deploying and operating network digital twin (NDT) experiments in a programmable networking environment. It is built as a SmartNIC-based emulation of programmable networks, enabling reproducible experimentation with digital twin synchronization, topology deployment, telemetry collection, and traffic generation.

## Requirements

- A Linux workstation with a BlueField-2 SmartNIC connected.
- An Intel (Barefoot) Tofino 1 switch or development board (hardware).


## HowTo (quick start)

This section gives a concise, runnable set of steps to get GhostTwin up and running. Adjust commands for your environment and privilege model (some steps may require root or BF2-specific configuration).

### Prepare the BF-2 environment


1) Clone or copy the repository to your BF2 

2) Install Python dependencies

```bash
# from repository root
python3 -m pip install --user -r bluefield2Scripts/digital-twin/requirements.txt
```

3) Prepare the BF2 environment

```bash
./bluefield2Scripts/digital-twin/restart_environment.sh
```

4) Generate or validate topology files

- A topology JSON is included at `bluefield2Scripts/digital-twin/topology.json`. To generate a text representation used by some scripts:

```bash
python3 bluefield2Scripts/digital-twin/generate_topology_txt.py \
  --input bluefield2Scripts/digital-twin/topology.json \
  --output topology.txt
```

5) Run the digital twin

```bash
python3 bluefield2Scripts/digital-twin/run_topo.py
```

This script will bring up the twin according to the topology. Check its command-line help (pass `-h` or `--help`) for flags to control the run mode, logging, and dry-run options.

### Run Tofino / P4 components

1) Clone or copy the repository to your Barefoot Tofino

2) Run the monitoring tofino script (You will need to use the SDE 9.9+ for this step to work)

```bash
cd tofinoScripts
./run.sh
```

### Host-side monitoring

1) Clone or copy the repository to your server
    - This can either be the BF-2 host or a separate server

2) Tun the monitoring script
    - The receiver interface is the interface where the monitoring packets will be catched.
    - The sender interface is the interface where the packets will be sent
    - The instruction file contains the flow and port identifiers that will be monitored, you can change it to reflect the desired monitoring parameters.

```bash
bash run_monitoring.sh -rxIntf <receiver_interface> -txIntf <sender_interface> -file <intruction_file>
```

3) Inspect logs and status

- The run_monitoring.sh script will show the current status of the monitoring Tofino port/flow. All the logs are stored afterwards in the log.log file.

## Repository layout (quick map)

- `bluefield2Scripts/digital-twin/` — main BF2-targeted twin scripts and topology files
- `bluefield2Scripts/digital-twin/hairpin/` — hairpin example C code and build files
- `bluefield2Scripts/digital-twin/rss/` — RSS example C code and build files
- `hostScrits/` — host-side helpers for traffic, monitoring and info
- `tofinoScripts/` — Tofino scripts and a `p4codes/` folder with P4 programs

## Troubleshooting

- If a script fails with missing Python packages, verify you installed `requirements.txt`.
- If you see permission errors, try running commands with appropriate privileges or enable the required kernel modules on the BF2 host.
- For P4/Tofino build failures, verify that your Tofino SDK and toolchain are installed and on PATH.

## Contributing

Contributions, bug reports and improvements are welcome. Please open issues or pull requests with clear descriptions and reproduction steps.
