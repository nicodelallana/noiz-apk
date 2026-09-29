#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Bizkaia Transit — Environment Bootstrap Script (Fedora / Linux)
# ==============================================================================
# This script verifies the host toolchain, checks for Flutter, Dart, FVM,
# Android toolchain prerequisites, and local Docker for Supabase development.
# ==============================================================================

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

info() {
  echo -e "${BOLD}[INFO]${RESET} $1"
}

success() {
  echo -e "${GREEN}${BOLD}[OK]${RESET} $1"
}

warn() {
  echo -e "${YELLOW}${BOLD}[WARN]${RESET} $1"
}

error() {
  echo -e "${RED}${BOLD}[ERROR]${RESET} $1"
}

echo -e "${BOLD}=====================================================${RESET}"
echo -e "${BOLD}       Bizkaia Transit — Development Environment    ${RESET}"
echo -e "${BOLD}=====================================================${RESET}"
echo ""

# 1. Check OS
info "Checking Operating System..."
if [ -f /etc/os-release ]; then
  . /etc/os-release
  info "Detected: ${NAME:-Linux} ${VERSION:-}"
else
  info "Detected generic Linux system."
fi

# 2. Check Essential Tools
info "Checking essential utilities..."
MISSING_PKGS=()

for cmd in git curl unzip xz tar; do
  if command -v "$cmd" >/dev/null 2>&1; then
    success "$cmd is installed"
  else
    warn "$cmd is NOT installed"
    MISSING_PKGS+=("$cmd")
  fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  warn "Missing basic utilities: ${MISSING_PKGS[*]}"
  echo "On Fedora, run: sudo dnf install -y ${MISSING_PKGS[*]}"
fi

# 3. Check Docker (for local Supabase)
info "Checking Docker (for local Supabase development)..."
if command -v docker >/dev/null 2>&1; then
  success "Docker is installed ($(docker --version))"
  if docker info >/dev/null 2>&1; then
    success "Docker daemon is running and accessible"
  else
    warn "Docker daemon is not running or current user is not in 'docker' group."
    echo "  Start Docker with: sudo systemctl start docker"
    echo "  Allow non-root access: sudo usermod -aG docker \$USER && newgrp docker"
  fi
else
  warn "Docker is not installed. Required for running 'supabase start' locally."
  echo "  Install on Fedora: sudo dnf install -y docker-ce docker-ce-cli containerd.io"
fi

# 4. Check FVM and Flutter
info "Checking Flutter / FVM..."
FLUTTER_READY=false

if command -v fvm >/dev/null 2>&1; then
  success "FVM is installed ($(fvm --version 2>/dev/null || true))"
  info "Running 'fvm install' based on .fvmrc..."
  fvm install || true
  FLUTTER_READY=true
elif command -v flutter >/dev/null 2>&1; then
  success "Flutter SDK is directly available in PATH ($(flutter --version | head -n 1))"
  FLUTTER_READY=true
else
  warn "Neither 'flutter' nor 'fvm' was found in PATH."
  echo ""
  echo -e "${BOLD}How to install Flutter / FVM:${RESET}"
  echo "Option A (Recommended: FVM standalone installer):"
  echo "  curl -fsSL https://fvm.app/install.sh | bash"
  echo "  export PATH=\"\$HOME/.fvm/default/bin:\$PATH\""
  echo "  fvm install"
  echo ""
  echo "Option B (Manual Flutter download):"
  echo "  mkdir -p ~/development"
  echo "  curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_stable.tar.xz"
  echo "  tar -xf flutter_linux_stable.tar.xz -C ~/development/"
  echo "  export PATH=\"\$HOME/development/flutter/bin:\$PATH\""
  echo ""
fi

# 5. Check Environment Config Templates
info "Checking environment configuration files..."
if [ -f env/dev.json ]; then
  success "env/dev.json exists"
else
  if [ -f env/dev.example.json ]; then
    info "env/dev.json not found. You can initialize it with: cp env/dev.example.json env/dev.json"
  fi
fi

# 6. Summary
echo ""
echo -e "${BOLD}=====================================================${RESET}"
if [ "$FLUTTER_READY" = true ]; then
  success "Core environment is ready for development!"
else
  info "Follow the installation instructions above to complete Flutter SDK setup."
fi
echo -e "${BOLD}=====================================================${RESET}"
