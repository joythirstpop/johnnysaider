#!/bin/bash
# Aider Recovery & Setup Script
# Automatically restores the optimized Qwen 3.6 27B MTP environment

set -e

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MODEL_DIR="/home/jimshit/Qwen3.6-27B-Q4_K_M-MTP-GGUF"
MODEL_FILE="$MODEL_DIR/Qwen3.6-27B-Q4_K_M-mtp.gguf"
LLAMA_DIR="/home/jimshit/llama.cpp"

echo "--- Starting Aider Setup/Restore ---"

# 1. Install/Update Aider
if ! command -v aider &> /dev/null; then
    echo "Installing Aider..."
    pipx install aider-chat || pip install --user aider-chat
else
    echo "Aider already installed."
fi

# 2. Ensure llama.cpp is built
if [ ! -f "$LLAMA_DIR/build/bin/llama-server" ]; then
    echo "llama-server not found. Building llama.cpp..."
    if [ ! -d "$LLAMA_DIR" ]; then
        git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
    fi
    cd "$LLAMA_DIR"
    cmake -B build -DGGML_CUDA=ON
    cmake --build build --config Release -j $(nproc)
    cd "$REPO_DIR"
else
    echo "llama-server verified."
fi

# 3. Ensure Model is downloaded
if [ ! -f "$MODEL_FILE" ]; then
    echo "Model missing. Downloading Qwen 3.6 27B MTP (17GB)..."
    mkdir -p "$MODEL_DIR"
    # Using 'hf' as verified in the environment
    hf download froggeric/Qwen3.6-27B-MTP-GGUF Qwen3.6-27B-Q4_K_M-mtp.gguf --local-dir "$MODEL_DIR" --local-dir-use-symlinks False
else
    echo "Model file verified."
fi

# 4. Deploy Scripts
echo "Deploying optimized scripts..."
cp "$REPO_DIR/start-agent.sh" "/home/jimshit/start-agent.sh"
cp "$REPO_DIR/start-aider-optimized.sh" "/home/jimshit/start-aider-optimized.sh"
chmod +x /home/jimshit/start-agent.sh
chmod +x /home/jimshit/start-aider-optimized.sh

# 5. Deploy Desktop Shortcut
echo "Deploying desktop shortcut..."
cp "$REPO_DIR/aider.desktop" "/home/jimshit/Desktop/aider.desktop"
chmod +x /home/jimshit/Desktop/aider.desktop

echo "--- Setup Complete! ---"
echo "You can now run Aider via the desktop icon or ./start-agent.sh"
