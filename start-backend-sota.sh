#!/bin/bash
# SOTA Dual-GPU Backend (Headroom + LiteLLM + 3090 + 3060ti)
# Updated Port Range (8090+) to avoid conflicts with Odysseus/SearXNG

SESSION="aider-servers"
ARCHITECT_MODEL="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF/Qwen3.6-27B-Q4_K_M-mtp.gguf"
EDITOR_MODEL="/home/jimshit/qwen3.5-9b/Qwen3.5-9B-UD-Q4_K_XL.gguf"
EMBED_MODEL="/opt/models/embeddings/nomic-embed-text-v1.5.f16.gguf"
LLAMA_SERVER="/home/jimshit/llama.cpp/build/bin/llama-server"
HEADROOM_BIN="/home/jimshit/odysseus/venv/bin/headroom"

# 1. Cleanup
echo "Cleaning up old AI sessions..."
tmux kill-session -t $SESSION 2>/dev/null
pkill -9 -f llama-server
pkill -9 -f litellm
pkill -9 -f headroom
fuser -k -9 /dev/nvidia0 /dev/nvidia1 8090/tcp 8091/tcp 8092/tcp 4000/tcp 8787/tcp 2>/dev/null || true
sleep 2

# 2. Start Servers in a BACKGROUND tmux session
if ! (echo > /dev/tcp/localhost/8787) >/dev/null 2>&1; then
    echo "Launching SOTA Stack (3090 Brain + 3060ti Janitor) in background..."
    tmux new-session -d -s $SESSION -n "3090-architect"

    # Architect (3090)
    tmux send-keys -t $SESSION:0 \
      "CUDA_VISIBLE_DEVICES=0 $LLAMA_SERVER \
       -m $ARCHITECT_MODEL \
       -c 65536 -fa on -t 6 -tb 6 \
       --cache-type-k q8_0 --cache-type-v q8_0 \
       --chat-template-file /home/jimshit/llama.cpp/models/templates/Qwen-Qwen2.5-7B-Instruct.jinja \
       --poll 100 --prio 3 \
       --spec-type draft-mtp --spec-draft-n-max 3 \
       --reasoning on --port 8090 --n-gpu-layers 99" C-m

    # Editor/Janitor (3060ti)
    tmux new-window -t $SESSION -n "3060ti-editor"
    tmux send-keys -t $SESSION:1 \
      "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
       -m $EDITOR_MODEL \
       -c 16384 -fa on -t 4 -tb 4 \
       --chat-template-file /home/jimshit/llama.cpp/models/templates/Qwen-Qwen2.5-7B-Instruct.jinja \
       --reasoning on --port 8091 --n-gpu-layers 99" C-m

    # Embeddings (3060ti)
    tmux new-window -t $SESSION -n "3060ti-embed"
    tmux send-keys -t $SESSION:2 \
      "CUDA_VISIBLE_DEVICES=1 $LLAMA_SERVER \
       --host 0.0.0.0 --port 8092 \
       --model $EMBED_MODEL \
       --n-gpu-layers 99 --ctx-size 8192 --embedding" C-m

    # Switchboard (LiteLLM)
    tmux new-window -t $SESSION -n "litellm"
    tmux send-keys -t $SESSION:3 \
      "litellm --config /home/jimshit/aider_litellm_config.yaml --port 4000" C-m

    # Headroom Automatic Janitor Proxy
    tmux new-window -t $SESSION -n "headroom"
    tmux send-keys -t $SESSION:4 \
      "env -u OPENAI_API_KEY CUDA_VISIBLE_DEVICES=1 $HEADROOM_BIN proxy \
       --host 0.0.0.0 --port 8787 \
       --backend anyllm \
       --anyllm-provider openai \
       --openai-api-url http://127.0.0.1:4000/v1 \
       --code-aware --learn --memory" C-m

    echo "Initializing AI models (Wait 30s)..."
    sleep 30
else
    echo "SOTA Backend is already running on port 8787."
fi
