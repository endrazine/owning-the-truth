#!/bin/bash

#
# Display lean version
#
LEAN_PATH="$PWD${LEAN_PATH:+:$LEAN_PATH}" lake env lean --version

#
# Verify certificate of PNP.olean using leanchecker.
# Should print "exit=0" on success.
#

LEAN_PATH="$PWD${LEAN_PATH:+:$LEAN_PATH}" lake env leanchecker --fresh PNP
echo "exit=$?"


LEAN_PATH="$PWD${LEAN_PATH:+:$LEAN_PATH}" lake env lean AuditPNP.lean

