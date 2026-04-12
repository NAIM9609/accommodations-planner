import { APIGatewayProxyResult } from 'aws-lambda';

export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

export function respond(statusCode: number, body: unknown): APIGatewayProxyResult {
  return { statusCode, headers: cors, body: JSON.stringify(body) };
}
