#!/bin/bash
# SOTA Dual-GPU Aider Setup (V3 - UI Optimized)
# RTX 3090 (Architect) & RTX 3060 Ti (Janitor)
# Servers run in background; Aider runs in foreground for normal UI behavior.

SESSION="aider-servers"
ARCHITECT_MODEL="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF/Qwen3.6-27B-Q4_K_M-mtp.gguf"
EDITOR_MODEL="/home/jimshit/qwen3.5-9b/Qwen3.5-9B-UD-Q4_K_XL.gguf"
EMBED_MODEL="/opt/models/embeddings/nomic-embed-text-v1.5.f16.gguf"
LLAMA_SERVER="/home/jimshit/llama.cpp/build/bin/llama-server"

# 1. Cleanup
tmux kill-session -t $SESSION 2>/dev/null
tmux kill-session -t aider-sota 2>/dev/null
pkill -9 -f llama-server
pkill -9 -f litellm
fuser -k 8080/tcp 8081/tcp 8082/tcp 4000/tcp 2>/dev/null

# 2. Start Servers in a BACKGROUND tmux session
echo "Launching AI Stack (3090 + 3060ti) in background..."
tmux new-session -d -s $SESSION -n "3090-architect"

# Architect (3090)
tmux send-keys -t $SESSION:0 \
  "CUDA_VISIBLE_DEVICES=0 $LLAMA_SERVER \
   -m $ARCHITECT_MODEL \
   -c 32768 -fa on -t 6 -tb 6 \
   --poll 100 --prio 3 \
   --spec-type draft-mtp --spec-draft-n-max 3 \
   --reasoning on --port 8080 --n-gpu-layers 99" C-m

# Editor/Janitor (3060ti)
tmux new-window -t $SESSION -n "3060ti-editor"
tmux send-keys -t $SESSION:1 \
  "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
   -m $EDITOR_MODEL \
   -c 16384 -fa on -t 4 -tb 4 \
   --reasoning on --port 8081 --n-gpu-layers 99" C-m

# Embeddings (3060ti)
tmux new-window -t $SESSION -n "3060ti-embed"
tmux send-keys -t $SESSION:2 \
  "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
   --port 8082 \
   --model $EMBED_MODEL \
   --n-gpu-layers 99 --ctx-size 8192 --embedding" C-m

# Switchboard (LiteLLM)
tmux new-window -t $SESSION -n "proxy"
tmux send-keys -t $SESSION:3 \
  "litellm --config /home/jimshit/aider_litellm_config.yaml --port 4000" C-m

echo "Waiting for models to load (30s)..."
sleep 30

# 3. Launch Aider in the FOREGROUND (Current Window)
# This removes tmux from the Aider window, restoring normal scrolling/copying.
export OPENAI_API_KEY=local
export AIDER_OPENAI_API_BASE=http://127.0.0.1:4000
/home/jimshit/.local/bin/aider
