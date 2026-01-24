# VM Setup Script

A standalone script to set up a complete development environment on Ubuntu VMs with mise, modern CLI tools, and AI coding agents.

## Quick Start

```bash
# One-liner (recommended)
curl -fsSL https://raw.githubusercontent.com/<your-repo>/setup.sh | sudo bash

# Or download and run
wget https://raw.githubusercontent.com/<your-repo>/setup.sh
sudo bash setup.sh
```

## Requirements

- **OS:** Ubuntu 22.04+ (tested on 25.10)
- **Arch:** x86_64 (AMD64) or ARM64
- **RAM:** 2GB minimum, 4GB recommended
- **Disk:** 10GB free space
- **Access:** Root or sudo privileges

## What Gets Installed

### Phase 1: System Setup

| Component | Description |
|-----------|-------------|
| User `ubuntu` | Created if not exists |
| Passwordless sudo | `ubuntu ALL=(ALL) NOPASSWD:ALL` |
| Docker group | User added to docker group |
| `/data/projects` | Workspace directory |
| `~/.local/bin` | User binary directory |

### Phase 2: Base Packages (apt)

| Package | Description |
|---------|-------------|
| `curl` | HTTP client |
| `git` | Version control |
| `ca-certificates` | SSL certificates |
| `unzip`, `tar`, `xz-utils` | Archive utilities |
| `build-essential` | GCC, make, etc. |
| `gnupg` | GPG encryption |
| `tmux` | Terminal multiplexer |
| `direnv` | Directory-based env vars |
| `git-lfs` | Git large file storage |
| `lsof` | List open files |
| `dnsutils` | DNS utilities (dig, nslookup) |
| `strace` | System call tracer |
| `rsync` | File synchronization |
| `htop` | Interactive process viewer |
| `tree` | Directory tree viewer |
| `ncdu` | Disk usage analyzer |
| `entr` | File watcher |
| `mtr` | Network diagnostic |
| `pv` | Pipe viewer |
| `zsh` | Z shell |
| `mysql-client` | MySQL/MariaDB CLI client |
| `sqlite3` | SQLite CLI client |
| `postgresql-client` | PostgreSQL CLI client (psql) |
| `docker-ce` | Docker Engine (official) |
| `docker-compose-plugin` | Docker Compose v2 |
| `docker-buildx-plugin` | Docker Buildx |

### Phase 3: Shell Environment

| Component | Description |
|-----------|-------------|
| **zsh** | Default shell |
| **Oh My Zsh** | Zsh framework |
| **Powerlevel10k** | Fast, customizable prompt theme |
| **zsh-autosuggestions** | Fish-like autosuggestions |
| **zsh-syntax-highlighting** | Syntax highlighting for commands |
| **zoxide** | Smart cd with frecency (use `z` command) |
| **fzf** | Fuzzy finder keybindings (Ctrl+R, Ctrl+T) |
| **direnv** | Auto-load .envrc files when entering directories |

### Phase 4: Mise (Runtime Manager)

[Mise](https://mise.jdx.dev/) is a polyglot runtime manager (like asdf, nvm, pyenv combined).

- Installed to `~/.local/bin/mise`
- Registered in both `~/.bashrc` and `~/.zshrc`
- Manages all languages and many CLI tools

### Phase 5: Languages (via mise)

| Language | Version | Description |
|----------|---------|-------------|
| **Node.js** | LTS (24.x) | JavaScript runtime |
| **Bun** | Latest | Fast JS runtime & bundler |
| **Go** | Latest (1.25.x) | Go programming language |
| **Rust** | Stable | Rust programming language |
| **Python** | 3.12 | Python interpreter |

### Phase 6: CLI Tools (via mise)

| Tool | Command | Description |
|------|---------|-------------|
| **ripgrep** | `rg` | Fast grep replacement |
| **fd** | `fd` | Fast find replacement |
| **bat** | `bat` | Cat with syntax highlighting |
| **eza** | `eza` | Modern ls replacement |
| **zoxide** | `z` | Smart cd with frecency |
| **fzf** | `fzf` | Fuzzy finder |
| **jq** | `jq` | JSON processor |
| **yq** | `yq` | YAML processor |
| **delta** | `delta` | Git diff viewer |
| **lazygit** | `lazygit` | Git TUI |
| **dust** | `dust` | Disk usage (du replacement) |
| **duf** | `duf` | Disk free (df replacement) |
| **btop** | `btop` | System monitor (htop++) |
| **hyperfine** | `hyperfine` | Benchmarking tool |
| **tokei** | `tokei` | Code statistics |
| **neovim** | `nvim` | Modern vim |
| **httpie-go** | `ht` | HTTP client |

Also installed separately:
| Tool | Description |
|------|-------------|
| **uv** | Fast Python package manager |

### Phase 7: Coding Agents

| Agent | Command | Description |
|-------|---------|-------------|
| **Claude Code** | `claude` | Anthropic's AI coding assistant |
| **Codex CLI** | `codex` | OpenAI's coding assistant |
| **Gemini CLI** | `gemini` | Google's AI assistant |
| **cc-switch** | `cc-switch` | Multi-agent config manager (Claude/Codex/Gemini) |

### Phase 8: GitHub CLI

| Tool | Command | Description |
|------|---------|-------------|
| **GitHub CLI** | `gh` | GitHub from command line |

## Usage Examples

### Basic Installation

```bash
# Run on fresh Ubuntu VM
sudo bash setup.sh
```

### Update Existing Installation

```bash
# Update all tools to latest versions
sudo bash setup.sh --update
```

This will:
- Update mise itself
- Upgrade all mise-managed tools (node, bun, go, rust, python, CLI tools)
- Update coding agents (claude, codex, gemini)
- Update cc-switch-cli

### Custom User

```bash
# Install for a different user
TARGET_USER=myuser sudo bash setup.sh
```

### Custom Home Directory

```bash
# Specify custom home directory
TARGET_USER=myuser TARGET_HOME=/custom/home/myuser sudo bash setup.sh
```

### After Installation

```bash
# Reload shell
source ~/.zshrc

# Verify mise
mise list

# Check tool versions
node --version
bun --version
go version
rustc --version
python --version

# Test CLI tools
rg --version
fd --version
bat --version
lazygit --version

# Test coding agents
claude --version
codex --version
gemini --version
```

### Using Mise

```bash
# List installed tools
mise list

# Install a specific version
mise use node@20

# Install globally
mise use --global python@3.11

# Update all tools
mise upgrade

# See available versions
mise ls-remote node
```

### Using Coding Agents

```bash
# Claude Code (Anthropic)
claude                    # Start interactive mode
claude "explain this code"
claude --help

# Codex (OpenAI)
codex                     # Start interactive mode
codex "write a function"
codex --help

# Gemini (Google)
gemini                    # Start interactive mode
gemini "help me debug"
gemini --help

# cc-switch (Multi-agent manager)
cc-switch                 # Interactive TUI
cc-switch --help          # Show all commands
cc-switch sync            # Sync configs across agents
cc-switch mcp             # Manage MCP servers
```

### Using CLI Tools

```bash
# ripgrep - Fast search
rg "pattern" .
rg -i "case insensitive"
rg -t py "import"          # Search only Python files

# fd - Fast find
fd "*.py"                  # Find Python files
fd -e js                   # Find by extension
fd -H hidden               # Include hidden files

# bat - Better cat
bat file.py                # View with syntax highlighting
bat -A file.txt            # Show all characters
bat --diff file1 file2     # Diff two files

# eza - Better ls
eza -la                    # Long format with all files
eza --tree                 # Tree view
eza --git                  # Show git status

# zoxide - Smart cd
z projects                 # Jump to frequently used dir
zi                         # Interactive selection

# fzf - Fuzzy finder
fzf                        # Interactive file picker
history | fzf              # Search history
cat file | fzf             # Filter lines

# lazygit - Git TUI
lazygit                    # Open git interface

# jq/yq - JSON/YAML processing
cat data.json | jq '.key'
cat config.yaml | yq '.setting'

# dust - Disk usage
dust                       # Current directory
dust /path                 # Specific path

# btop - System monitor
btop                       # Interactive monitor

# hyperfine - Benchmarking
hyperfine 'sleep 0.1'
hyperfine 'cmd1' 'cmd2'    # Compare commands

# tokei - Code statistics
tokei                      # Current directory
tokei src/                 # Specific path
```

## Configuration Files

After installation, these files are configured:

| File | Purpose |
|------|---------|
| `~/.zshrc` | Zsh configuration (mise, p10k) |
| `~/.bashrc` | Bash configuration (mise) |
| `~/.p10k.zsh` | Powerlevel10k theme config |
| `~/.config/mise/config.toml` | Mise tool versions |
| `/etc/sudoers.d/ubuntu` | Passwordless sudo |

## Troubleshooting

### Mise not found after install

```bash
# Reload shell
source ~/.zshrc
# or
source ~/.bashrc

# Or manually activate
eval "$(~/.local/bin/mise activate bash)"
```

### Tool not found

```bash
# Check if mise has it
mise list

# Reinstall
mise use --global <tool>@latest

# Check PATH
echo $PATH | tr ':' '\n' | grep mise
```

### Permission denied

```bash
# Run with sudo
sudo bash setup.sh

# Or fix ownership
sudo chown -R $USER:$USER ~/.local ~/.config
```

### Docker not working

```bash
# Check group membership
groups

# Re-login to apply docker group
su - $USER

# Or use sudo
sudo docker ps
```

### Coding agent API keys

```bash
# Claude Code
export ANTHROPIC_API_KEY="your-key"

# Codex
export OPENAI_API_KEY="your-key"

# Gemini
export GOOGLE_API_KEY="your-key"

# Add to ~/.zshrc for persistence
echo 'export ANTHROPIC_API_KEY="your-key"' >> ~/.zshrc
```

## Uninstall

```bash
# Remove mise and all tools
rm -rf ~/.local/share/mise
rm -rf ~/.config/mise
rm -rf ~/.local/bin/mise

# Remove shell integrations
# Edit ~/.zshrc and ~/.bashrc to remove mise lines

# Remove Oh My Zsh
rm -rf ~/.oh-my-zsh

# Remove coding agents
rm -rf ~/.local/bin/{claude,codex,gemini}
rm -rf ~/.bun
```

## Customization

### Add more mise tools

Edit the script's `install_via_mise()` function:

```bash
local cli_tools=(
    # ... existing tools ...
    "your-tool@latest"
)
```

### Skip certain phases

Comment out phases in `main()`:

```bash
main() {
    setup_system
    install_base_packages
    setup_shell
    install_mise
    install_via_mise
    # install_agents      # Skip agents
    install_github_cli
}
```

### Change default user

```bash
# At the top of the script
TARGET_USER="${TARGET_USER:-myuser}"
```

## License

MIT License - Feel free to modify and distribute.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Test on a fresh Ubuntu VM
4. Submit a pull request
