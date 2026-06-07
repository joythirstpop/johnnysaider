#!/bin/bash
# SOTA Dual-GPU Aider Setup (V4 - Automatic Janitor Tier)
# RTX 3090 (Architect) & RTX 3060 Ti (Janitor)
# Servers run in background; Aider runs in foreground.
# Primary Proxy: Headroom-AI (Automatic Context Optimization)

SESSION="aider-servers"
ARCHITECT_MODEL="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF/Qwen3.6-27B-Q4_K_M-mtp.gguf"
EDITOR_MODEL="/home/jimshit/qwen3.5-9b/Qwen3.5-9B-UD-Q4_K_XL.gguf"
EMBED_MODEL="/opt/models/embeddings/nomic-embed-text-v1.5.f16.gguf"
LLAMA_SERVER="/home/jimshit/llama.cpp/build/bin/llama-server"
HEADROOM_BIN="/home/jimshit/odysseus/venv/bin/headroom"

# 1. Cleanup
echo "Cleaning up old sessions..."
tmux kill-session -t $SESSION 2>/dev/null
pkill -9 -f llama-server
pkill -9 -f litellm
pkill -9 -f headroom
fuser -k 8080/tcp 8081/tcp 8082/tcp 4000/tcp 8787/tcp 2>/dev/null

# 2. Start Servers in a BACKGROUND tmux session
echo "Launching SOTA Stack (3090 Brain + 3060ti Janitor) in background..."
tmux new-session -d -s $SESSION -n "3090-architect"

# Architect (3090)
# Scaled to 64k context using q8_0 cache quantization (SOTA efficiency)
tmux send-keys -t $SESSION:0 \
  "CUDA_VISIBLE_DEVICES=0 $LLAMA_SERVER \
   -m $ARCHITECT_MODEL \
   -c 65536 -fa on -t 6 -tb 6 \
   --cache-type-k q8_0 --cache-type-v q8_0 \
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

# Switchboard (LiteLLM) - Routes qwen-architect and qwen-editor
tmux new-window -t $SESSION -n "litellm"
tmux send-keys -t $SESSION:3 \
  "litellm --config /home/jimshit/aider_litellm_config.yaml --port 4000" C-m

# 3. Start Headroom Automatic Janitor Proxy
# This wraps LiteLLM and automatically crushes context on the 3060ti.
tmux new-window -t $SESSION -n "headroom"
tmux send-keys -t $SESSION:4 \
  "CUDA_VISIBLE_DEVICES=1 $HEADROOM_BIN proxy \
   --port 8787 \
   --backend litellm-openai \
   --openai-api-url http://127.0.0.1:4000/v1 \
   --code-aware --learn --memory" C-m

echo "Initializing models (Wait 30s)..."
sleep 30

# 4. Launch Aider in the FOREGROUND (Normal UI)
# Pointing Aider to Headroom (8787) instead of LiteLLM (4000)
export OPENAI_API_KEY=sk-local
export AIDER_OPENAI_API_BASE=http://127.0.0.1:8787/v1
/home/jimshit/.local/bin/aider
