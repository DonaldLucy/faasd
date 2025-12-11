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
PROTOBUF_VERSION="23.5"
cd /tmp
if [ ! -d protobuf ]; then
    git clone https://github.com/protocolbuffers/protobuf.git
fi
cd protobuf
git fetch --tags
git checkout v$PROTOBUF_VERSION
git submodule update --init --recursive
./autogen.sh
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
which grpc_cpp_plugin
