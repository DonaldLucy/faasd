#!/bin/bash
set -euo pipefail

# --- Configuration ---
PROTOBUF_VERSION="v26.1"
GRPC_VERSION="v1.64.0"
INSTALL_DIR="/usr/local"
BUILD_DIR="/tmp/protobuf_grpc_build"

echo "=== 🚀 Starting Setup: Protobuf ($PROTOBUF_VERSION) and gRPC ($GRPC_VERSION) ==="

# --- 1. System Update and Dependencies ---
echo "--- 1. Installing Prerequisites ---"
sudo apt update
sudo apt upgrade -y

echo "Installing build essentials..."
sudo apt install -y build-essential cmake git pkg-config curl \
    autoconf libtool

# Cleanup and Prepare Build Directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# -----------------------------------------------------------------------------

# --- 2. Installing Protocol Buffers (Protobuf) via CMake ---
echo "--- 2. Building Protobuf (CMake) ---"

# Clone Protobuf
if [ ! -d "protobuf" ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
fi
cd protobuf
git checkout "$PROTOBUF_VERSION"
git submodule update --init --recursive

# Safe directory config
git config --global --add safe.directory "$PWD"

# Build using CMake (Fixes the missing ./configure issue)
mkdir -p cmake_build
cd cmake_build
cmake .. \
    -DCMAKE_CXX_STANDARD=17 \
    -Dprotobuf_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

make -j$(nproc)
sudo make install
sudo ldconfig

cd "$BUILD_DIR" # Return to base

# Verify Protobuf
echo "Verifying Protoc..."
protoc --version

# -----------------------------------------------------------------------------

# --- 3. Installing gRPC via CMake ---
echo "--- 3. Building gRPC (CMake) ---"

# Clone gRPC
if [ ! -d "grpc" ]; then
    git clone -b "$GRPC_VERSION" https://github.com/grpc/grpc
fi
cd grpc
git checkout "$GRPC_VERSION"
git submodule update --init --recursive

# Build using CMake
mkdir -p cmake_build
cd cmake_build
cmake .. \
    -DCMAKE_CXX_STANDARD=17 \
    -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DgRPC_ABSL_PROVIDER=module \
    -DgRPC_PROTOBUF_PROVIDER=package \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

make -j$(nproc)
sudo make install
sudo ldconfig

cd "$BUILD_DIR"

# -----------------------------------------------------------------------------

# --- 4. Final Verification ---
echo "--- 4. Verification ---"

if command -v grpc_cpp_plugin &> /dev/null; then
    echo "✅ SUCCESS: grpc_cpp_plugin found at $(which grpc_cpp_plugin)"
else
    echo "❌ ERROR: grpc_cpp_plugin not found."
    exit 1
fi

echo "=== ✨ Setup Complete! ==="