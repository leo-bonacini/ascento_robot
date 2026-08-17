#!/bin/bash
#
# install_ros2_humble.sh
# Installs ROS 2 Humble on Ubuntu 22.04 via APT. On other Ubuntu versions
# it explains why it won't install automatically and what to do instead.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

ROS_DISTRO="humble"

# ============================================================
# Header
# ============================================================

echo -e "${BLUE}=====================================${NC}"
echo -e "${CYAN}       ROS 2 Humble Installer${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

# ============================================================
# 0. Check we're not running as root
# ============================================================

if [ "$EUID" -eq 0 ]; then
    fail "Do not run this script as root."
    echo
    echo "Use:"
    echo "  ./install_ros2_humble.sh"
    exit 1
fi

# ============================================================
# 1. Check Ubuntu
# ============================================================

if [ ! -f /etc/os-release ]; then
    fail "Could not identify the operating system."
    exit 1
fi

source /etc/os-release

if [ "$ID" != "ubuntu" ]; then
    fail "This installer targets Ubuntu."
    echo "Detected system: $PRETTY_NAME"
    exit 1
fi

UBUNTU_VERSION="$VERSION_ID"
UBUNTU_CODENAME="$UBUNTU_CODENAME"

info "Detected system: ${CYAN}${PRETTY_NAME}${NC}"

# ============================================================
# 2. Ubuntu 22.04
# ============================================================

if [ "$UBUNTU_VERSION" == "22.04" ]; then

    echo
    ok "Ubuntu 22.04 detected."
    info "ROS 2 Humble will be installed via APT."
    echo

    read -r -p "Do you want to continue? [y/N]: " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        info "Installation cancelled."
        exit 0
    fi

    echo
    info "[1/9] Updating Ubuntu..."
    sudo apt update
    sudo apt upgrade -y

    echo
    info "[2/9] Installing dependencies..."
    sudo apt install -y \
        locales \
        software-properties-common \
        curl \
        gnupg \
        lsb-release \
        ca-certificates

    echo
    info "[3/9] Configuring locale..."

    sudo locale-gen en_US en_US.UTF-8
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    export LANG=en_US.UTF-8

    echo
    info "[4/9] Adding the ROS key..."

    sudo curl -sSL \
        https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg

    echo
    info "[5/9] Adding the ROS 2 repository..."

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" | \
        sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

    echo
    info "[6/9] Updating repositories..."

    sudo apt update

    echo
    info "[7/9] Installing ROS 2 Humble Desktop..."

    sudo apt install -y ros-humble-desktop

    echo
    info "[8/9] Installing tools..."

    sudo apt install -y \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        build-essential \
        git \
        python3-pip

    echo
    info "[9/9] Configuring ROS 2..."

    # Initialize rosdep
    sudo rosdep init 2>/dev/null || true
    rosdep update

    # Configure .bashrc
    if ! grep -q "/opt/ros/humble/setup.bash" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# ROS 2 Humble" >> "$HOME/.bashrc"
        echo "source /opt/ros/humble/setup.bash" >> "$HOME/.bashrc"
    fi

    # Load ROS in this session
    source /opt/ros/humble/setup.bash

    echo
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}   ROS 2 Humble installed successfully${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo

    info "ROS 2:"
    ros2 --help | head -n 3

    echo
    info "Recommended test:"
    echo
    echo "Terminal 1:"
    echo "  ros2 run demo_nodes_cpp talker"
    echo
    echo "Terminal 2:"
    echo "  ros2 run demo_nodes_py listener"
    echo

    info "Open a new terminal to load ROS 2 automatically."

    exit 0
fi

# ============================================================
# 3. Ubuntu 20.04
# ============================================================

if [ "$UBUNTU_VERSION" == "20.04" ]; then

    echo
    warn "Ubuntu 20.04 detected."
    echo
    echo "ROS 2 Humble has Tier 3 support for Ubuntu 20.04."
    echo
    echo "The recommended install is not through the standard"
    echo "APT package. For Ubuntu 20.04, Humble must be built"
    echo "from source."
    echo
    warn "This script will NOT change your APT repositories"
    warn "to avoid breaking the system."
    echo
    echo "If you specifically need Humble:"
    echo
    echo "  -> we can install it from SOURCE"
    echo
    echo "If you want a simple APT install:"
    echo
    echo "  -> Ubuntu 22.04 + ROS 2 Humble"
    echo

    exit 0
fi

# ============================================================
# 4. Ubuntu 24.04
# ============================================================

if [ "$UBUNTU_VERSION" == "24.04" ]; then

    echo
    warn "Ubuntu 24.04 detected."
    echo
    echo "ROS 2 Humble has no official support for Ubuntu 24.04."
    echo
    echo "For Ubuntu 24.04, the recommended option is:"
    echo
    echo "  ROS 2 Jazzy"
    echo
    warn "Humble will not be installed on this system."
    echo
    echo "If you ABSOLUTELY need Humble, it's recommended"
    echo "to use:"
    echo
    echo "  Ubuntu 22.04 + ROS 2 Humble"
    echo

    exit 0
fi

# ============================================================
# 5. Other versions
# ============================================================

echo
fail "Unsupported version."
echo
echo "Detected Ubuntu: $UBUNTU_VERSION"
echo
echo "This script has no automated ROS 2 Humble install"
echo "for this version."
echo
echo "For Humble, we recommend:"
echo
echo "  Ubuntu 22.04"
echo
echo "Installation via APT."
echo
