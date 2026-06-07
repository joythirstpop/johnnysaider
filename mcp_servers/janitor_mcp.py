"""
janitor_mcp.py

SOTA Context Janitor for Aider.
Uses Headroom-AI (Kompress-base) and Qwen-Editor (3060ti).
"""

import asyncio
import os
import sys
import json
import httpx
import torch
from pathlib import Path

# Add odysseus root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Try to import Headroom for high-fidelity compression
try:
    from headroom import Headroom
    _has_headroom = True
except ImportError:
    _has_headroom = False

server = Server("context-janitor")

# Port for the 3060 Ti Editor/Janitor llama-server
JANITOR_LLM_URL = "http://127.0.0.1:8081/v1/chat/completions"

# Global Headroom instance (Lazy-init)
_headroom_instance = None

def get_headroom():
    global _headroom_instance
    if _headroom_instance is None and _has_headroom:
        # Load Kompress-base onto GPU 1 (3060ti)
        # We use CUDA_VISIBLE_DEVICES=1 in the env usually, but we can be explicit
        device = "cuda" if torch.cuda.is_available() else "cpu"
        # If dual-gpu, ensure it stays on the sidecar
        _headroom_instance = Headroom(model_name="chopratejas/kompress-base", device=device)
    return _headroom_instance

@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="compress_context",
            description="Mathematically compress tool outputs, logs, or RAG chunks by 60-95% using the 3060 Ti sidecar. Preserves data integrity for the Architect.",
            inputSchema={
                "type": "object",
                "properties": {
                    "text": {"type": "string", "description": "The text or JSON to compress."},
                    "mode": {"type": "string", "enum": ["text", "json", "code"], "default": "text", "description": "Type of content."}
                },
                "required": ["text"],
            },
        ),
        Tool(
            name="background_lint",
            description="Perform a deep syntax and logic check on code using the 3060 Ti sidecar.",
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {"type": "string", "description": "The code block to verify."},
                    "language": {"type": "string", "description": "The programming language."}
                },
                "required": ["code"],
            },
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "compress_context":
        text = arguments.get("text", "")
        mode = arguments.get("mode", "text")
        
        hr = get_headroom()
        if hr:
            try:
                # Use SOTA Headroom compression
                compressed_text = hr.compress(text)
                return [TextContent(type="text", text=f"ULTIMATE COMPRESSION APPLIED (Headroom):\n\n{compressed_text}")]
            except Exception as e:
                return [TextContent(type="text", text=f"Headroom failed, falling back to LLM summary: {e}")]
        
        # Fallback to 9B LLM summary if Headroom isn't ready
        prompt = f"CRITICAL TASK: Summarize this technical trace. Keep ALL identifiers and logic. Shrink by 80%.\n\n{text}"
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    JANITOR_LLM_URL,
                    json={
                        "model": "qwen-editor",
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": 0.1
                    }
                )
                summary = response.json()['choices'][0]['message']['content']
                return [TextContent(type="text", text=f"9B SUMMARY COMPRESSION:\n\n{summary}")]
        except Exception as e:
            return [TextContent(type="text", text=f"All compression failed: {e}")]

    elif name == "background_lint":
        code = arguments.get("code", "")
        lang = arguments.get("language", "auto")
        prompt = f"ACT AS A SENIOR LINTER. Check this {lang} code. If perfect, say 'Valid'. Otherwise, list bugs.\n\n{code}"
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(JANITOR_LLM_URL, json={
                    "model": "qwen-editor",
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.0
                })
                return [TextContent(type="text", text=f"LINT REPORT:\n\n{response.json()['choices'][0]['message']['content']}")]
        except Exception as e:
            return [TextContent(type="text", text=f"Lint failed: {e}")]

    return [TextContent(type="text", text=f"Unknown tool: {name}")]

async def run():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(run())
