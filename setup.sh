#!/usr/bin/env bash
# VM Setup Script - Installs mise, languages, tools, coding agents
# Usage: curl -fsSL <url>/setup.sh | sudo bash
# Update: sudo bash setup.sh --update

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"
UPDATE_MODE="${UPDATE_MODE:-false}"

# Parse args
for arg in "$@"; do
    case $arg in
        --update) UPDATE_MODE=true ;;
    esac
done

log_step() { echo -e "${BLUE}[*]${NC} $1"; }
log_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err() { echo -e "${RED}[✗]${NC} $1"; }
log_detail() { echo -e "    → $1"; }

run_as_user() {
    sudo -u "$TARGET_USER" -H bash -c "$*"
}

setup_system() {
    log_step "Setting up system..."

    if ! id "$TARGET_USER" &>/dev/null; then
        log_detail "Creating user $TARGET_USER"
        useradd -m -s /bin/bash "$TARGET_USER"
    fi

    if [[ ! -f "/etc/sudoers.d/$TARGET_USER" ]]; then
        log_detail "Enabling passwordless sudo"
        echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$TARGET_USER"
        chmod 440 "/etc/sudoers.d/$TARGET_USER"
    fi

    getent group docker &>/dev/null && usermod -aG docker "$TARGET_USER" 2>/dev/null || true

    mkdir -p /data/projects "$TARGET_HOME/.local/bin"
    chown "$TARGET_USER:$TARGET_USER" /data/projects
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local"

    log_ok "System setup complete"
}

setup_system_limits() {
    log_step "Configuring system limits..."

    # Kernel parameters for Redis, databases, and high-performance apps
    local sysctl_conf="/etc/sysctl.d/99-custom.conf"
    if [[ ! -f "$sysctl_conf" ]]; then
        log_detail "Setting kernel parameters"
        cat > "$sysctl_conf" << 'EOF'
# Memory overcommit (required for Redis background saving)
vm.overcommit_memory = 1

# Increase socket backlog for high connections
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# Increase file descriptors
fs.file-max = 2097152

# Network tuning
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
EOF
        sysctl -p "$sysctl_conf" 2>/dev/null || true
    fi

    # Increase ulimits for ubuntu user
    local limits_conf="/etc/security/limits.d/99-custom.conf"
    if [[ ! -f "$limits_conf" ]]; then
        log_detail "Setting user limits"
        cat > "$limits_conf" << EOF
$TARGET_USER soft nofile 65535
$TARGET_USER hard nofile 65535
$TARGET_USER soft nproc 65535
$TARGET_USER hard nproc 65535
EOF
    fi

    # Disable transparent huge pages (recommended for Redis/MongoDB)
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        # Make persistent via rc.local or systemd
        grep -q "transparent_hugepage" /etc/rc.local 2>/dev/null || {
            echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local 2>/dev/null || true
        }
    fi

    log_ok "System limits configured"
}

install_base_packages() {
    log_step "Installing base packages..."

    apt-get update -qq
    apt-get install -y curl git ca-certificates unzip tar xz-utils build-essential sudo gnupg \
        tmux direnv git-lfs lsof dnsutils strace rsync htop tree ncdu entr mtr pv zsh \
        mysql-client sqlite3 postgresql-client 2>/dev/null

    if ! command -v docker &>/dev/null; then
        log_detail "Installing Docker"
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        local codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
        curl -sfI "https://download.docker.com/linux/ubuntu/dists/$codename/Release" &>/dev/null || codename="noble"

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || log_warn "Docker installation failed"
    else
        log_detail "Docker already installed"
        docker compose version &>/dev/null || apt-get install -y docker-compose-plugin 2>/dev/null || true
    fi

    # Configure Docker log limits (100MB max per container)
    local docker_config="/etc/docker/daemon.json"
    if [[ ! -f "$docker_config" ]] || ! grep -q "max-size" "$docker_config" 2>/dev/null; then
        log_detail "Setting Docker log limit to 100MB"
        mkdir -p /etc/docker
        cat > "$docker_config" << 'DOCKEREOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
DOCKEREOF
        systemctl restart docker 2>/dev/null || true
    fi

    log_ok "Base packages installed"
}

setup_shell() {
    log_step "Setting up shell..."

    local omz_dir="$TARGET_HOME/.oh-my-zsh"

    [[ ! -d "$omz_dir" ]] && {
        log_detail "Installing Oh My Zsh"
        run_as_user 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    }

    [[ ! -d "$omz_dir/custom/themes/powerlevel10k" ]] && {
        log_detail "Installing Powerlevel10k"
        run_as_user "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $omz_dir/custom/themes/powerlevel10k"
    }

    local plugins_dir="$omz_dir/custom/plugins"
    [[ ! -d "$plugins_dir/zsh-autosuggestions" ]] && {
        log_detail "Installing zsh-autosuggestions"
        run_as_user "git clone https://github.com/zsh-users/zsh-autosuggestions $plugins_dir/zsh-autosuggestions"
    }
    [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]] && {
        log_detail "Installing zsh-syntax-highlighting"
        run_as_user "git clone https://github.com/zsh-users/zsh-syntax-highlighting $plugins_dir/zsh-syntax-highlighting"
    }

    local zshrc="$TARGET_HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"
        grep -q "zsh-autosuggestions" "$zshrc" || sed -i 's/^plugins=(/plugins=(zsh-autosuggestions zsh-syntax-highlighting /' "$zshrc"
        # Minimal p10k config: remove user, hostname, time
        grep -q "POWERLEVEL9K_LEFT_PROMPT_ELEMENTS" "$zshrc" || run_as_user "cat >> $zshrc" << 'EOF'

# p10k minimal config
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time)
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

# PATH for local binaries
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# mise (activates shims for node, bun, zoxide, fzf, etc.)
eval "$($HOME/.local/bin/mise activate zsh)"

# zoxide (smart cd)
eval "$(zoxide init zsh)"

# fzf keybindings and completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(fzf --zsh 2>/dev/null)" || true

# direnv hook
eval "$(direnv hook zsh)"
EOF
    fi

    chsh -s /bin/zsh "$TARGET_USER" 2>/dev/null || true
    log_ok "Shell setup complete"
}

setup_git() {
    log_step "Configuring git..."

    # Prefer HTTPS over SSH for GitHub
    run_as_user "git config --global url.'https://github.com/'.insteadOf 'git@github.com:'"
    run_as_user "git config --global url.'https://github.com/'.insteadOf 'ssh://git@github.com/'"
    log_detail "Set HTTPS as default for GitHub"

    # Basic git config
    run_as_user "git config --global init.defaultBranch main"
    run_as_user "git config --global pull.rebase false"

    log_ok "Git configured"
}

install_mise() {
    log_step "Installing mise..."

    local mise_bin="$TARGET_HOME/.local/bin/mise"

    [[ ! -x "$mise_bin" ]] && {
        log_detail "Downloading mise"
        run_as_user 'curl -fsSL https://mise.run | sh'
    }

    local bashrc="$TARGET_HOME/.bashrc"
    grep -q 'mise activate bash' "$bashrc" 2>/dev/null || {
        log_detail "Registering mise in bash"
        run_as_user "cat >> $bashrc" << 'EOF'

# PATH for local binaries
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# mise (activates shims for node, bun, zoxide, fzf, etc.)
eval "$($HOME/.local/bin/mise activate bash)"

# zoxide (smart cd)
eval "$(zoxide init bash)"

# fzf keybindings
eval "$(fzf --bash 2>/dev/null)" || true

# direnv hook
eval "$(direnv hook bash)"
EOF
    }

    # mise in zsh is now added in setup_shell() with proper ordering
    # keeping this check for backwards compatibility on existing installs
    local zshrc="$TARGET_HOME/.zshrc"

    run_as_user "$mise_bin settings set experimental true" 2>/dev/null || true
    run_as_user "$mise_bin trust --all" 2>/dev/null || true

    log_ok "Mise installed"
}

install_via_mise() {
    log_step "Installing languages and tools via mise..."

    local mise_bin="$TARGET_HOME/.local/bin/mise"

    # Update mise itself if in update mode
    if [[ "$UPDATE_MODE" == "true" ]]; then
        log_detail "Updating mise"
        run_as_user "$mise_bin self-update" 2>/dev/null || true
    fi

    local languages=("node@lts" "bun@latest" "go@latest" "rust@stable" "python@3.12")
    for tool in "${languages[@]}"; do
        local name="${tool%%@*}"
        log_detail "Installing $name"
        run_as_user "$mise_bin use --global $tool" 2>/dev/null && log_ok "$name" || log_warn "$name failed"
    done

    # Upgrade all tools if in update mode
    if [[ "$UPDATE_MODE" == "true" ]]; then
        log_detail "Upgrading all mise tools"
        run_as_user "$mise_bin upgrade" 2>/dev/null || true
    fi

    local cli_tools=("ripgrep@latest" "fd@latest" "bat@latest" "eza@latest" "zoxide@latest" "fzf@latest"
        "jq@latest" "yq@latest" "delta@latest" "lazygit@latest" "dust@latest" "duf@latest"
        "btop@latest" "hyperfine@latest" "tokei@latest" "neovim@latest" "httpie-go@latest")
    for tool in "${cli_tools[@]}"; do
        local name="${tool%%@*}"
        log_detail "Installing $name"
        run_as_user "$mise_bin use --global $tool" 2>/dev/null && log_ok "$name" || log_detail "$name not available"
    done

    [[ ! -x "$TARGET_HOME/.local/bin/uv" ]] && {
        log_detail "Installing uv"
        run_as_user 'curl -LsSf https://astral.sh/uv/install.sh | sh' && log_ok "uv"
    }

    log_ok "Languages and tools installed"
}

install_agents() {
    log_step "Installing coding agents..."

    local bun_bin="$TARGET_HOME/.local/share/mise/installs/bun/latest/bin/bun"
    [[ ! -x "$bun_bin" ]] && bun_bin=$(run_as_user "which bun" 2>/dev/null || echo "")
    [[ ! -x "$bun_bin" ]] && bun_bin="$TARGET_HOME/.local/bin/bun"

    if [[ ! -x "$bun_bin" ]]; then
        log_warn "Bun not found, skipping agents"
        return 0
    fi

    # Claude Code
    if [[ ! -x "$TARGET_HOME/.local/bin/claude" ]] || [[ "$UPDATE_MODE" == "true" ]]; then
        log_detail "Installing/updating Claude Code"
        run_as_user "curl -fsSL https://claude.ai/install.sh | bash" 2>/dev/null || \
        run_as_user "$bun_bin install -g --trust @anthropic-ai/claude-code@latest" 2>/dev/null || \
        log_warn "Claude Code failed"
    fi
    [[ -x "$TARGET_HOME/.local/bin/claude" ]] && log_ok "Claude Code"

    # Codex
    if [[ ! -x "$TARGET_HOME/.local/bin/codex" ]] || [[ "$UPDATE_MODE" == "true" ]]; then
        log_detail "Installing/updating Codex CLI"
        run_as_user "$bun_bin install -g --trust @openai/codex@latest" 2>/dev/null || log_warn "Codex failed"
    fi
    [[ -x "$TARGET_HOME/.local/bin/codex" ]] && log_ok "Codex CLI"

    # Gemini
    if [[ ! -x "$TARGET_HOME/.local/bin/gemini" ]] || [[ "$UPDATE_MODE" == "true" ]]; then
        log_detail "Installing/updating Gemini CLI"
        run_as_user "$bun_bin install -g --trust @google/gemini-cli@latest" 2>/dev/null || log_warn "Gemini failed"
    fi
    [[ -x "$TARGET_HOME/.local/bin/gemini" ]] && log_ok "Gemini CLI"

    log_ok "Coding agents installed"
}

install_cc_switch() {
    log_step "Installing cc-switch-cli..."

    local cc_switch_bin="$TARGET_HOME/.local/bin/cc-switch"

    if [[ -x "$cc_switch_bin" ]] && [[ "$UPDATE_MODE" != "true" ]]; then
        log_ok "cc-switch already installed"
        return 0
    fi

    log_detail "Downloading cc-switch-cli"
    local tmp_dir=$(mktemp -d)
    local arch=$(uname -m)
    local variant="linux-x64-musl"
    [[ "$arch" == "aarch64" ]] && variant="linux-arm64-musl"

    # Get latest release
    local latest_url=$(curl -sL https://api.github.com/repos/SaladDay/cc-switch-cli/releases/latest | grep "browser_download_url.*${variant}.tar.gz" | cut -d '"' -f 4)

    if [[ -n "$latest_url" ]]; then
        curl -fsSL "$latest_url" -o "$tmp_dir/cc-switch.tar.gz"
        tar -xzf "$tmp_dir/cc-switch.tar.gz" -C "$tmp_dir"
        install -m 755 "$tmp_dir/cc-switch" "$TARGET_HOME/.local/bin/"
        chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/bin/cc-switch"
        rm -rf "$tmp_dir"
        log_ok "cc-switch installed"
    else
        log_warn "cc-switch download failed"
        rm -rf "$tmp_dir"
    fi
}

install_github_cli() {
    log_step "Installing GitHub CLI..."

    if command -v gh &>/dev/null; then
        log_ok "GitHub CLI already installed"
        return 0
    fi

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt-get update -qq
    apt-get install -y gh

    log_ok "GitHub CLI installed"
}

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    if [[ "$UPDATE_MODE" == "true" ]]; then
    echo "║  VM Setup - UPDATE MODE                                       ║"
    else
    echo "║  VM Setup - mise, languages, tools, coding agents             ║"
    fi
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    [[ $EUID -ne 0 ]] && { log_err "Run as root (use sudo)"; exit 1; }

    local start_time=$(date +%s)

    setup_system
    setup_system_limits
    install_base_packages
    setup_shell
    setup_git
    install_mise
    install_via_mise
    install_agents
    install_cc_switch
    install_github_cli

    local duration=$(($(date +%s) - start_time))

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  COMPLETE! (${duration}s)                                            ║"
    echo "║  Next: source ~/.zshrc && mise list                           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

main "$@"
