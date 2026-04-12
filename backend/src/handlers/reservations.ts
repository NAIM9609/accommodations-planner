import { randomUUID } from 'node:crypto';
import { APIGatewayProxyHandler } from 'aws-lambda';
import { PutCommand, GetCommand, DeleteCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, TABLE_NAME } from '../lib/dynamodb';
import { respond } from '../lib/http';

export const handler: APIGatewayProxyHandler = async (event) => {
  const method = event.httpMethod;
  const id = event.pathParameters?.id;

  try {
    if (method === 'GET' && !id) {
      const result = await ddb.send(new ScanCommand({ TableName: TABLE_NAME }));
      return respond(200, result.Items ?? []);
    }

    if (method === 'GET' && id) {
      const result = await ddb.send(new GetCommand({ TableName: TABLE_NAME, Key: { id } }));
      if (!result.Item) return respond(404, { message: 'Not found' });
      return respond(200, result.Item);
    }

    if (method === 'POST') {
      let body: Record<string, unknown>;
      try {
        body = JSON.parse(event.body ?? 'null');
        if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('Invalid body');
      } catch {
        return respond(400, { message: 'Invalid JSON body' });
      }
      if (!body.guestName || !body.guestEmail || !body.checkIn || !body.checkOut) {
        return respond(400, { message: 'Missing required fields: guestName, guestEmail, checkIn, checkOut' });
      }
      const item = {
        id: randomUUID(),
        guestName: body.guestName,
        guestEmail: body.guestEmail,
        checkIn: body.checkIn,
        checkOut: body.checkOut,
        roomType: body.roomType ?? 'standard',
        createdAt: new Date().toISOString(),
      };
      await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));
      return respond(201, item);
    }

    if (method === 'DELETE' && id) {
      await ddb.send(new DeleteCommand({ TableName: TABLE_NAME, Key: { id } }));
      return respond(204, null);
    }

    return respond(405, { message: 'Method not allowed' });
  } catch (err) {
    console.error(err);
    return respond(500, { message: 'Internal server error' });
  }
};
