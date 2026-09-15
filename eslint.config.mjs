import ionic from '@ionic/eslint-config/recommended.js';

export default [
  {
    ignores: ['dist/**', 'build/**', '**/.build/**', 'node_modules/**', 'android/**', 'ios/**', 'example-app/**'],
  },
  ...ionic,
];
