import { BedrockAgentRuntimeClient } from '@aws-sdk/client-bedrock-agent-runtime';
import { BedrockRuntimeClient } from '@aws-sdk/client-bedrock-runtime';

const region = process.env.AWS_REGION ?? 'us-east-1';

export const BEDROCK_REGION = region;
export const bedrockRuntime = new BedrockRuntimeClient({ region });
export const bedrockAgentRuntime = new BedrockAgentRuntimeClient({ region });

// Default model: Claude 3 Haiku. Override via BEDROCK_MODEL_ID env var.
// The model must be enabled in the Bedrock console for the target region.
export const BEDROCK_MODEL_ID =
  process.env.BEDROCK_MODEL_ID ?? 'anthropic.claude-3-haiku-20240307-v1:0';
