#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"
export PATH="$HOME/.local/bin:$PATH"
SUDO=""
if [ "$(id -u)" != "0" ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi
fi
NEED_DEPS="false"
for cmd in curl git gcc make; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    NEED_DEPS="true"
  fi
done
if [ "$NEED_DEPS" = "true" ]; then
  OS_ID=""
  OS_LIKE=""
  if [ -f /etc/os-release ]; then
    OS_ID="$(grep -E "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')"
    OS_LIKE="$(grep -E "^ID_LIKE=" /etc/os-release | cut -d= -f2 | tr -d '"')"
  fi
  OS_MATCH=" $OS_ID $OS_LIKE "
  case "$OS_MATCH" in
    *"debian"*|*"ubuntu"*)
      $SUDO apt-get update
      $SUDO apt-get install -y curl git build-essential libssl-dev libyaml-dev zlib1g-dev libreadline-dev libffi-dev
      ;;
    *"suse"*|*"opensuse"*)
      $SUDO zypper refresh
      $SUDO zypper install -y curl git gcc make libopenssl-devel libyaml-devel zlib-devel readline-devel libffi-devel
      ;;
    *"fedora"*|*"rhel"*|*"centos"*)
      $SUDO dnf install -y curl git gcc make openssl-devel libyaml-devel zlib-devel readline-devel libffi-devel
      ;;
    *"arch"*)
      $SUDO pacman -Sy --noconfirm curl git base-devel openssl libyaml zlib readline libffi
      ;;
    *"alpine"*)
      $SUDO apk add curl git build-base openssl-dev yaml-dev zlib-dev readline-dev libffi-dev
      ;;
    *)
      echo "Unsupported OS for automatic dependency install, please install curl git gcc make openssl libyaml zlib readline libffi manually"
      exit 1
      ;;
  esac
  if [ "$(uname -s)" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      brew install openssl libyaml readline libffi
    else
      echo "Homebrew not found, please install Homebrew and openssl libyaml readline libffi manually"
      exit 1
    fi
  fi
fi
if ! command -v mise >/dev/null 2>&1; then
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
mise trust 2>/dev/null || true
if [ -f mise.toml ] || [ -f .tool-versions ]; then
  mise install
else
  mise use ruby@3.3
fi
BUNDLER_VERSION="$(awk "/BUNDLED WITH/{getline; print \$1; exit}" Gemfile.lock)"
if [ -z "$BUNDLER_VERSION" ]; then
  BUNDLER_VERSION="2.6.9"
fi
echo "Using Ruby: $(mise exec -- ruby -v)"
echo "Using Bundler: $BUNDLER_VERSION"
mise exec -- gem install bundler -v "$BUNDLER_VERSION"
mise exec -- bundle "_${BUNDLER_VERSION}_" config set --local path "vendor/bundle"
mise exec -- bundle "_${BUNDLER_VERSION}_" install
JEKYLL_ENV=production mise exec -- bundle "_${BUNDLER_VERSION}_" exec jekyll build
echo "Install complete"
echo "Run: mise exec -- bundle exec jekyll serve"
