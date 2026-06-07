"""
janitor_mcp.py

MCP server for "Context Janitor" tasks (Compression, Linting, Pruning).
Runs on the 3060 Ti sidecar to keep the 3090 Architect fast.
"""

import asyncio
import os
import sys
import json
import httpx
from pathlib import Path

# Add odysseus root to path for shared utilities if needed
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

server = Server("context-janitor")

# Port for the 3060 Ti Editor/Janitor llama-server
JANITOR_LLM_URL = "http://127.0.0.1:8081/v1/chat/completions"

@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="compress_context",
            description="Summarize and compress large blocks of text (logs, research, code) to save tokens. Uses the 3060 Ti sidecar.",
            inputSchema={
                "type": "object",
                "properties": {
                    "text": {"type": "string", "description": "The large block of text to compress."},
                    "ratio": {"type": "string", "enum": ["high", "medium", "low"], "default": "high", "description": "Compression intensity."}
                },
                "required": ["text"],
            },
        ),
        Tool(
            name="background_lint",
            description="Perform a syntax and logic check on a code block using the 3060 Ti sidecar. Prevents the 3090 from making dumb mistakes.",
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
        ratio = arguments.get("ratio", "high")
        
        prompt = f"Summarize the following technical content into a dense, high-fidelity technical summary. Keep all critical function names, logic paths, and constants. Target reduction: 90%.\n\nContent:\n{text}"
        
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
                res_json = response.json()
                summary = res_json['choices'][0]['message']['content']
                return [TextContent(type="text", text=f"COMPRESSED SUMMARY (90% reduction):\n\n{summary}")]
        except Exception as e:
            return [TextContent(type="text", text=f"Compression failed: {e}")]

    elif name == "background_lint":
        code = arguments.get("code", "")
        lang = arguments.get("language", "auto")
        
        prompt = f"ACT AS A SENIOR LINTER. Check this {lang} code for syntax errors, logical fallacies, and missing imports. Be extremely critical. If it is perfect, say 'Code is valid'.\n\nCode:\n{code}"
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    JANITOR_LLM_URL,
                    json={
                        "model": "qwen-editor",
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": 0.0
                    }
                )
                res_json = response.json()
                lint_report = res_json['choices'][0]['message']['content']
                return [TextContent(type="text", text=f"BACKGROUND LINT REPORT:\n\n{lint_report}")]
        except Exception as e:
            return [TextContent(type="text", text=f"Linting failed: {e}")]

    return [TextContent(type="text", text=f"Unknown tool: {name}")]

async def run():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(run())
