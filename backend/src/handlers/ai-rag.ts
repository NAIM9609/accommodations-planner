import { RetrieveAndGenerateCommand } from '@aws-sdk/client-bedrock-agent-runtime';
import { APIGatewayProxyHandler } from 'aws-lambda';

import { BEDROCK_MODEL_ID, BEDROCK_REGION, bedrockAgentRuntime } from '../lib/bedrock';
import { respond } from '../lib/http';

export const handler: APIGatewayProxyHandler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return respond(204, null, event.headers);
  }

  const knowledgeBaseId = process.env.KNOWLEDGE_BASE_ID;
  if (!knowledgeBaseId) {
    return respond(503, { message: 'RAG knowledge base is not configured' }, event.headers);
  }

  let body: { question?: unknown };
  try {
    body = JSON.parse(event.body ?? 'null');
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
  } catch {
    return respond(400, { message: 'Invalid JSON body' }, event.headers);
  }

  if (!body.question || typeof body.question !== 'string' || !body.question.trim()) {
    return respond(400, { message: 'Missing required field: question' }, event.headers);
  }

  try {
    const modelArn = `arn:aws:bedrock:${BEDROCK_REGION}::foundation-model/${BEDROCK_MODEL_ID}`;

    const result = await bedrockAgentRuntime.send(
      new RetrieveAndGenerateCommand({
        input: { text: body.question as string },
        retrieveAndGenerateConfiguration: {
          type: 'KNOWLEDGE_BASE',
          knowledgeBaseConfiguration: {
            knowledgeBaseId,
            modelArn,
          },
        },
      }),
    );

    const citations =
      result.citations?.map((c) => ({
        text: c.generatedResponsePart?.textResponsePart?.text ?? '',
        references:
          c.retrievedReferences?.map((r) => ({
            content: r.content?.text ?? '',
            location: r.location?.s3Location?.uri ?? '',
          })) ?? [],
      })) ?? [];

    return respond(200, { answer: result.output?.text ?? '', citations }, event.headers);
  } catch (err) {
    console.error(err);
    return respond(500, { message: 'Internal server error' }, event.headers);
  }
};
