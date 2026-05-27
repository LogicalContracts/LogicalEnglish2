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
});
