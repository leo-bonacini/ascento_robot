#!/bin/bash

set -e

# ============================================================
# ROS 2 HUMBLE - INSTALADOR MULTI-VERSÃO UBUNTU
#
# Ubuntu 22.04 -> instalação oficial via APT
# Ubuntu 20.04 -> não instala automaticamente (source)
# Ubuntu 24.04 -> Humble não suportado oficialmente
# ============================================================

ROS_DISTRO="humble"

echo ""
echo "===================================================="
echo "          INSTALADOR ROS 2 HUMBLE"
echo "===================================================="
echo ""

# ------------------------------------------------------------
# Verificar se está rodando como root
# ------------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
    echo "ERRO: não execute este script como root."
    echo ""
    echo "Use:"
    echo "  ./install_ros2_humble.sh"
    exit 1
fi

# ------------------------------------------------------------
# Verificar Ubuntu
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    echo "ERRO: não foi possível identificar o sistema operacional."
    exit 1
fi

source /etc/os-release

if [ "$ID" != "ubuntu" ]; then
    echo "ERRO: este instalador é destinado ao Ubuntu."
    echo "Sistema detectado: $PRETTY_NAME"
    exit 1
fi

UBUNTU_VERSION="$VERSION_ID"
UBUNTU_CODENAME="$UBUNTU_CODENAME"

echo "Sistema detectado:"
echo "  $PRETTY_NAME"
echo ""

# ------------------------------------------------------------
# Ubuntu 22.04
# ------------------------------------------------------------

if [ "$UBUNTU_VERSION" == "22.04" ]; then

    echo "Ubuntu 22.04 detectado."
    echo "ROS 2 Humble será instalado via APT."
    echo ""

    read -p "Deseja continuar? [s/N]: " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
        echo "Instalação cancelada."
        exit 0
    fi

    echo ""
    echo "[1/9] Atualizando Ubuntu..."
    sudo apt update
    sudo apt upgrade -y

    echo ""
    echo "[2/9] Instalando dependências..."
    sudo apt install -y \
        locales \
        software-properties-common \
        curl \
        gnupg \
        lsb-release \
        ca-certificates

    echo ""
    echo "[3/9] Configurando locale..."

    sudo locale-gen en_US en_US.UTF-8
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    export LANG=en_US.UTF-8

    echo ""
    echo "[4/9] Adicionando chave do ROS..."

    sudo curl -sSL \
        https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg

    echo ""
    echo "[5/9] Adicionando repositório ROS 2..."

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" | \
        sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

    echo ""
    echo "[6/9] Atualizando repositórios..."

    sudo apt update

    echo ""
    echo "[7/9] Instalando ROS 2 Humble Desktop..."

    sudo apt install -y ros-humble-desktop

    echo ""
    echo "[8/9] Instalando ferramentas..."

    sudo apt install -y \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        build-essential \
        git \
        python3-pip

    echo ""
    echo "[9/9] Configurando ROS 2..."

    # Inicializar rosdep
    sudo rosdep init 2>/dev/null || true
    rosdep update

    # Configurar .bashrc
    if ! grep -q "/opt/ros/humble/setup.bash" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# ROS 2 Humble" >> "$HOME/.bashrc"
        echo "source /opt/ros/humble/setup.bash" >> "$HOME/.bashrc"
    fi

    # Carregar ROS nesta sessão
    source /opt/ros/humble/setup.bash

    echo ""
    echo "===================================================="
    echo "       ROS 2 HUMBLE INSTALADO COM SUCESSO"
    echo "===================================================="
    echo ""

    echo "ROS 2:"
    ros2 --help | head -n 3

    echo ""
    echo "Teste recomendado:"
    echo ""
    echo "Terminal 1:"
    echo "  ros2 run demo_nodes_cpp talker"
    echo ""
    echo "Terminal 2:"
    echo "  ros2 run demo_nodes_py listener"
    echo ""

    echo "Abra um novo terminal para carregar automaticamente o ROS 2."
    echo ""

    exit 0
fi

# ------------------------------------------------------------
# Ubuntu 20.04
# ------------------------------------------------------------

if [ "$UBUNTU_VERSION" == "20.04" ]; then

    echo "===================================================="
    echo "              UBUNTU 20.04 DETECTADO"
    echo "===================================================="
    echo ""
    echo "O ROS 2 Humble possui suporte Tier 3 para Ubuntu 20.04."
    echo ""
    echo "A instalação recomendada não é pelo pacote APT padrão."
    echo "Para Ubuntu 20.04, o Humble deve ser compilado a partir"
    echo "do código-fonte."
    echo ""
    echo "Este script NÃO vai alterar seus repositórios APT"
    echo "para evitar quebrar o sistema."
    echo ""
    echo "Se você precisa especificamente do Humble:"
    echo ""
    echo "  -> podemos instalar pelo SOURCE"
    echo ""
    echo "Se você quer instalação simples via APT:"
    echo ""
    echo "  -> Ubuntu 22.04 + ROS 2 Humble"
    echo ""

    exit 0
fi

# ------------------------------------------------------------
# Ubuntu 24.04
# ------------------------------------------------------------

if [ "$UBUNTU_VERSION" == "24.04" ]; then

    echo "===================================================="
    echo "              UBUNTU 24.04 DETECTADO"
    echo "===================================================="
    echo ""
    echo "ROS 2 Humble não possui suporte oficial para Ubuntu 24.04."
    echo ""
    echo "Para Ubuntu 24.04, a opção recomendada é:"
    echo ""
    echo "  ROS 2 Jazzy"
    echo ""
    echo "Não será instalado Humble neste sistema."
    echo ""
    echo "Se você precisa OBRIGATORIAMENTE do Humble,"
    echo "recomenda-se usar:"
    echo ""
    echo "  Ubuntu 22.04 + ROS 2 Humble"
    echo ""

    exit 0
fi

# ------------------------------------------------------------
# Outras versões
# ------------------------------------------------------------

echo "===================================================="
echo "             VERSÃO NÃO SUPORTADA"
echo "===================================================="
echo ""
echo "Ubuntu detectado: $UBUNTU_VERSION"
echo ""
echo "Este script não possui instalação automática do"
echo "ROS 2 Humble para esta versão."
echo ""
echo "Para Humble, recomendamos:"
echo ""
echo "  Ubuntu 22.04"
echo ""
echo "Instalação via APT."
echo ""
