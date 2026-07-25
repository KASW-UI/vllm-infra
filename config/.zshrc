# Minimal zsh config for vllm-dev container
export EDITOR=vim

# Activate venv on shell start
source /workspace/.venv/bin/activate 2>/dev/null

# Environment configs (VLLM_TARGET_DEVICE, LD_PRELOAD, OMP_NUM_THREADS, etc.)
source /home/dev/.config/cpu-vllm-infra/torch.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/vllm.env 2>/dev/null || true
source /home/dev/.config/cpu-vllm-infra/docker.env 2>/dev/null || true

# Aliases
alias ll='ls -alh'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias gl='git log --oneline'
alias gd='git diff'
alias gp='git push'
alias py='python'
alias ipy='ipython'
alias serve='bash /workspace/scripts/serve.sh'
alias bench='bash /workspace/scripts/bench.sh'

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Prompt
PROMPT='%F{cyan}%n@vllm-dev%f:%F{blue}%~%f $ '

# Dependency check on shell start
bash /workspace/scripts/welcome.sh
