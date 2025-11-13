# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
# Added by dev-ex zsh-functions
fpath=(~/.zsh $fpath)
autoload -Uz clear-schema-registry
autoload -Uz tsh-login
autoload -Uz tsh-db
autoload -Uz tsh-db-forward
autoload -Uz pod-forward
autoload -Uz pod-shell
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
alias ai='codex --dangerously-bypass-approvals-and-sandbox -s danger-full-access'

boop() {
  if [ $? -eq 0 ]; then
    afplay /System/Library/Sounds/Glass.aiff &
  else
    afplay /System/Library/Sounds/Funk.aiff &
  fi
};

chk() {
  ./gradlew ktfmtFormat check "$@" ; boop
}

export AI_PREFS="Preferred editor: vim. Prefer zsh syntax. Use brew for installs."

# Company-safe Warp-AI-like helper using Codex CLI + fzf
# Usage:
#   ai "undo last git commit"
#   ai "rename all *.jpeg to *.jpg"
# Flags:
#   AI_N=3         -> number of suggestions (1-5)
#   AI_DRY=1       -> don't execute, just print
#   AI_COPY=1      -> copy selected command to clipboard instead of running
#   AI_NOCTX=1     -> don't send recent cmds/git status as context

aie() {
  local q="$*"
  [[ -z "$q" ]] && { echo "Usage: ai <what you want to do>"; return 1; }

  # Config
  local N="${AI_N:-3}"
  [[ "$N" -lt 1 || "$N" -gt 5 ]] && N=3

  # Optional context (minimised for privacy)
  local CWD="$(pwd)"
  local LAST_CMDS="" GIT_SUMMARY=""
  if [[ -z "$AI_NOCTX" ]]; then
    LAST_CMDS="$(fc -ln -20 2>/dev/null | tail -n 10)"
    if command -v git >/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      GIT_SUMMARY="$(git status -s 2>/dev/null | head -n 20)"
      [[ -z "$GIT_SUMMARY" ]] && GIT_SUMMARY="(clean)"
    fi
  fi

  # Prompt template -> JSON only
  local prompt
  prompt=$'Return ONLY compact JSON:\n{"commands":[{"cmd":"","why":""}]}\n'\
$'Rules:\n- Provide '"$N"$' safe, reversible zsh/bash commands (best first).\n'\
$'- Prefer --dry-run or non-destructive forms unless user explicitly asks otherwise.\n'\
$'- Never include rm -rf or destructive flags unless explicitly requested.\n'\
$'- macOS environment.\n\n'\
$"Task: ${q}\n"\
$"cwd: ${CWD}\n"\
$"recent_cmds:\n${LAST_CMDS}\n"\
$"git:\n${GIT_SUMMARY}\n"

  # One-shot Codex call (non-interactive)
  local out
  if ! out="$(codex exec "$prompt" 2>/dev/null)"; then
    echo "codex failed (is it installed/logged in?)"; return 1
  fi

  # Extract/validate JSON
  local content
  content="$(printf '%s' "$out" | jq -r '.commands? // empty' 2>/dev/null)"
  if [[ -z "$content" || "$content" == "null" ]]; then
    echo "Unexpected Codex response:"; echo "$out"; return 1
  fi

  # Pretty list for user + gather options
  local menu
  menu="$(printf '%s' "$out" | jq -r '.commands[] | "- \(.cmd)\t# \(.why)"')" || {
    echo "$out"; return 1;
  }
  echo "$menu"

  # Choose command (fzf optional)
  local cmd
  if command -v fzf >/dev/null; then
    cmd="$(printf '%s\n' "$out" | jq -r '.commands[].cmd' | fzf --prompt="Run which command? > ")"
  else
    cmd="$(printf '%s\n' "$out" | jq -r '.commands[0].cmd')"
  fi

  [[ -z "$cmd" ]] && { echo "No command selected."; return 1; }

  echo
  echo "Selected:"
  echo "  $cmd"
  if [[ -n "$AI_COPY" && "$AI_COPY" -eq 1 ]]; then
    if command -v pbcopy >/dev/null; then
      printf '%s' "$cmd" | pbcopy
      echo "✅ Copied to clipboard (not executed)."
      return 0
    else
      echo "pbcopy not found; skipping copy."
    fi
  fi

  if [[ -n "$AI_DRY" && "$AI_DRY" -eq 1 ]]; then
    echo "🔎 Dry run (not executing)."
    return 0
  fi

  read -q "REPLY?Proceed to run? [y/N] "; echo
  if [[ "$REPLY" == [yY] ]]; then
    eval "$cmd"
  else
    echo "Cancelled."
  fi
}

# Setup zoxide
eval "$(zoxide init zsh)"



[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
