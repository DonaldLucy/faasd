CXX = g++
CXXFLAGS = -std=c++17 -pthread -Wall -O2

# 1. Common Files (The Logic)
# junctiond.cpp is included here as it contains the logic needed by test.cpp
COMMON_SRCS = junctiond.cpp
COMMON_OBJS = $(COMMON_SRCS:.cpp=.o)

# 2. Target: Test (test.cpp)
TEST_TARGET = test
TEST_SRCS = test.cpp
TEST_OBJS = $(TEST_SRCS:.cpp=.o)

# We remove the SERVER_TARGET definitions.

# Default: Build only the test executable
all: $(TEST_TARGET)

# --- Build Rules ---

# Build the Test Binary
$(TEST_TARGET): $(TEST_OBJS) $(COMMON_OBJS)
    $(CXX) $(CXXFLAGS) -o $@ $(TEST_OBJS) $(COMMON_OBJS)

# We remove the rule for the server target.

# --- Helper Commands ---

# Convenience command to build AND run the test
run: $(TEST_TARGET)
    @echo ">>> Starting Test..."
    ./$(TEST_TARGET)

# Compile .cpp files to .o files
%.o: %.cpp
    $(CXX) $(CXXFLAGS) -c $< -o $@

# Clean only the files relevant to the test
clean:
    rm -f *.o $(TEST_TARGET)
# We remove the cleanup for the 'server' target.