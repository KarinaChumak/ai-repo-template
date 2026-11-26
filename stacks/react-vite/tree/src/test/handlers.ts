import type { RequestHandler } from 'msw';

// The default API responses for every test. A test that needs another answer overrides one with
// server.use(http.get('/api/...', () => HttpResponse.json(...))).
export const handlers: RequestHandler[] = [];
