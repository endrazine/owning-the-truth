# Makefile for undecidable.c
# Hardened, portable build.  Requires libgmp-dev.
#
# Usage:
#   make
#   ./undecidable "x1^2 - x2^2 - x3^2 - 1"   # halts at (1,0,0)
#   ./undecidable "x1^2 + 1"                   # runs forever

CC      ?= cc
CFLAGS  := -std=c17 -O2 -Wall -Wextra \
           -fPIE -fstack-protector-all \
           -D_FORTIFY_SOURCE=2
LDFLAGS := -Wl,-z,relro -Wl,-z,now -pie
LIBS    := -lgmp

# Arch-specific hardening (detected at build time)
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
  CFLAGS += -fcf-protection=full
endif

TARGET  := undecidable
SRC     := undecidable.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LIBS)

clean:
	rm -f $(TARGET)
