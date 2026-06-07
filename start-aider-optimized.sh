#!/bin/bash
# Simplified Aider Launch - ONLY RTX 3090 (GPU 0)
# No 3060 Ti, No separate embedding server for now.

SESSION="aider-3090"
MODEL_PATH="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF/Qwen3.6-27B-Q4_K_M-mtp.gguf"
LLAMA_SERVER="/home/jimshit/llama.cpp/build/bin/llama-server"

# Cleanup
tmux kill-session -t $SESSION 2>/dev/null
pkill -9 -f llama-server
# Ensure port 8080 is definitely clear
fuser -k 8080/tcp 2>/dev/null

tmux new-session -d -s $SESSION -n "qwen-server"

# Start Qwen Server on GPU 0
# Physical cores: 6 (-t 6 -tb 6)
# Updated reasoning flag to avoid deprecation warning
tmux send-keys -t $SESSION:0 \
  "CUDA_VISIBLE_DEVICES=0 $LLAMA_SERVER \
   -m $MODEL_PATH \
   -c 32768 \
   -fa on \
   -t 6 -tb 6 \
   --poll 100 --prio 3 \
   --spec-type draft-mtp --spec-draft-n-max 3 \
   --temp 0.6 --top-p 0.95 --top-k 20 --repeat-penalty 1.0 \
   --reasoning on \
   --port 8080 \
   --n-gpu-layers 99" C-m

echo "Starting server on RTX 3090... (Wait 10s)"
sleep 10

# Launch Aider
tmux new-window -t $SESSION -n "aider"
tmux send-keys -t $SESSION:1 "export OPENAI_API_KEY=local" C-m
tmux send-keys -t $SESSION:1 "export AIDER_OPENAI_API_BASE=http://127.0.0.1:8080/v1" C-m
tmux send-keys -t $SESSION:1 "/home/jimshit/.local/bin/aider --model openai/qwen-3.6-27b-mtp" C-m

tmux attach-session -t $SESSION:1
