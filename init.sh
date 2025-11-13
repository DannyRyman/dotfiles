#!/usr/bin/env bash
set -euo pipefail

main() {
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  require_macos
  ensure_homebrew
  install_brew_packages
  run_stow "$repo_root"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This setup script currently targets macOS only." >&2
    exit 1
  fi
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    eval "$("$(command -v brew)" shellenv)"
    return
  fi

  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # shellcheck disable=SC1090
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
}

install_brew_packages() {
  local taps=(
    homebrew/cask-fonts
  )
  local formulae=(
    stow
    zoxide
    fzf
    jq
    ripgrep
    neovim
  )
  local casks=(
    wezterm
    font-meslo-lg-nerd-font
  )

  for tap in "${taps[@]}"; do
    if ! brew tap | grep -qx "$tap"; then
      brew tap "$tap"
    fi
  done

  if ((${#formulae[@]})); then
    brew install "${formulae[@]}"
  fi

  if ((${#casks[@]})); then
    brew install --cask "${casks[@]}"
  fi
}

run_stow() {
  local repo_root="$1"
  local stow_target="${STOW_TARGET:-$HOME}"
  local packages=(
    shell
    nvim
    wezterm
  )

  mkdir -p "$stow_target"
  cd "$repo_root"

  for pkg in "${packages[@]}"; do
    if [[ -d "$repo_root/$pkg" ]]; then
      stow --restow --target "$stow_target" "$pkg"
    else
      echo "Skipping missing package: $pkg" >&2
    fi
  done
}

main "$@"
