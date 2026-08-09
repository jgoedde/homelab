#!/usr/bin/env bash
set -euo pipefail

BEET="/home/julian/.local/bin/beet"

"$BEET" lastgenre --items genres:=Music --no-keep-existing --force
