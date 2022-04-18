module.exports = {
  arrowParens: 'avoid',
  bracketSpacing: true,
  bracketSameLine: true,
  singleQuote: true,
  trailingComma: 'es5',
  tabWidth: 2,
  endOfLine: 'auto',
  semi: true,
  printWidth: 120,
  overrides: [
    {
      files: '*.sol',
      options: {
        printWidth: 80,
        tabWidth: 4,
        useTabs: false,
        singleQuote: false,
        bracketSpacing: false,
        explicitTypes: 'always',
      },
    },
  ],
};
