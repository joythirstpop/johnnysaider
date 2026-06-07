# ODYSSEUS CONVENTIONS & MANDATES

You are working on the **Odysseus** project. You must strictly adhere to the following rules at all times. Do not ask for permission to follow these rules; execute them autonomously.

## 1. Architectural Standards
- **Framework:** This is a FastAPI backend with asynchronous Python (`async`/`await`). Do not write synchronous blocking code in route handlers.
- **Dependencies:** Use `httpx` for all network requests. Never use `requests`. Use `pydantic` v2 for all data validation.
- **Typing:** Strict Python type hints are mandatory for all function signatures and returns (e.g., `def get_user(id: int) -> dict:`).

## 2. Agentic Workflow (The "Self-Healing" Loop)
- **Zero Placeholders:** Never use placeholders like `// implement logic here` or `pass`. Write complete, production-ready code.
- **Autonomous Testing:** You are expected to run the test suite (`pytest`) autonomously if you are unsure if your code works.
- **Self-Correction:** If a test or linter fails, DO NOT wait for the user to tell you what to do. Read the error trace, identify the bug, and write the fix immediately.

## 3. Communication
- **No Yapping:** Output only the raw technical analysis, the architectural plan, and the code. Do not use conversational filler, pleasantries, or apologies.
- **Plan First:** Always provide a brief bulleted plan of the files you intend to change before making edits.

## 4. MCP Tools & Hardware
- **3060 Ti Sidecar:** You have access to the `compress_context` and `background_lint` tools on the secondary GPU. USE THEM proactively to keep your context window lean and your code error-free.
