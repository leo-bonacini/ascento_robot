#!/bin/bash
#
# connect_ascento.sh
# Connects to the ASCENTO robot's Wi-Fi and opens an SSH session.
#
# First run: generates a dedicated SSH key, registers a "ascento" host in
# ~/.ssh/config, and copies the key to the robot.
# Later runs: connects Wi-Fi only if necessary + SSH, no password needed.
#

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE="$SCRIPT_DIR/config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    fail "Missing config.sh."
    echo
    echo "Copy config.sh.example to config.sh and fill in your robot's values:"
    echo
    echo "    cp config.sh.example config.sh"
    echo
    exit 1
fi

# shellcheck source=config.sh
source "$CONFIG_FILE"

SSH_ALIAS="ascento"
SSH_KEY="$HOME/.ssh/id_ascento"
SSH_CONFIG="$HOME/.ssh/config"

# ============================================================
# Header
# ============================================================

echo -e "${BLUE}=====================================${NC}"
echo -e "${CYAN}       ASCENTO Connection Manager${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

# ============================================================
# 0. Check required commands
# ============================================================

declare -A REQUIRED_PKG=(
    [nmcli]="network-manager"
    [ping]="iputils-ping"
    [ssh]="openssh-client"
    [ssh-keygen]="openssh-client"
    [ssh-copy-id]="openssh-client"
)

missing_cmds=()

for cmd in "${!REQUIRED_PKG[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_cmds+=("$cmd")
    fi
done

if [ ${#missing_cmds[@]} -gt 0 ]; then

    fail "Missing required command(s): ${missing_cmds[*]}"

    missing_pkgs=()

    for cmd in "${missing_cmds[@]}"; do
        missing_pkgs+=("${REQUIRED_PKG[$cmd]}")
    done

    echo
    echo "Install with:"
    echo
    echo "    sudo apt install -y $(printf "%s\n" "${missing_pkgs[@]}" | sort -u | tr '\n' ' ')"
    echo

    exit 1
fi

# ============================================================
# 1. Check Wi-Fi connection
# ============================================================

echo
info "Checking Wi-Fi connection..."

CURRENT_SSID=$(
    nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null \
    | awk -F: '$1 == "yes" {print $2; exit}'
)

if [ "$CURRENT_SSID" = "$SSID" ]; then

    ok "Already connected to Wi-Fi: ${CYAN}${SSID}${NC}"

else

    if [ -n "$CURRENT_SSID" ]; then
        warn "Currently connected to: ${CURRENT_SSID}"
    else
        info "No Wi-Fi network currently connected."
    fi

    info "Connecting to network ${CYAN}${SSID}${NC}..."

    if nmcli dev wifi connect "$SSID" password "$WIFI_PASSWORD" >/dev/null 2>&1; then
        ok "Wi-Fi connected."
    else
        fail "Could not connect to Wi-Fi."
        exit 1
    fi

    sleep 3

fi

# ============================================================
# 2. Show current Wi-Fi information
# ============================================================

echo
info "Wi-Fi status:"

nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null \
    | grep ':wifi:' \
    | while IFS=: read -r DEVICE TYPE STATE CONNECTION; do
        echo "    Interface : $DEVICE"
        echo "    State     : $STATE"
        echo "    Network   : $CONNECTION"
    done

# ============================================================
# 3. Check internet
# ============================================================

echo
info "Checking internet..."

if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    ok "Internet available."
else
    warn "No internet."
    warn "The ASCENTO network may only provide local connectivity."
fi

# ============================================================
# 4. Check robot reachability
# ============================================================

echo
info "Checking ASCENTO (${CYAN}${ROBOT_IP}${NC})..."

if ping -c 1 -W 2 "$ROBOT_IP" >/dev/null 2>&1; then
    ok "ASCENTO found at ${ROBOT_IP}."
else
    fail "ASCENTO not found at ${ROBOT_IP}."
    echo
    warn "Check the Wi-Fi connection."
    warn "Current SSID: ${CURRENT_SSID:-unknown}"
    echo
    exit 1
fi

# ============================================================
# 5. Ensure SSH directory exists
# ============================================================

echo

if [ ! -d "$HOME/.ssh" ]; then
    info "Creating ~/.ssh directory..."
    mkdir -p "$HOME/.ssh"
fi

chmod 700 "$HOME/.ssh"

# ============================================================
# 6. Ensure dedicated SSH key exists
# ============================================================

if [ ! -f "$SSH_KEY" ]; then

    info "Generating dedicated SSH key:"
    echo "    $SSH_KEY"

    ssh-keygen \
        -t ed25519 \
        -f "$SSH_KEY" \
        -N "" \
        -q \
        -C "ascento-robot"

    if [ $? -eq 0 ]; then
        ok "SSH key generated."
    else
        fail "Could not generate SSH key."
        exit 1
    fi

else

    ok "SSH key already exists."

fi

# ============================================================
# 7. Configure ~/.ssh/config
# ============================================================

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if ! grep -qE "^Host[[:space:]]+${SSH_ALIAS}$" "$SSH_CONFIG" 2>/dev/null; then

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

    ok "SSH configuration added."

else

    ok "SSH configuration for '${SSH_ALIAS}' already exists."

fi

# ============================================================
# 8. Check passwordless SSH access
# ============================================================

echo
info "Checking passwordless SSH access..."

if ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=3 \
    "$SSH_ALIAS" true >/dev/null 2>&1; then

    ok "SSH key already authorized."

else

    warn "SSH key is not authorized on ASCENTO."
    echo
    warn "You will be asked for the ASCENTO SSH password."
    warn "This should only be necessary once."
    echo

    if ssh-copy-id \
        -i "${SSH_KEY}.pub" \
        "$SSH_ALIAS"; then

        ok "SSH key authorized successfully."

    else

        fail "Could not copy the SSH key."
        exit 1

    fi

fi

# ============================================================
# 9. Final SSH connection
# ============================================================

echo
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}       Connecting to ASCENTO${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

info "Robot IP   : ${ROBOT_IP}"
info "Robot user : ${ROBOT_USER}"
info "SSH alias  : ${SSH_ALIAS}"
echo

exec ssh "$SSH_ALIAS"
