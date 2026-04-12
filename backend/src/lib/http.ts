import { APIGatewayProxyResult } from 'aws-lambda';

export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'OPTIONS,GET,POST,PUT,PATCH,DELETE',
};

export function respond(statusCode: number, body: unknown): APIGatewayProxyResult {
  if (statusCode === 204) {
    return { statusCode, headers: cors, body: '' };
  }
  return {
    statusCode,
    headers: { ...cors, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}
