# Logical English MCP Server Settings

This directory contains example configuration files for using the Logical English MCP server with various LLM clients.

## Claude Desktop

### Option 1: STDIO (Recommended for local use)
Add this to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "logical-english": {
      "command": "/Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl",
      "args": [
        "-g",
        "use_module(llm/mcp), mcp:handle_mcp_stdio.",
        "llm/mcp.pl"
      ]
    }
  }
}
```

### Option 2: HTTP (via classic_web_api.pl)
Add this to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "logical-english": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "http://localhost:3050/mcp"
      ]
    }
  }
}
```
Make sure the server is running:
```bash
swipl -g "use_module(classic_web_api), start_api_server(3050)" classic_web_api.pl
```
(Note: If the process exits immediately, add `, thread_get_message(_)` to the goal to keep it alive.)

## Claude Code

You can use the MCP server with Claude Code by running:
```bash
claude --mcp "swipl -g 'use_module(classic_web_api), start_api_server(3050), thread_get_message(_).' classic_web_api.pl"
```

Alternatively, add it to your Claude Code config if supported.

## ChatGPT Pro (Actions)

1. Create a new Custom GPT.
2. Go to "Configure" -> "Create new action".
3. Copy the contents of `chatgpt_openapi.yaml` into the Schema field.
4. Set the server URL to your publicly accessible server address where the API server is running (default port 3050).
5. Note: You may need to use a tool like `ngrok` to expose your local server to the internet.

## Starting the Server Manually

To start the server on port 3050:
```bash
swipl -g "use_module(classic_web_api), start_api_server(3050)" classic_web_api.pl
```
