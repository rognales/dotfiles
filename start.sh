#!/bin/sh

# Welcome to the thoughtbot laptop script!
# Be prepared to turn your laptop (or desktop, no haters here)
# into an awesome development machine.

# shellcheck disable=SC3043

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\\n$fmt\\n" "$@"
}

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\\n" "$text" >> "$zshrc"
    else
      printf "\\n%s\\n" "$text" >> "$zshrc"
    fi
  fi
}

fancy_echo "This script will install the thoughtbot laptop script."

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

# Determine Homebrew prefix
arch="$(uname -m)"
if [ "$arch" = "arm64" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

update_shell() {
  local shell_path;
  shell_path="$(command -v zsh)"

  fancy_echo "Changing your shell to zsh ..."
  if ! grep "$shell_path" /etc/shells > /dev/null 2>&1 ; then
    fancy_echo "Adding '$shell_path' to /etc/shells"
    sudo sh -c "echo $shell_path >> /etc/shells"
  fi
  sudo chsh -s "$shell_path" "$USER"
}

case "$SHELL" in
  */zsh)
    if [ "$(command -v zsh)" != "$HOMEBREW_PREFIX/bin/zsh" ] ; then
      update_shell
    fi
    ;;
  *)
    update_shell
    ;;
esac

# checks architecture
if [ "$(uname -m)" = "arm64" ]
  then
  # checks if Rosetta is already installed
  if ! pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto > /dev/null 2>&1
  then
    echo "Installing Rosetta"
    # Installs Rosetta2
    softwareupdate --install-rosetta --agree-to-license
  else
    echo "Rosetta is installed"
  fi
fi

# Install Homebrew
if test ! $(which brew); then
  fancy_echo "Installing Homebrew ..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    append_to_zshrc "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""

    export PATH="$HOMEBREW_PREFIX/bin:$PATH"
else
   fancy_echo "Homebrew already installed."
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

# Update Homebrew recipes and install formulaes/casks listed in the Brewfile
fancy_echo "Updating Homebrew formulae ..."
brew update --force # https://github.com/Homebrew/brew/issues/1151
fancy_echo "Installing Homebrew formulae ..."
brew bundle --file ./Brewfile

# Check for Oh My Zsh and install if we don't have it
if test ! $(which omz); then
  fancy_echo "Installing Oh My Zsh ..."
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
else
  fancy_echo "Oh My Zsh already installed ..."
fi

# Re-register homebrew
append_to_zshrc "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""

# Removes .starship.toml from $HOME (if it exists) and symlinks the .starship.toml file from the .dotfiles
rm -rf $HOME/.config/starship.toml
ln -s .starship.toml $HOME/.config/starship.toml
append_to_zshrc "eval \"\$$(starship init zsh)\""

# Install PHP extensions with PECL
pecl install imagick redis

# Install global Composer packages
/usr/local/bin/composer global require laravel/valet beyondcode/expose spatie/global-ray tightenco/takeout

# Install Laravel Valet
$HOME/.composer/vendor/bin/valet install

# Install Global Ray
$HOME/.composer/vendor/bin/global-ray install

# Prepare docker containers (redis, mysql, elasticsearch)
$HOME/.composer/vendor/bin/takeout enable redis mysql elastisearch --default

# Remove outdated versions from the cellar.
brew cleanup

# Create a Codes directory, where I keep all my code
mkdir $HOME/Codes

# Symlink the Mackup config file to the home directory
ln -s .mackup.cfg $HOME/.mackup.cfg

# TODO
# zsh plugins
# zsh config

# TODO
# Set macOS preferences - we will run this last because this will reload the shell
# source ./.macos
