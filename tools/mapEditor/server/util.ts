import type { IncomingMessage, ServerResponse } from 'node:http';

export function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(body));
}

/** AI 가 스스로 복구할 수 있도록 error + hint 를 함께 보낸다. */
export function sendError(res: ServerResponse, status: number, error: string, hint?: string): void {
  sendJson(res, status, hint ? { error, hint } : { error });
}

export function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on('data', (c: Buffer) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    req.on('error', reject);
  });
}

export async function readJsonBody(req: IncomingMessage): Promise<unknown> {
  const text = await readBody(req);
  if (!text.trim()) return {};
  return JSON.parse(text);
}
