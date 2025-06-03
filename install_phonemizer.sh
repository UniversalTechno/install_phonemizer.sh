#!/usr/bin/env bash
set -e

echo "🔧 Detecting system and configuring Docker repo..."
. /etc/os-release
DISTRO_ID=$ID
DISTRO_CODENAME=$VERSION_CODENAME

if [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "debian" ]]; then
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/${DISTRO_ID}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} jammy stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
else
  echo "❌ Unsupported distribution: $DISTRO_ID"
  exit 1
fi

echo "📦 Updating APT and installing build dependencies..."
sudo apt update
sudo apt install -y \
  git python3 python3-pip python3-venv \
  build-essential cmake pkg-config \
  libespeak-ng-dev curl g++ unzip

echo "🐍 Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip setuptools wheel

echo "📥 Cloning and building ONNX Runtime..."
if [[ ! -d "onnxruntime" ]]; then
  git clone --recursive https://github.com/microsoft/onnxruntime
fi

cd onnxruntime
./build.sh --config Release --build_shared_lib --parallel --build_dir build --skip_tests
cd ..

echo "🔧 Exporting ONNXRUNTIME_DIR..."
export ONNXRUNTIME_DIR="$PWD/onnxruntime/build/Linux/Release"
echo "export ONNXRUNTIME_DIR=$ONNXRUNTIME_DIR" >> venv/bin/activate
export CPLUS_INCLUDE_PATH="$ONNXRUNTIME_DIR/include"
export LIBRARY_PATH="$ONNXRUNTIME_DIR/lib"

echo "📦 Installing piper_phonemize with correct paths..."
pip install --no-binary :all: \
  --global-option=build_ext \
  --global-option="-I$ONNXRUNTIME_DIR/include" \
  --global-option="-L$ONNXRUNTIME_DIR/lib" \
  git+https://github.com/rhasspy/piper-phonemize

echo "✅ All done! To activate your environment, run:"
echo "    source venv/bin/activate"
