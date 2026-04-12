import { handler } from '../src/handlers/reservations';
import { APIGatewayProxyEvent, Context } from 'aws-lambda';

jest.mock('../src/lib/dynamodb', () => ({
  ddb: {
    send: jest.fn(),
  },
  TABLE_NAME: 'test-table',
}));

import { ddb } from '../src/lib/dynamodb';
const mockSend = ddb.send as jest.Mock;

const ctx = {} as Context;

function makeEvent(overrides: Partial<APIGatewayProxyEvent>): APIGatewayProxyEvent {
  return {
    httpMethod: 'GET',
    path: '/reservations',
    pathParameters: null,
    queryStringParameters: null,
    headers: {},
    multiValueHeaders: {},
    body: null,
    isBase64Encoded: false,
    resource: '',
    stageVariables: null,
    requestContext: {} as any,
    multiValueQueryStringParameters: null,
    ...overrides,
  };
}

beforeEach(() => mockSend.mockReset());

test('GET /reservations returns list', async () => {
  mockSend.mockResolvedValue({ Items: [{ id: '1', guestName: 'Alice' }] });
  const result = await handler(makeEvent({ httpMethod: 'GET' }), ctx, () => {});
  expect(result?.statusCode).toBe(200);
  const body = JSON.parse(result!.body);
  expect(Array.isArray(body)).toBe(true);
});

test('GET /reservations/:id returns 404 when not found', async () => {
  mockSend.mockResolvedValue({ Item: undefined });
  const result = await handler(makeEvent({ httpMethod: 'GET', pathParameters: { id: 'missing' } }), ctx, () => {});
  expect(result?.statusCode).toBe(404);
});

test('POST /reservations creates a reservation', async () => {
  mockSend.mockResolvedValue({});
  const body = JSON.stringify({ guestName: 'Bob', guestEmail: 'bob@example.com', checkIn: '2024-06-01', checkOut: '2024-06-05', roomType: 'deluxe' });
  const result = await handler(makeEvent({ httpMethod: 'POST', body }), ctx, () => {});
  expect(result?.statusCode).toBe(201);
  const parsed = JSON.parse(result!.body);
  expect(parsed.guestName).toBe('Bob');
  expect(parsed.id).toBeDefined();
});

test('DELETE /reservations/:id deletes a reservation', async () => {
  mockSend.mockResolvedValue({});
  const result = await handler(makeEvent({ httpMethod: 'DELETE', pathParameters: { id: '1' } }), ctx, () => {});
  expect(result?.statusCode).toBe(204);
});
