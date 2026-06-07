#!/bin/bash
# SOTA Dual-GPU Aider Setup
# GPU 0 (3090): Qwen 3.6 27B (Architect) -> The Brain
# GPU 1 (3060ti): Qwen 3.5 9B (Editor)   -> The Hands

SESSION="aider-sota"
ARCHITECT_MODEL="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF/Qwen3.6-27B-Q4_K_M-mtp.gguf"
EDITOR_MODEL="/home/jimshit/qwen3.5-9b/Qwen3.5-9B-UD-Q4_K_XL.gguf"
LLAMA_SERVER="/home/jimshit/llama.cpp/build/bin/llama-server"

# Cleanup
tmux kill-session -t $SESSION 2>/dev/null
pkill -9 -f llama-server
pkill -9 -f litellm
# Clear ports 8080, 8081, and the LiteLLM port 4000
fuser -k 8080/tcp 8081/tcp 4000/tcp 2>/dev/null

tmux new-session -d -s $SESSION -n "architect"

# 1. Start Architect (3090) using llama-server
# Using MTP and Reasoning for maximum "smartness"
tmux send-keys -t $SESSION:0 \
  "CUDA_VISIBLE_DEVICES=0 $LLAMA_SERVER \
   -m $ARCHITECT_MODEL \
   -c 32768 -fa on -t 6 -tb 6 \
   --poll 100 --prio 3 \
   --spec-type draft-mtp --spec-draft-n-max 3 \
   --reasoning on --port 8080 --n-gpu-layers 99" C-m

# 2. Start Editor (3060 Ti) using llama-server
# Using Reasoning for smarter diff application
tmux new-window -t $SESSION -n "editor"
tmux send-keys -t $SESSION:1 \
  "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
   -m $EDITOR_MODEL \
   -c 16384 -fa on -t 4 -tb 4 \
   --reasoning on --port 8081 --n-gpu-layers 99" C-m

# 3. Start LiteLLM (Switchboard)
# LiteLLM only exists to let Aider talk to both llama-servers at once
tmux new-window -t $SESSION -n "proxy"
tmux send-keys -t $SESSION:2 \
  "litellm --config /home/jimshit/aider_litellm_config.yaml --port 4000" C-m

echo "Initializing llama-servers on 3090 and 3060ti..."
sleep 30

# 4. Launch Aider
tmux new-window -t $SESSION -n "aider"
tmux send-keys -t $SESSION:3 "export OPENAI_API_KEY=local" C-m
tmux send-keys -t $SESSION:3 "export AIDER_OPENAI_API_BASE=http://127.0.0.1:4000" C-m
tmux send-keys -t $SESSION:3 \
  "/home/jimshit/.local/bin/aider" --architect \
   --model openai/qwen-architect \
   --editor-model openai/qwen-editor \
   --edit-format diff \
   --suggest-shell-commands \
   --map-tokens 4096" C-m

tmux attach-session -t $SESSION:3
