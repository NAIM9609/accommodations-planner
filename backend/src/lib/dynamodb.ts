import { DynamoDBClient, DynamoDBClientConfig } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

const region = process.env.AWS_REGION;
const tableName = process.env.DYNAMODB_TABLE_NAME;

if (!region) {
  throw new Error('Missing required environment variable: AWS_REGION');
}
if (!tableName) {
  throw new Error('Missing required environment variable: DYNAMODB_TABLE_NAME');
}

// DYNAMODB_ENDPOINT is set only for local development with LocalStack.
// It is never set in the Lambda runtime; the SDK uses the standard AWS endpoint.
const clientConfig: DynamoDBClientConfig = { region };
if (process.env.DYNAMODB_ENDPOINT) {
  clientConfig.endpoint = process.env.DYNAMODB_ENDPOINT;
}

const client = new DynamoDBClient(clientConfig);
export const ddb = DynamoDBDocumentClient.from(client);
export const TABLE_NAME = tableName;
