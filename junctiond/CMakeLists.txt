cmake_minimum_required(VERSION 3.14)
project(junctiond)

set(CMAKE_CXX_STANDARD 17)

# --- Dependencies ---
find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)
find_package(absl REQUIRED) 

message(STATUS "Using protobuf ${Protobuf_VERSION}")
message(STATUS "Using gRPC")

include_directories(
    ${Protobuf_INCLUDE_DIRS}
    ${GRPC_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/gen
)

# --- Protobuf / gRPC generated files ---
set(PROTO_SRC
    gen/junctiond.pb.cc
    gen/junctiond.grpc.pb.cc
)

set(PROTO_HDRS
    gen/junctiond.pb.h
    gen/junctiond.grpc.pb.h
)

# --- Your code ---
set(SOURCES
    junctiond.cpp
    junctiond_server.cpp
    ${PROTO_SRC}
)

add_executable(junctiond ${SOURCES})

# --- Link libraries ---
target_link_libraries(junctiond
    gRPC::grpc++
    protobuf::libprotobuf
)

