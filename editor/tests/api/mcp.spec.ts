import { test, expect } from '@playwright/test';

test.describe('MCP and REST API Endpoints', () => {
  const baseURL = 'http://localhost:3000';

  test('GET /list_examples should return list of examples', async ({ request }) => {
    const response = await request.get(`${baseURL}/list_examples`);
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(Array.isArray(data.examples)).toBeTruthy();
    const exampleNames = data.examples.map((e: any) => e.name || e);
    expect(exampleNames).toContain('citizenship');
  });

  test('POST /example_details should return details for citizenship', async ({ request }) => {
    const response = await request.post(`${baseURL}/example_details`, {
      data: { example_name: 'citizenship' }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    // Note: program_text is not returned by get_example_details tool, it returns examples, kb, queries, scenarios, templates
    expect(data.kb).toBe('citizenship');
    const scenarioNames = data.scenarios.map((s: any) => s.name || s);
    expect(scenarioNames).toContain('alice');
    expect(data.queries.some((q: any) => q.name === 'one')).toBeTruthy();
  });

  test('POST /verify should verify a valid program', async ({ request }) => {
    // Fetch program text first using the /examples endpoint
    const detailsRes = await request.post(`${baseURL}/leapi`, {
      data: { token: 'myToken123', operation: 'examples', file: 'citizenship' }
    });
    const details = await detailsRes.json();
    
    const response = await request.post(`${baseURL}/verify`, {
      data: { program_text: details.document }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(Array.isArray(data.issues)).toBeTruthy();
  });

  test('POST /query should execute a query on citizenship', async ({ request }) => {
    const detailsRes = await request.post(`${baseURL}/leapi`, {
      data: { token: 'myToken123', operation: 'examples', file: 'citizenship' }
    });
    const details = await detailsRes.json();

    const response = await request.post(`${baseURL}/query`, {
      data: {
        program_text: details.document,
        scenario_name: 'alice',
        query: 'one'
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    if (data.error) {
      console.error('Query error:', data.error);
    }
    expect(Array.isArray(data.results)).toBeTruthy();
    expect(data.results.length).toBeGreaterThan(0);
    expect(data.results[0].answer).toContain('John acquires British citizenship');
  });

  test('POST /mcp should handle tools/list', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'tools/list',
        id: 1
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.jsonrpc).toBe('2.0');
    expect(data.id).toBe(1);
    expect(Array.isArray(data.result.tools)).toBeTruthy();
    const toolNames = data.result.tools.map((t: any) => t.name);
    expect(toolNames).toContain('list_examples');
    expect(toolNames).toContain('get_example_details');
    expect(toolNames).toContain('verify');
    expect(toolNames).toContain('query');
  });

  test('POST /mcp should handle tools/call for get_example_details', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: 'get_example_details',
          arguments: { example_name: 'citizenship' }
        },
        id: 2
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.jsonrpc).toBe('2.0');
    expect(data.id).toBe(2);
    expect(Array.isArray(data.result.content)).toBeTruthy();
    expect(data.result.content[0].type).toBe('text');
    expect(data.result.content[0].text).toContain('alice');
  });

  test('POST /mcp should handle initialize', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: { jsonrpc: '2.0', method: 'initialize', id: 10 }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.jsonrpc).toBe('2.0');
    expect(data.id).toBe(10);
    expect(data.result.protocolVersion).toBe('2024-11-05');
    expect(data.result.serverInfo.name).toBe('Logical English MCP Server');
    // Server advertises tools, prompts and resources capabilities.
    expect(data.result.capabilities).toHaveProperty('tools');
    expect(data.result.capabilities).toHaveProperty('prompts');
    expect(data.result.capabilities).toHaveProperty('resources');
  });

  test('POST /mcp should handle resources/list', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: { jsonrpc: '2.0', method: 'resources/list', id: 11 }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(11);
    expect(Array.isArray(data.result.resources)).toBeTruthy();
    const uris = data.result.resources.map((r: any) => r.uri);
    expect(uris).toContain('le://docs/syntax');
  });

  test('POST /mcp should handle resources/read for the syntax doc', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'resources/read',
        params: { uri: 'le://docs/syntax' },
        id: 12
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(12);
    expect(Array.isArray(data.result.contents)).toBeTruthy();
    expect(data.result.contents[0].uri).toBe('le://docs/syntax');
    expect(data.result.contents[0].mimeType).toBe('text/markdown');
    expect(typeof data.result.contents[0].text).toBe('string');
    expect(data.result.contents[0].text.length).toBeGreaterThan(0);
  });

  test('POST /mcp should return Method not found for an unknown resource uri', async ({ request }) => {
    // resources/read fails for an unknown uri, which surfaces as JSON-RPC -32601.
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'resources/read',
        params: { uri: 'le://docs/does-not-exist' },
        id: 13
      }
    });
    expect(response.status()).toBe(404);
    const data = await response.json();
    expect(data.id).toBe(13);
    expect(data.error.code).toBe(-32601);
  });

  test('POST /mcp should handle prompts/list', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: { jsonrpc: '2.0', method: 'prompts/list', id: 14 }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(14);
    expect(Array.isArray(data.result.prompts)).toBeTruthy();
    const names = data.result.prompts.map((p: any) => p.name);
    expect(names).toContain('use_logical_english');
    expect(names).toContain('massage_query');
    expect(names).toContain('massage_facts');
  });

  test('POST /mcp should handle prompts/get for use_logical_english', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'prompts/get',
        params: {
          name: 'use_logical_english',
          arguments: { example_name: 'citizenship' }
        },
        id: 15
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(15);
    expect(Array.isArray(data.result.messages)).toBeTruthy();
    expect(data.result.messages[0].content.type).toBe('text');
    // The generated prompt is parameterised with the requested example name.
    expect(data.result.messages[0].content.text).toContain('citizenship');
  });

  test('POST /mcp should handle tools/call for list_examples', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: { name: 'list_examples', arguments: {} },
        id: 16
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(16);
    expect(Array.isArray(data.result.content)).toBeTruthy();
    expect(data.result.content[0].type).toBe('text');
    expect(data.result.content[0].text).toContain('citizenship');
  });

  test('POST /mcp should handle tools/call for query', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: 'query',
          arguments: {
            example_name: 'citizenship',
            scenario_name: 'alice',
            query: 'one'
          }
        },
        id: 17
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(17);
    expect(Array.isArray(data.result.content)).toBeTruthy();
    expect(data.result.content[0].type).toBe('text');
    expect(data.result.content[0].text).toContain('John acquires British citizenship');
  });

  test('POST /mcp should handle tools/call for verify', async ({ request }) => {
    const detailsRes = await request.post(`${baseURL}/leapi`, {
      data: { token: 'myToken123', operation: 'examples', file: 'citizenship' }
    });
    const details = await detailsRes.json();

    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: 'verify',
          arguments: { program_text: details.document }
        },
        id: 18
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(18);
    expect(Array.isArray(data.result.content)).toBeTruthy();
    expect(data.result.content[0].type).toBe('text');
    // verify returns a JSON-serialised result containing an "issues" array.
    expect(data.result.content[0].text).toContain('issues');
  });

  test('POST /mcp should report an error for an unknown tool', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: {
        jsonrpc: '2.0',
        method: 'tools/call',
        params: { name: 'no_such_tool', arguments: {} },
        id: 19
      }
    });
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.id).toBe(19);
    expect(data.result.isError).toBe(true);
    expect(data.result.content[0].text).toContain('Unknown tool');
  });

  test('POST /mcp should return Method not found for an unknown method', async ({ request }) => {
    const response = await request.post(`${baseURL}/mcp`, {
      data: { jsonrpc: '2.0', method: 'does/not/exist', id: 20 }
    });
    expect(response.status()).toBe(404);
    const data = await response.json();
    expect(data.id).toBe(20);
    expect(data.error.code).toBe(-32601);
  });
});
