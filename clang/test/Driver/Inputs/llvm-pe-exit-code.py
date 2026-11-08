"""Runs a command with its output passed through, then prints its exit code (lit's shell cannot), as an
unsigned 32-bit value in hexadecimal for Windows exception codes."""

import subprocess
import sys

code = subprocess.call(sys.argv[1:])
print("exit code %d (0x%08X)" % (code, code & 0xFFFFFFFF), flush=True)
