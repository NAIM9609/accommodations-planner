import { APIGatewayProxyEvent, Context } from 'aws-lambda';

import { handler } from '../src/handlers/ai-rag';

jest.mock('../src/lib/bedrock', () => ({
  bedrockAgentRuntime: { send: jest.fn() },
  BEDROCK_MODEL_ID: 'anthropic.claude-3-haiku-20240307-v1:0',
  BEDROCK_REGION: 'us-east-1',
}));

import { bedrockAgentRuntime } from '../src/lib/bedrock';
const mockSend = bedrockAgentRuntime.send as jest.Mock;

const ctx = {} as Context;

function makeEvent(overrides: Partial<APIGatewayProxyEvent>): APIGatewayProxyEvent {
  return {
    httpMethod: 'POST',
    path: '/ai/rag',
    pathParameters: null,
    queryStringParameters: null,
    headers: {},
    multiValueHeaders: {},
    body: null,
    isBase64Encoded: false,
    resource: '',
    stageVariables: null,
    requestContext: {} as APIGatewayProxyEvent['requestContext'],
    multiValueQueryStringParameters: null,
    ...overrides,
  };
}

beforeEach(() => {
  mockSend.mockReset();
  delete process.env.KNOWLEDGE_BASE_ID;
});

test('OPTIONS /ai/rag returns 204', async () => {
  const result = await handler(makeEvent({ httpMethod: 'OPTIONS' }), ctx, () => {});
  expect(result?.statusCode).toBe(204);
});

test('POST /ai/rag returns 503 when KNOWLEDGE_BASE_ID is not set', async () => {
  const result = await handler(
    makeEvent({ body: JSON.stringify({ question: 'What rooms are available?' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(503);
});

test('POST /ai/rag returns answer and citations', async () => {
  process.env.KNOWLEDGE_BASE_ID = 'test-kb-id';
  mockSend.mockResolvedValue({
    output: { text: 'We have standard and deluxe rooms.' },
    citations: [
      {
        generatedResponsePart: {
          textResponsePart: { text: 'We have standard and deluxe rooms.' },
        },
        retrievedReferences: [
          {
            content: { text: 'Room types: standard, deluxe' },
            location: { s3Location: { uri: 's3://bucket/rooms.pdf' } },
          },
        ],
      },
    ],
  });
  const result = await handler(
    makeEvent({ body: JSON.stringify({ question: 'What rooms are available?' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(200);
  const body = JSON.parse(result!.body);
  expect(body.answer).toBe('We have standard and deluxe rooms.');
  expect(body.citations).toHaveLength(1);
  expect(body.citations[0].references[0].location).toBe('s3://bucket/rooms.pdf');
});

test('POST /ai/rag returns empty citations when none provided', async () => {
  process.env.KNOWLEDGE_BASE_ID = 'test-kb-id';
  mockSend.mockResolvedValue({ output: { text: 'No info found.' }, citations: [] });
  const result = await handler(
    makeEvent({ body: JSON.stringify({ question: 'What is the checkout time?' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(200);
  const body = JSON.parse(result!.body);
  expect(body.citations).toEqual([]);
});

test('POST /ai/rag returns 400 for missing question field', async () => {
  process.env.KNOWLEDGE_BASE_ID = 'test-kb-id';
  const result = await handler(makeEvent({ body: JSON.stringify({}) }), ctx, () => {});
  expect(result?.statusCode).toBe(400);
});

test('POST /ai/rag returns 400 for whitespace-only question', async () => {
  process.env.KNOWLEDGE_BASE_ID = 'test-kb-id';
  const result = await handler(
    makeEvent({ body: JSON.stringify({ question: '  ' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(400);
});

test('POST /ai/rag returns 400 for invalid JSON body', async () => {
  process.env.KNOWLEDGE_BASE_ID = 'test-kb-id';
  const result = await handler(makeEvent({ body: 'not-json' }), ctx, () => {});
  expect(result?.statusCode).toBe(400);
});

test('POST /ai/rag returns 500 when Bedrock throws', async () => {
  process.env.KNOWLEDGE_BASE_ID = 'test-kb-id';
  mockSend.mockRejectedValue(new Error('Bedrock error'));
  const result = await handler(
    makeEvent({ body: JSON.stringify({ question: 'What rooms are available?' }) }),
    ctx,
    () => {},
  );
  expect(result?.statusCode).toBe(500);
});
