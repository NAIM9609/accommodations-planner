import { APIGatewayProxyResult } from 'aws-lambda';

const CORS_ALLOWED_HEADERS = 'Content-Type';
const CORS_ALLOWED_METHODS = 'OPTIONS,GET,POST,PUT,PATCH,DELETE';

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function buildAllowedOriginPatterns(): RegExp[] {
  const branch = (process.env.AMPLIFY_BRANCH ?? '').trim();
  const amplifyAppPattern = /^https:\/\/[a-z0-9-]+\.[a-z0-9]+\.amplifyapp\.com$/i;
  const branchPattern = branch
    ? new RegExp(`^https://${escapeRegex(branch)}\\.[a-z0-9]+\\.amplifyapp\\.com$`, 'i')
    : null;
  return [
    /^http:\/\/localhost(?::\d+)?$/i,
    /^http:\/\/127\.0\.0\.1(?::\d+)?$/i,
    /^https:\/\/localhost(?::\d+)?$/i,
    /^https:\/\/127\.0\.0\.1(?::\d+)?$/i,
    amplifyAppPattern,
    ...(branchPattern ? [branchPattern] : []),
  ];
}

function buildAllowedOrigins(): Set<string> {
  const configuredOrigins = (process.env.CORS_ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const customDomain = (process.env.CUSTOM_DOMAIN_URL ?? '').trim();
  if (customDomain) configuredOrigins.push(customDomain);
  return new Set(configuredOrigins);
}

function resolveAllowedOrigin(originHeader?: string): string | null {
  const origin = originHeader?.trim();
  if (!origin) return '*';

  const allowedOrigins = buildAllowedOrigins();
  if (allowedOrigins.has(origin)) return origin;

  const allowedPatterns = buildAllowedOriginPatterns();
  return allowedPatterns.some((pattern) => pattern.test(origin)) ? origin : null;
}

function corsHeaders(requestHeaders?: Record<string, string | undefined>): Record<string, string> {
  const origin = requestHeaders?.origin ?? requestHeaders?.Origin;
  const allowedOrigin = resolveAllowedOrigin(origin);
  const baseHeaders: Record<string, string> = {
    'Access-Control-Allow-Headers': CORS_ALLOWED_HEADERS,
    'Access-Control-Allow-Methods': CORS_ALLOWED_METHODS,
    Vary: 'Origin',
  };

  if (allowedOrigin) {
    baseHeaders['Access-Control-Allow-Origin'] = allowedOrigin;
  }

  return baseHeaders;
}

export function respond(
  statusCode: number,
  body: unknown,
  requestHeaders?: Record<string, string | undefined>,
): APIGatewayProxyResult {
  const responseCors = corsHeaders(requestHeaders);
  if (statusCode === 204) {
    return { statusCode, headers: responseCors, body: '' };
  }
  return {
    statusCode,
    headers: { ...responseCors, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}
