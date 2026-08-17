# ASCENTO Robot Scripts

Connects your machine to the ASCENTO robot's Wi-Fi/SSH, and bridges its ROS 2 topics to this machine over Zenoh.

## Setup

Robot-specific settings (Wi-Fi SSID/password, robot IP, SSH user, optionally the zenoh router address) live in `config.sh`, which is git-ignored so they never get committed. Before first use, create it from the template:

```
cp config.sh.example config.sh
```

Then edit `config.sh` with your robot's actual values.

## Connect

```
./connect_ascento.sh
```

What it does, every run:

1. Connects to the robot's Wi-Fi (`Ascento-0110_5G`).
2. Checks for internet access (informational only, the robot's network is local-only).
3. Pings the robot at `10.42.0.50` to confirm it's reachable.
4. Opens an SSH session to the robot.

First run also:

- Generates a dedicated SSH key at `~/.ssh/id_ascento` (only used for this robot, doesn't touch any other keys you have).
- Adds a `Host ascento` entry to `~/.ssh/config`, so you can also just run `ssh ascento` directly, or use `scp`, VS Code Remote-SSH, etc.
- Copies the key to the robot with `ssh-copy-id`. You'll be asked for the robot's SSH password once (`administrator` account). After that, connections are passwordless.

## Zenoh bridge

So this machine can see the robot's ROS 2 topics:

```
./run_zenoh.sh
```

1. Checks ROS 2 Humble is installed.
2. Checks whether `zenoh-bridge-ros2dds` is installed on this machine. If not, it finds the version running on the robot (over SSH), downloads the matching standalone build, and installs it.
3. Runs the bridge against the robot's zenoh router.

Run `./run_zenoh.sh --background` to run it in the background (logs to `/tmp/ascento_zenoh_bridge.log`) instead of blocking the terminal. It's not `nohup`'d/disowned, so it's tied to that terminal and ends when the terminal closes. Use `./run_zenoh.sh --status` / `--stop` to check on or stop it manually.

## Files

- `connect_ascento.sh` · connects Wi-Fi + SSH to the robot.
- `run_zenoh.sh` · installs (if needed) and runs the zenoh-ROS2 bridge.
- `utils.sh` · shared colors/logging helpers (`info`/`ok`/`warn`/`fail`) sourced by the other scripts.
- `config.sh.example` · template for robot settings, safe to commit.
- `config.sh` · your real robot settings, git-ignored, created by you from the template.

## Notes

- `config.sh` is git-ignored (see `.gitignore`) so the Wi-Fi password and robot details never end up in the repo, past or future commits included.
- The SSH password is never stored anywhere. It's only typed once, interactively, during the first-run key setup.
- If you ever need to re-authorize the key (e.g. after a robot reflash), delete the `Host ascento` block from `~/.ssh/config` and re-run the script.
