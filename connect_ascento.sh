#!/bin/bash
#
# connect_ascento.sh
# Connects to the ASCENTO robot's Wi-Fi and opens an SSH session.
#
# First run: generates a dedicated SSH key, registers a "ascento" host in
# ~/.ssh/config, and copies the key to the robot (you'll be asked for the
# robot's SSH password once).
# Later runs: just connects Wi-Fi + SSH, no password needed.

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
NC="\033[0m"

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\033[0;31m[ERROR]\033[0m Missing config.sh."
    echo "Copy config.sh.example to config.sh and fill in your robot's values:"
    echo "    cp config.sh.example config.sh"
    exit 1
fi

# shellcheck source=config.sh.example
source "$CONFIG_FILE"

SSH_ALIAS="ascento"
SSH_KEY="$HOME/.ssh/id_ascento"
SSH_CONFIG="$HOME/.ssh/config"

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1"; }

# 0. Check required commands are installed
declare -A REQUIRED_PKG=(
    [nmcli]="network-manager"
    [ping]="iputils-ping"
    [ssh]="openssh-client"
    [ssh-keygen]="openssh-client"
    [ssh-copy-id]="openssh-client"
)
missing_cmds=()
for cmd in "${!REQUIRED_PKG[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing_cmds+=("$cmd")
done
if [ ${#missing_cmds[@]} -gt 0 ]; then
    fail "Missing required command(s): ${missing_cmds[*]}"
    missing_pkgs=()
    for cmd in "${missing_cmds[@]}"; do
        missing_pkgs+=("${REQUIRED_PKG[$cmd]}")
    done
    echo "Install with:"
    echo "    sudo apt install -y $(printf "%s\n" "${missing_pkgs[@]}" | sort -u | tr '\n' ' ')"
    exit 1
fi

echo -e "${BLUE}=====================================${NC}"
echo -e "${CYAN}   ASCENTO Connection Manager${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

# 1. Connect Wi-Fi
info "Connecting to network ${CYAN}${SSID}${NC}..."
if nmcli dev wifi connect "$SSID" password "$WIFI_PASSWORD" >/dev/null 2>&1; then
    ok "Wi-Fi connected."
else
    fail "Could not connect to Wi-Fi."
    exit 1
fi

sleep 3

# 2. Check internet (informational only, robot network is often offline-only)
echo
info "Checking internet..."
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    ok "Internet available."
else
    warn "No internet."
    warn "The ASCENTO network only works locally."
fi

# 3. Check robot reachability
echo
info "Checking ASCENTO (${CYAN}${ROBOT_IP}${NC})..."
if ping -c 1 -W 2 "$ROBOT_IP" >/dev/null 2>&1; then
    ok "ASCENTO found."
else
    fail "ASCENTO not found."
    warn "Check the Wi-Fi connection."
    exit 1
fi

# 4. Ensure a dedicated SSH key exists
echo
if [ ! -f "$SSH_KEY" ]; then
    info "Generating dedicated SSH key (${SSH_KEY})..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q -C "ascento-robot"
    ok "SSH key generated."
fi

# 5. Ensure ~/.ssh/config has a Host entry for the robot
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -q "^Host ${SSH_ALIAS}$" "$SSH_CONFIG" 2>/dev/null; then
    info "Adding '${SSH_ALIAS}' entry to ~/.ssh/config..."
    cat <<EOF >> "$SSH_CONFIG"

Host ${SSH_ALIAS}
    HostName ${ROBOT_IP}
    User ${ROBOT_USER}
    IdentityFile ${SSH_KEY}
    IdentitiesOnly yes
    ForwardX11 yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    ok "Entry added."
fi

# 6. Make sure the key is authorized on the robot (copy it if not)
echo
info "Checking passwordless access..."
if ssh -o BatchMode=yes -o ConnectTimeout=3 "$SSH_ALIAS" true 2>/dev/null; then
    ok "Key already authorized."
else
    warn "Key not authorized yet."
    warn "Enter the ASCENTO password when prompted (only needed this once)."
    if ! ssh-copy-id -i "${SSH_KEY}.pub" "$SSH_ALIAS"; then
        fail "Could not copy the SSH key."
        exit 1
    fi
    ok "Key authorized successfully."
fi

# 7. Connect
echo
info "Connecting to ASCENTO..."
echo
exec ssh "$SSH_ALIAS"
