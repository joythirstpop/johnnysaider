"""
search_server.py

MCP server exposing Odysseus's comprehensive web search capabilities to Aider.
"""

import asyncio
import os
import sys
import json
from pathlib import Path

# Add odysseus root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Import the Odysseus search orchestrator
try:
    from services.search.core import comprehensive_web_search
except ImportError:
    # Try alternate pathing if needed
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
    from services.search.core import comprehensive_web_search

server = Server("odysseus-search")

@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="web_search",
            description="Perform a comprehensive web search using SearXNG and other providers. Returns ranked results with content summaries.",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string", 
                        "description": "The search query to perform."
                    },
                    "max_pages": {
                        "type": "integer",
                        "description": "Maximum number of pages to fetch and analyze.",
                        "default": 3
                    }
                },
                "required": ["query"],
            },
        )
    ]

@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name != "web_search":
        return [TextContent(type="text", text=f"Unknown tool: {name}")]

    query = arguments.get("query")
    max_pages = arguments.get("max_pages", 3)

    if not query:
        return [TextContent(type="text", text="Error: Query is required.")]

    try:
        # Run the synchronous search in a thread to not block the event loop
        loop = asyncio.get_event_loop()
        results = await loop.run_in_executor(
            None, 
            lambda: comprehensive_web_search(query=query, max_pages=max_pages)
        )
        
        # Format results for the LLM
        if not results:
            return [TextContent(type="text", text=f"No results found for query: {query}")]
            
        output = [f"Search results for: {query}\n"]
        for i, res in enumerate(results, 1):
            title = res.get('title', 'No Title')
            url = res.get('url', 'No URL')
            snippet = res.get('snippet', res.get('content', ''))
            output.append(f"{i}. {title}")
            output.append(f"   URL: {url}")
            output.append(f"   Snippet: {snippet[:500]}...") # Limit snippet length
            output.append("")

        return [TextContent(type="text", text="\n".join(output))]
        
    except Exception as e:
        return [TextContent(type="text", text=f"Search failed with error: {str(e)}")]

async def run():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(run())
