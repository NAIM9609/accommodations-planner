import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

const region = process.env.AWS_REGION;
const tableName = process.env.DYNAMODB_TABLE_NAME;

if (!region) {
  throw new Error('Missing required environment variable: AWS_REGION');
}
if (!tableName) {
  throw new Error('Missing required environment variable: DYNAMODB_TABLE_NAME');
}

const client = new DynamoDBClient({ region });
export const ddb = DynamoDBDocumentClient.from(client);
export const TABLE_NAME = tableName;
