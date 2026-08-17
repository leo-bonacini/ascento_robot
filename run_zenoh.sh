#!/bin/bash
#
# run_zenoh.sh
# Checks that zenoh-bridge-ros2dds is installed on this machine, installing
# it (matching the robot's version) if it's not, then runs the bridge so
# this machine can see the ASCENTO robot's ROS 2 topics.
#
# Follows the process documented in zenoh_bridge_local_host.md.
#
# Usage:
#   ./run_zenoh.sh               Run the bridge in the foreground.
#   ./run_zenoh.sh --background  Run it in the background (logs to a file).
#                                 Not nohup'd/disowned, so it dies with the
#                                 terminal it was started from.
#   ./run_zenoh.sh --status      Check whether a background bridge is running.
#   ./run_zenoh.sh --stop        Stop a background bridge.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

# Extracts a X.Y.Z version number from arbitrary --version output.
extract_version() {
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<< "$1" | head -n 1
}

# ============================================================
# Argument parsing
# ============================================================

PID_FILE="/tmp/ascento_zenoh_bridge.pid"
LOG_FILE="/tmp/ascento_zenoh_bridge.log"

BACKGROUND=false
ACTION="run"

for arg in "$@"; do
    case "$arg" in
        --background|-b)
            BACKGROUND=true
            ;;
        --stop)
            ACTION="stop"
            ;;
        --status)
            ACTION="status"
            ;;
        --help|-h)
            ACTION="help"
            ;;
        *)
            fail "Unknown option: $arg"
            echo "Run with --help for usage."
            exit 1
            ;;
    esac
done

if [ "$ACTION" = "help" ]; then
    echo "Usage:"
    echo "  ./run_zenoh.sh               Run the bridge in the foreground."
    echo "  ./run_zenoh.sh --background  Run it in the background (logs to a file)."
    echo "                                Not nohup'd/disowned, so it dies with the"
    echo "                                terminal it was started from."
    echo "  ./run_zenoh.sh --status      Check whether a background bridge is running."
    echo "  ./run_zenoh.sh --stop        Stop a background bridge."
    exit 0
fi

if [ "$ACTION" = "status" ]; then
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        ok "Bridge running in background (PID $(cat "$PID_FILE"))."
        info "Logs: $LOG_FILE"
    else
        info "No background bridge running."
    fi
    exit 0
fi

if [ "$ACTION" = "stop" ]; then
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        PID="$(cat "$PID_FILE")"
        kill "$PID"
        rm -f "$PID_FILE"
        ok "Stopped background bridge (PID ${PID})."
    else
        info "No background bridge running."
        rm -f "$PID_FILE"
    fi
    exit 0
fi

# ============================================================
# Configuration
# ============================================================

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
BRIDGE_BIN="zenoh-bridge-ros2dds"
BRIDGE_INSTALL_PATH="/usr/local/bin/$BRIDGE_BIN"
ROS_SETUP="/opt/ros/humble/setup.bash"

# Can be overridden by setting these in config.sh.
ZENOH_ROUTER_IP="${ZENOH_ROUTER_IP:-10.42.0.100}"
ZENOH_ROUTER_PORT="${ZENOH_ROUTER_PORT:-7447}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# ============================================================
# Header
# ============================================================

echo -e "${BLUE}=====================================${NC}"
echo -e "${CYAN}       ASCENTO Zenoh Bridge${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

# ============================================================
# 0. Check required commands
# ============================================================

declare -A REQUIRED_PKG=(
    [ssh]="openssh-client"
    [wget]="wget"
    [unzip]="unzip"
    [sudo]="sudo"
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
# 1. Check ROS 2 Humble is installed
# ============================================================

echo
info "Checking for ROS 2 Humble..."

if [ -f "$ROS_SETUP" ]; then
    ok "Found $ROS_SETUP."
else
    fail "ROS 2 Humble not found at $ROS_SETUP."
    echo
    echo "Install it first with:"
    echo
    echo "    ./install_ros2_humble.sh"
    echo
    exit 1
fi

# ============================================================
# 2. Check if zenoh-bridge-ros2dds is installed
# ============================================================

echo
info "Checking for ${CYAN}${BRIDGE_BIN}${NC} on this machine..."

if command -v "$BRIDGE_BIN" >/dev/null 2>&1; then

    LOCAL_VERSION="$(extract_version "$("$BRIDGE_BIN" --version 2>&1)")"
    ok "Already installed (version ${LOCAL_VERSION:-unknown})."

else

    warn "${BRIDGE_BIN} is not installed."
    echo
    info "Following the install process from zenoh_bridge_local_host.md..."

    # --------------------------------------------------------
    # 2a. Find the version running on the robot
    # --------------------------------------------------------

    echo
    info "Checking ${BRIDGE_BIN} version on the robot..."

    ROBOT_VERSION_OUTPUT="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_ALIAS" "$BRIDGE_BIN --version" 2>/dev/null)"

    if [ -z "$ROBOT_VERSION_OUTPUT" ]; then
        fail "Could not reach the robot to check its ${BRIDGE_BIN} version."
        echo
        warn "Run ./connect_ascento.sh first to set up Wi-Fi and SSH access."
        exit 1
    fi

    VER="$(extract_version "$ROBOT_VERSION_OUTPUT")"

    if [ -z "$VER" ]; then
        fail "Could not parse a version number from the robot's output:"
        echo "    $ROBOT_VERSION_OUTPUT"
        exit 1
    fi

    ok "Robot is running version ${CYAN}${VER}${NC}."

    # --------------------------------------------------------
    # 2b. Check architecture (only linux-gnu standalone builds
    #     are published)
    # --------------------------------------------------------

    ARCH="$(uname -m)"

    if [ "$ARCH" != "x86_64" ]; then
        fail "No standalone build known for architecture '${ARCH}'."
        echo
        echo "Check available builds at:"
        echo "    https://download.eclipse.org/zenoh/zenoh-plugin-ros2dds/"
        echo "    https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases"
        exit 1
    fi

    # --------------------------------------------------------
    # 2c. Download and install the matching standalone build
    # --------------------------------------------------------

    ASSET="zenoh-plugin-ros2dds-${VER}-x86_64-unknown-linux-gnu-standalone.zip"
    URL="https://download.eclipse.org/zenoh/zenoh-plugin-ros2dds/${VER}/x86_64-unknown-linux-gnu/${ASSET}"

    echo
    info "Downloading ${CYAN}${ASSET}${NC}..."

    if ! wget -q -O "$WORK_DIR/$ASSET" "$URL"; then
        fail "Could not download ${URL}"
        echo
        echo "Check the release exists at:"
        echo "    https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases"
        exit 1
    fi

    ok "Downloaded."

    info "Extracting..."
    unzip -q -o "$WORK_DIR/$ASSET" -d "$WORK_DIR"

    if [ ! -f "$WORK_DIR/$BRIDGE_BIN" ]; then
        fail "Extracted archive does not contain ${BRIDGE_BIN}."
        exit 1
    fi

    info "Installing to ${BRIDGE_INSTALL_PATH} (sudo required)..."

    if sudo install -m 0755 "$WORK_DIR/$BRIDGE_BIN" "$BRIDGE_INSTALL_PATH"; then
        ok "${BRIDGE_BIN} installed."
    else
        fail "Could not install ${BRIDGE_BIN}."
        exit 1
    fi

    LOCAL_VERSION="$(extract_version "$("$BRIDGE_BIN" --version 2>&1)")"

    if [ "$LOCAL_VERSION" != "$VER" ]; then
        warn "Installed version (${LOCAL_VERSION:-unknown}) does not match the robot's (${VER})."
    else
        ok "Installed version matches the robot (${VER})."
    fi

fi

# ============================================================
# 3. Check connectivity to the zenoh router
# ============================================================

echo
info "Checking connectivity to zenoh router (${CYAN}${ZENOH_ROUTER_IP}:${ZENOH_ROUTER_PORT}${NC})..."

if ping -c 1 -W 2 "$ZENOH_ROUTER_IP" >/dev/null 2>&1; then
    ok "Router reachable."
else
    warn "Router not reachable directly at ${ZENOH_ROUTER_IP}."
    warn "Make sure you're on the robot's Wi-Fi (./connect_ascento.sh)."
    warn "If you're on a different network, set up the SSH tunnel described"
    warn "in the \"If you are not on 10.42.0.x\" section of"
    warn "zenoh_bridge_local_host.md, then re-run this script."
fi

# ============================================================
# 4. Run the bridge
# ============================================================

echo
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}       Starting Zenoh Bridge${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

info "Zenoh router : tcp/${ZENOH_ROUTER_IP}:${ZENOH_ROUTER_PORT}"
info "ROS domain   : 0"
info "RMW          : rmw_cyclonedds_cpp"
echo

# shellcheck source=/opt/ros/humble/setup.bash
source "$ROS_SETUP"
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_DOMAIN_ID=0

if [ "$BACKGROUND" = true ]; then

    "$BRIDGE_BIN" -e "tcp/${ZENOH_ROUTER_IP}:${ZENOH_ROUTER_PORT}" > "$LOG_FILE" 2>&1 &
    BRIDGE_PID=$!
    echo "$BRIDGE_PID" > "$PID_FILE"

    ok "Bridge running in background (PID ${BRIDGE_PID})."
    info "Logs   : $LOG_FILE"
    info "Stop   : ./run_zenoh.sh --stop"
    info "Status : ./run_zenoh.sh --status"
    echo
    warn "This job is not nohup'd/disowned, so it's tied to this terminal:"
    warn "closing the terminal window should end it. If your shell has"
    warn "'huponexit' off, run 'shopt -s huponexit' before this command"
    warn "for that to be guaranteed."

else

    exec "$BRIDGE_BIN" -e "tcp/${ZENOH_ROUTER_IP}:${ZENOH_ROUTER_PORT}"

fi
