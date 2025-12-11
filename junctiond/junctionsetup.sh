#!/bin/bash
# install_protobuf_grpc_v2.sh
set -euo pipefail # Exit on error, unset variable, or command failure in a pipe

# --- Configuration ---
# Use recent, stable tags. Adjust these if specific versions are required.
PROTOBUF_VERSION="v26.1"
GRPC_VERSION="v1.64.0"
INSTALL_DIR="/usr/local"
BUILD_DIR="/tmp/protobuf_grpc_build"

echo "=== 🚀 Starting Setup: Protobuf ($PROTOBUF_VERSION) and gRPC ($GRPC_VERSION) ==="

# --- 1. System Update and Dependencies ---
## 📦 Installing Prerequisites
echo "--- 1. Installing Prerequisites ---"
sudo apt update
sudo apt upgrade -y

echo "Installing build essentials and development tools..."
# Minimal set of tools needed for building from source
sudo apt install -y build-essential cmake git pkg-config curl wget unzip \
    autoconf automake libtool

# Prepare fresh build environment
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# --- 2. Installing Protocol Buffers (Protobuf) ---
## ⚙️ Building Protobuf
echo "--- 2. Building Protobuf from source ---"

if [ ! -d "protobuf" ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
fi
cd protobuf
git checkout "$PROTOBUF_VERSION"
git submodule update --init --recursive

# The 'safe.directory' config is often needed when working with git in /tmp.
git config --global --add safe.directory "$PWD"

# Protobuf (modern versions) uses ./configure directly
./configure --prefix="$INSTALL_DIR"
make -j$(nproc)
sudo make install
sudo ldconfig

cd "$BUILD_DIR" # Return to main build directory

echo "Protoc version verification:"
protoc --version
if [ $? -ne 0 ]; then
    echo "ERROR: Protobuf installation failed. Exiting."
    exit 1
fi

# --- 3. Installing gRPC (gRPC core) ---
## 🔗 Building gRPC
echo "--- 3. Building gRPC from source ---"

if [ ! -d "grpc" ]; then
    git clone -b "$GRPC_VERSION" https://github.com/grpc/grpc
fi

cd grpc
git checkout "$GRPC_VERSION"
# Submodules include Abseil (for gRPC dependencies), re2, etc.
git submodule update --init --recursive

# gRPC uses CMake for building (DO NOT run autogen.sh)
mkdir -p cmake/build
cd cmake/build
cmake ../.. \
    -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

make -j$(nproc)
sudo make install
sudo ldconfig

# --- 4. Verification ---
## ✅ Final Checks
echo "--- 4. Verification ---"

GRPC_PLUGIN_PATH=$(which grpc_cpp_plugin 2>/dev/null)
if [ -n "$GRPC_PLUGIN_PATH" ]; then
    echo "**SUCCESS**: grpc_cpp_plugin found at $GRPC_PLUGIN_PATH"
    echo "Protobuf and gRPC libraries and headers are installed to $INSTALL_DIR"
else
    echo "ERROR: grpc_cpp_plugin not found. gRPC installation failed."
    exit 1
fi

echo "=== ✨ Setup complete! ==="