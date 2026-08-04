# ASCENTO Connection Manager

Connects your machine to the ASCENTO robot's Wi-Fi and opens an SSH session.

## Setup

Robot-specific settings (Wi-Fi SSID/password, robot IP, SSH user) live in `config.sh`, which is git-ignored so they never get committed. Before first use, create it from the template:

```
cp config.sh.example config.sh
```

Then edit `config.sh` with your robot's actual values.

## Usage

```
./connect_ascento.sh
```

What it does, every run:

1. Connects to the robot's Wi-Fi (`Ascento-0110_5G`).
2. Checks for internet access (informational only, the robot's network is local-only).
3. Pings the robot at `10.42.0.50` to confirm it's reachable.
4. Opens an SSH session to the robot.

## First run

The first time you run it, it also:

- Generates a dedicated SSH key at `~/.ssh/id_ascento` (only used for this robot, doesn't touch any other keys you have).
- Adds a `Host ascento` entry to `~/.ssh/config`, so you can also just run `ssh ascento` directly, or use `scp`, VS Code Remote-SSH, etc.
- Copies the key to the robot with `ssh-copy-id`. You'll be asked for the robot's SSH password once (`administrator` account). After that, connections are passwordless.

## Files

- `connect_ascento.sh` · does everything above. This replaces the old `set_ascento.sh` (SSH alias setup) and `access_ascento.sh` (Wi-Fi + connect) scripts, which have been removed.
- `config.sh.example` · template for robot settings, safe to commit.
- `config.sh` · your real robot settings, git-ignored, created by you from the template.

## Notes

- `config.sh` is git-ignored (see `.gitignore`) so the Wi-Fi password and robot details never end up in the repo, past or future commits included.
- The SSH password is never stored anywhere. It's only typed once, interactively, during the first-run key setup.
- If you ever need to re-authorize the key (e.g. after a robot reflash), delete the `Host ascento` block from `~/.ssh/config` and re-run the script.
