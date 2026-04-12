import { handler } from '../src/handlers/health';
import { APIGatewayProxyEvent, Context } from 'aws-lambda';

const mockEvent = {} as APIGatewayProxyEvent;
const mockContext = {} as Context;

test('health handler returns 200 with status ok', async () => {
  const result = await handler(mockEvent, mockContext, () => {});
  expect(result).toBeDefined();
  if (result) {
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body);
    expect(body.status).toBe('ok');
    expect(body.timestamp).toBeDefined();
  }
});
