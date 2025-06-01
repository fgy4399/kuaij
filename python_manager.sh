#!/bin/bash
set -e

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

function show_menu() {
  echo -e "${YELLOW}
╔══════════════════════════════╗
║      Python 环境管理工具     ║
╠══════════════════════════════╣
║ 1. 查看已安装的 Python 版本  ║
║ 2. 卸载指定 Python 版本      ║
║ 3. 安装 Python（3.10~3.13） ║
║ 4. 安装 uv + uvx 工具        ║
║ 0. 退出                      ║
╚══════════════════════════════╝
${RESET}"
}

function ensure_dependencies() {
  if ! dpkg -l | grep -q build-essential; then
    echo -e "${GREEN}🔧 正在安装构建依赖...${RESET}"
    sudo apt update
    sudo apt install -y wget build-essential libssl-dev zlib1g-dev \
      libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev \
      libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev uuid-dev
  fi
}

function list_python_versions() {
  echo -e "${GREEN}🔍 扫描系统中已安装的 Python 版本:${RESET}"

  find_python() {
    for py in $(compgen -c python); do
      if [[ "$py" =~ ^python3\.[0-9]+$ ]]; then
        path=$(command -v "$py")
        version=$($py --version 2>/dev/null)
        echo -e "  $py -> $path   ($version)"
      fi
    done

    for ver in 3.10 3.11 3.12 3.13; do
      for path in "/usr/local/bin/python$ver" "/opt/python$ver/bin/python$ver"; do
        if [ -x "$path" ]; then
          echo -e "  python$ver -> $path   ($($path --version))"
        fi
      done
    done
  }

  find_python | sort -u || echo -e "${RED}未发现任何 Python3.x 版本。${RESET}"
}

function uninstall_python() {
  echo -e "${YELLOW}请输入要卸载的 Python 版本号（如 3.12）:${RESET}"
  read -r ver
  if [[ ! "$ver" =~ ^3\.(10|11|12|13)$ ]]; then
    echo -e "${RED}❌ 不支持的版本号，只能卸载 3.10 ～ 3.13${RESET}"
    return
  fi

  installed=false
  if [[ -x "/opt/python$ver/bin/python$ver" || -x "/usr/local/bin/python$ver" ]]; then
    installed=true
  fi

  if [[ "$installed" == false ]]; then
    echo -e "${YELLOW}⚠️ 未发现 Python $ver 安装记录，无需卸载${RESET}"
    return
  fi

  echo -e "${GREEN}🧹 正在卸载 Python $ver...${RESET}"
  sudo rm -rf /opt/python$ver
  sudo rm -f /usr/local/bin/python$ver /usr/local/bin/pip$ver
  sudo apt remove -y python$ver python$ver-dev python$ver-venv python$ver-distutils || true

  if [[ -f .python-version && "$(cat .python-version)" == "$ver" ]]; then
    echo -e "${YELLOW}⚠️ .python-version 指向的版本已被卸载，删除该文件${RESET}"
    rm -f .python-version
  fi

  if [[ -d .venv ]]; then
    echo -e "${YELLOW}🗑️ 删除虚拟环境目录 .venv${RESET}"
    rm -rf .venv
  fi

  if [[ -f requirements.lock ]]; then
    echo -e "${YELLOW}🗑️ 删除依赖锁文件 requirements.lock${RESET}"
    rm -f requirements.lock
  fi

  echo -e "${GREEN}✅ 卸载完成${RESET}"
}

function install_python() {
  echo -e "${YELLOW}请选择要安装的 Python 版本（3.10 / 3.11 / 3.12 / 3.13）:${RESET}"
  read -r pyver

  if [[ ! "$pyver" =~ ^3\.(10|11|12|13)$ ]]; then
    echo -e "${RED}❌ 版本非法，仅支持 3.10 ～ 3.13${RESET}"
    return
  fi

  ensure_dependencies

  echo -e "${GREEN}🚀 安装 Python $pyver 中...${RESET}"
  pushd /tmp > /dev/null
  wget -q https://www.python.org/ftp/python/${pyver}.0/Python-${pyver}.0.tgz
  tar -xzf Python-${pyver}.0.tgz
  cd Python-${pyver}.0
  ./configure --enable-optimizations --prefix=/opt/python$pyver
  make -j"$(nproc)"
  sudo make altinstall
  popd > /dev/null

  sudo ln -sf /opt/python$pyver/bin/python${pyver} /usr/local/bin/python$pyver
  sudo ln -sf /opt/python$pyver/bin/pip${pyver} /usr/local/bin/pip$pyver

  echo -e "${GREEN}📦 安装 pip...${RESET}"
  curl -sS https://bootstrap.pypa.io/get-pip.py | sudo /opt/python$pyver/bin/python${pyver}

  echo "$pyver" > .python-version
  echo -e "${GREEN}✅ 安装成功: python$pyver 可用，已写入 .python-version${RESET}"

  echo -e "${GREEN}📦 使用 uv 创建虚拟环境 .venv...${RESET}"
  if ! command -v uv >/dev/null; then
    echo -e "${YELLOW}未检测到 uv，请先选择选项 4 安装 uv${RESET}"
  else
    uv --python=/usr/local/bin/python$pyver venv
    echo -e "${GREEN}✅ 虚拟环境 .venv 创建完成，已绑定 Python $pyver${RESET}"
  fi
}

function install_uv() {
  echo -e "${GREEN}📦 安装 uv + uvx 中...${RESET}"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo -e "${GREEN}✅ uv 安装完成，命令：uv / uvx${RESET}"
}

function check_python_version_file() {
  if [[ -f .python-version ]]; then
    ver=$(cat .python-version)
    if ! command -v python$ver >/dev/null; then
      echo -e "${RED}❌ .python-version 指定的 python$ver 不存在，请修改或删除该文件${RESET}"
      exit 1
    fi
  fi
}

while true; do
  show_menu
  check_python_version_file
  echo -en "${YELLOW}请输入选项编号: ${RESET}"
  read -r choice
  case "$choice" in
    1) list_python_versions ;;
    2) uninstall_python ;;
    3) install_python ;;
    4) install_uv ;;
    0) echo -e "${GREEN}👋 退出脚本${RESET}"; exit 0 ;;
    *) echo -e "${RED}无效选项，请重试${RESET}" ;;
  esac
  echo ""
done
