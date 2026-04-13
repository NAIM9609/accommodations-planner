import { APIGatewayProxyHandler } from 'aws-lambda';
import { respond } from '../lib/http';

export const handler: APIGatewayProxyHandler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return respond(204, null, event.headers);
  }

  return respond(200, { status: 'ok', timestamp: new Date().toISOString() }, event.headers);
};
