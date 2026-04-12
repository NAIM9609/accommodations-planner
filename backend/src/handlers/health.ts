import { APIGatewayProxyHandler } from 'aws-lambda';
import { respond } from '../lib/http';

export const handler: APIGatewayProxyHandler = async () => {
  return respond(200, { status: 'ok', timestamp: new Date().toISOString() });
};
