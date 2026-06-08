#!/usr/bin/env bash
# Hermes Iteration 4: SOTA Dual-GPU Backend

set -euo pipefail

# 1. Boot the shared SOTA Backend
/home/jimshit/start-backend-sota.sh

# 2. Start Hermes Desktop
echo "Starting Hermes Desktop..."
export HERMES_CONFIG="/home/jimshit/Documents/iteration 4/hermes_config_iter4.yaml"
cd /home/jimshit/.hermes/hermes-agent && uv run hermes desktop --skip-build
