#!/bin/bash
# SOTA Dual-GPU Aider Setup (V4)
# Uses the shared backend script to keep logic DRY.

# 1. Boot the shared SOTA Backend
/home/jimshit/start-backend-sota.sh

# 2. Launch Aider in the FOREGROUND (Normal UI)
export OPENAI_API_KEY=sk-local
export AIDER_OPENAI_API_BASE=http://127.0.0.1:8787/v1
/home/jimshit/.local/bin/aider
