#!/bin/bash

set -e

function title() {
  echo -e "\033[1;34m➡ $1\033[0m"
}

function info() {
  echo -e "\033[1;32m$1\033[0m"
}

function warn() {
  echo -e "\033[1;33m$1\033[0m"
}

function error_exit() {
  echo -e "\033[1;31m$1\033[0m" >&2
  exit 1
}

# Ensure script runs from its directory
cd "$(dirname "$0")"

# 🐧 OS Detection
OS=$(lsb_release -is)
VER=$(lsb_release -rs)
ARCH=$(uname -m)
info "Detected OS: $OS $VER ($ARCH)"

# 📦 Ensure APT is updated and required tools are installed
info "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
  git curl build-essential cmake pkg-config \
  python3 python3-pip python3-venv \
  libespeak-ng-dev

# 🐍 Setup Python venv
info "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel

# 📥 Clone ONNX Runtime (if not already exists)
if [ ! -d "onnxruntime" ]; then
  info "Cloning ONNX Runtime..."
  git clone --recursive https://github.com/microsoft/onnxruntime
fi
cd onnxruntime

# 🔧 Build ONNX Runtime
info "Building ONNX Runtime..."
./build.sh --config Release --build_shared_lib --parallel
cd ..

# 🔧 Export ONNXRUNTIME_DIR
export ONNXRUNTIME_DIR=$(realpath onnxruntime/build/Linux/Release)

# 🧪 Clone and patch piper_phonemize
if [ ! -d "piper-phonemize" ]; then
  info "Cloning piper-phonemize..."
  git clone https://github.com/rhasspy/piper-phonemize
fi
cd piper-phonemize

info "Patching setup.cfg for ONNX paths..."
cat > setup.cfg <<EOF
[build_ext]
include_dirs = $ONNXRUNTIME_DIR/include
library_dirs = $ONNXRUNTIME_DIR/lib
EOF

# 🧱 Build and install piper_phonemize
info "Installing piper_phonemize in editable mode..."
pip install -e .

cd ..

# 🔁 Add ONNX runtime lib path to venv
if ! grep -q "LD_LIBRARY_PATH" venv/bin/activate; then
  echo "export LD_LIBRARY_PATH=$ONNXRUNTIME_DIR/lib:\$LD_LIBRARY_PATH" >> venv/bin/activate
  info "LD_LIBRARY_PATH added to venv activation script."
fi

info "✅ Installation complete!"
echo "Run: source venv/bin/activate"
echo "Then: python -c 'from piper_phonemize import phonemize_espeak; print(phonemize_espeak("hello", "en"))'"
