#!/bin/bash
set -e

echo "=== Updating system ==="
sudo apt update
sudo apt upgrade -y

echo "=== Installing build essentials ==="
sudo apt install -y build-essential cmake git pkg-config autoconf automake libtool curl unzip wget

echo "=== Installing Abseil (for gRPC dependencies) ==="
sudo apt install -y libabsl-dev

echo "=== Installing Protocol Buffers ==="
PROTOBUF_VERSION="33.1"
cd /tmp
if [ ! -d protobuf ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
else
    cd protobuf
    git fetch --tags
    git reset --hard
fi
cd protobuf
git checkout v$PROTOBUF_VERSION
git submodule update --init --recursive

if [ -f "./autogen.sh" ]; then
    chmod +x ./autogen.sh
    ./autogen.sh
fi

./configure
make -j$(nproc)
sudo make install
sudo ldconfig

echo "Protoc version:"
protoc --version

echo "=== Installing gRPC ==="
cd /tmp
if [ ! -d grpc ]; then
    git clone -b v1.58.0 https://github.com/grpc/grpc
else
    cd grpc
    git reset --hard
    git submodule update --init --recursive
fi

cd grpc
git submodule update --init --recursive
mkdir -p cmake/build
cd cmake/build
cmake ../.. -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install
sudo ldconfig

echo "=== Verifying gRPC installation ==="
if command -v grpc_cpp_plugin &> /dev/null
then
    echo "grpc_cpp_plugin found at $(which grpc_cpp_plugin)"
else
    echo "ERROR: grpc_cpp_plugin not found"
    exit 1
fi

echo "=== Setup complete ==="
