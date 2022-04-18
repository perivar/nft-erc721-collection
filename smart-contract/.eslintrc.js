module.exports = {
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true,
  },
  plugins: ['@typescript-eslint', 'simple-import-sort', 'unused-imports'],
  extends: [
    'standard',
    'eslint:recommended',
    'plugin:@typescript-eslint/eslint-recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:node/recommended',
    'plugin:prettier/recommended',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 12,
  },
  rules: {
    'node/no-unsupported-features/es-syntax': ['error', { ignores: ['modules'] }],
    'node/no-missing-import': [
      'error',
      {
        allowModules: [],
        resolvePaths: ['node_modules/@types'],
        tryExtensions: ['.js', '.json', '.node', '.ts', '.d.ts'],
      },
    ],
    'node/no-unpublished-import': 0,
    'node/no-path-concat': 0,
    camelcase: 'off',
    'no-console': 'off',
    'unused-imports/no-unused-imports-ts': 'warn',
    'simple-import-sort/imports': 'error',
    '@typescript-eslint/no-non-null-assertion': 'off',
  },
};
