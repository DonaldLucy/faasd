#!/bin/bash
# install_protobuf_grpc.sh
set -euo pipefail # Added 'u' for unset variables, 'o pipefail' for better error handling

# --- Configuration ---
PROTOBUF_VERSION="v26.1" # Changed to a recent, stable tag (e.g., v26.1)
GRPC_VERSION="v1.64.0"    # Changed to a recent, stable tag (e.g., v1.64.0)
INSTALL_DIR="/usr/local"  # Standard installation prefix
BUILD_DIR="/tmp/protobuf_grpc_build"

echo "=== System Update and Dependencies Installation ==="
sudo apt update
sudo apt upgrade -y

echo "Installing build essentials and common tools..."
# Added 'unzip' and 'autoconf/automake/libtool' are already included.
# Removed 'libabsl-dev' - often better to let gRPC handle Abseil dependencies via submodules.
sudo apt install -y build-essential cmake git pkg-config curl wget unzip \
    autoconf automake libtool

# Cleanup previous build artifacts and create a fresh build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# --- Installing Protocol Buffers (Protobuf) ---

echo "=== Installing Protocol Buffers ($PROTOBUF_VERSION) ==="
if [ ! -d "protobuf" ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
fi
cd protobuf
# Use the configured version
git checkout "$PROTOBUF_VERSION"
git submodule update --init --recursive

# The 'safe.directory' config is generally needed when working with git in /tmp.
git config --global --add safe.directory "$BUILD_DIR/protobuf"

# Build and install Protobuf
./autogen.sh
./configure --prefix="$INSTALL_DIR" # Specify installation directory
make -j$(nproc)
sudo make install
sudo ldconfig

echo "Protoc version verification:"
protoc --version
if [ $? -ne 0 ]; then
    echo "ERROR: Protobuf installation failed."
    exit 1
fi

# --- Installing gRPC and gRPC C++ dependencies (gRPC core) ---

echo "=== Installing gRPC ($GRPC_VERSION) ==="
cd "$BUILD_DIR"
if [ ! -d "grpc" ]; then
    # Clone with the specified version tag
    git clone -b "$GRPC_VERSION" https://github.com/grpc/grpc
fi

cd grpc
# Checkout again to ensure the correct version if directory existed prior
git checkout "$GRPC_VERSION"
# Recursively update submodules (including Abseil, re2, etc.)
git submodule update --init --recursive

# Build and install gRPC
mkdir -p cmake/build
cd cmake/build
cmake ../.. -DgRPC_INSTALL=ON \
    -DgRPC_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" # Specify installation directory
make -j$(nproc)
sudo make install
sudo ldconfig

# --- Verification ---

echo "=== Verifying gRPC installation ==="
GRPC_PLUGIN_PATH=$(which grpc_cpp_plugin 2>/dev/null)
if [ -n "$GRPC_PLUGIN_PATH" ]; then
    echo "grpc_cpp_plugin found at $GRPC_PLUGIN_PATH"
else
    echo "ERROR: grpc_cpp_plugin not found. Please check Protobuf and gRPC logs."
    exit 1
fi

echo "=== Setup complete! Protobuf and gRPC are installed to $INSTALL_DIR ==="