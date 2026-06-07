#!/bin/bash
# SOTA Dual-GPU Aider Setup
# GPU 0 (3090): Qwen 3.6 27B (Architect) -> The Brain
# GPU 1 (3060ti): Qwen 3.5 9B (Editor/Janitor) + Nomic Embed -> The Hands

SESSION="aider-sota"
ARCHITECT_MODEL="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF/Qwen3.6-27B-Q4_K_M-mtp.gguf"
EDITOR_MODEL="/home/jimshit/qwen3.5-9b/Qwen3.5-9B-UD-Q4_K_XL.gguf"
EMBED_MODEL="/opt/models/embeddings/nomic-embed-text-v1.5.f16.gguf"
LLAMA_SERVER="/home/jimshit/llama.cpp/build/bin/llama-server"

# Cleanup
tmux kill-session -t $SESSION 2>/dev/null
pkill -9 -f llama-server
pkill -9 -f litellm
# Clear ports
fuser -k 8080/tcp 8081/tcp 8082/tcp 4000/tcp 2>/dev/null

tmux new-session -d -s $SESSION -n "architect"
# Enable mouse support for scrolling and selection
tmux set -g mouse on
# Copy tmux selection to system clipboard automatically
tmux bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
tmux bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"

# 1. Start Architect (3090) using llama-server
tmux send-keys -t $SESSION:0 \
  "CUDA_VISIBLE_DEVICES=0 $LLAMA_SERVER \
   -m $ARCHITECT_MODEL \
   -c 32768 -fa on -t 6 -tb 6 \
   --poll 100 --prio 3 \
   --spec-type draft-mtp --spec-draft-n-max 3 \
   --reasoning on --port 8080 --n-gpu-layers 99" C-m

# 2. Start Editor/Janitor (3060 Ti) using llama-server
tmux new-window -t $SESSION -n "editor"
tmux send-keys -t $SESSION:1 \
  "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
   -m $EDITOR_MODEL \
   -c 16384 -fa on -t 4 -tb 4 \
   --reasoning on --port 8081 --n-gpu-layers 99" C-m

# 3. Start Embedding Server (3060 Ti)
tmux new-window -t $SESSION -n "embeddings"
tmux send-keys -t $SESSION:2 \
  "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
   --port 8082 \
   --model $EMBED_MODEL \
   --n-gpu-layers 99 --ctx-size 8192 --embedding" C-m

# 4. Start LiteLLM (Switchboard)
tmux new-window -t $SESSION -n "proxy"
tmux send-keys -t $SESSION:3 \
  "litellm --config /home/jimshit/aider_litellm_config.yaml --port 4000" C-m

echo "Initializing SOTA stack on 3090 and 3060ti..."
sleep 30

# 5. Launch Aider
tmux new-window -t $SESSION -n "aider"
tmux send-keys -t $SESSION:4 "export OPENAI_API_KEY=local" C-m
tmux send-keys -t $SESSION:4 "export AIDER_OPENAI_API_BASE=http://127.0.0.1:4000" C-m
tmux send-keys -t $SESSION:4 \
  "/home/jimshit/.local/bin/aider" C-m

tmux attach-session -t $SESSION:4
