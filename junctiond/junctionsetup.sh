#!/bin/bash
# install_protobuf_grpc_final.sh
set -euo pipefail # Exit on error, unset variable, or command failure in a pipe

# --- Configuration ---
# Use recent, stable tags. You can change these versions if needed.
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
# Tools needed for building from source (includes autoconf for Protobuf's configure)
sudo apt install -y build-essential cmake git pkg-config curl wget unzip autoconf automake libtool

# Prepare fresh build environment
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

---

# --- 2. Installing Protocol Buffers (Protobuf) ---
## ⚙️ Building Protobuf (Uses Autotools)
echo "--- 2. Building Protobuf from source (Autotools) ---"

if [ ! -d "protobuf" ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
fi
cd protobuf
git checkout "$PROTOBUF_VERSION"
# Pull in dependencies like Googletest
git submodule update --init --recursive

# Mark the directory as safe for git operations in /tmp
git config --global --add safe.directory "$PWD"

# **Protobuf Build Steps:**
# Use ./configure directly for modern tags (or ./autogen.sh then ./configure for older tags)
# This assumes the configure script is already present after cloning.
./configure --prefix="$INSTALL_DIR"
make -j$(nproc)
sudo make install
sudo ldconfig

cd "$BUILD_DIR" # Return to main build directory staging area

echo "Protoc version verification:"
protoc --version
if [ $? -ne 0 ]; then
    echo "ERROR: Protobuf installation failed. Exiting."
    exit 1
fi

---

# --- 3. Installing gRPC (gRPC core) ---
## 🔗 Building gRPC (Uses CMake)
echo "--- 3. Building gRPC from source (CMake) ---"

if [ ! -d "grpc" ]; then
    git clone -b "$GRPC_VERSION" https://github.com/grpc/grpc
fi

cd grpc
git checkout "$GRPC_VERSION"
# Crucial step: pulls in Abseil, re2, and other critical gRPC dependencies
git submodule update --init --recursive

# **gRPC Build Steps:**
# gRPC uses CMake. We skip ./configure and ./autogen.sh entirely.
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

cd "$BUILD_DIR" # Return to main build directory

---

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