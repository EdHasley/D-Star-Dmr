CXX ?= g++
CC ?= gcc
CXXFLAGS ?= -O2 -std=c++11 -Wall -Wextra
CFLAGS ?= -O2
CPPFLAGS += -Ivendor -Ivendor/mbe
C_SOURCES := $(wildcard vendor/mbe/*.c)
CPP_SOURCES := $(wildcard vendor/imbe_vocoder/*.cc) vendor/mbe/mbevocoder.cpp
OBJECTS := $(C_SOURCES:.c=.o) $(CPP_SOURCES:.cc=.o)
OBJECTS := $(OBJECTS:.cpp=.o)

all: software-ambed codec-check
software-ambed: server.o $(OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -lm -o $@
codec-check: codec-check.o $(OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -lm -o $@
test: all
	./codec-check
	python3 tests/test_protocol.py
clean:
	rm -f software-ambed codec-check server.o codec-check.o $(OBJECTS)
.PHONY: all test clean
