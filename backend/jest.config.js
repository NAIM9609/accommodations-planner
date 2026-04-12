const path = require('path');

module.exports = {
  rootDir: path.resolve(__dirname),
  preset: 'ts-jest',
  testEnvironment: 'node',
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      { tsconfig: path.resolve(__dirname, 'tsconfig.jest.json') },
    ],
  },
  testMatch: ['**/__tests__/**/*.test.ts'],
  collectCoverageFrom: ['src/**/*.ts'],
};
