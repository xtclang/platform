import globals from 'globals'
import pluginVue from 'eslint-plugin-vue'
import prettier from 'eslint-config-prettier'

// Flat config (ESLint 9+). Replaces the legacy .eslintrc.cjs / .eslintignore,
// which ESLint 9 no longer reads and eslint-plugin-vue 10 no longer ships
// legacy shareable configs for.
export default [
  {
    // Migrated from .eslintignore
    ignores: [
      'dist/**',
      'src-capacitor/**',
      'src-cordova/**',
      '.quasar/**',
      'node_modules/**',
      'quasar.config.*.temporary.compiled*'
    ]
  },

  // Vue 3 "essential" rules; also wires vue-eslint-parser for *.vue files.
  ...pluginVue.configs['flat/essential'],

  {
    languageOptions: {
      ecmaVersion: 2021,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
        ga: 'readonly',
        cordova: 'readonly',
        __statics: 'readonly',
        __QUASAR_SSR__: 'readonly',
        __QUASAR_SSR_SERVER__: 'readonly',
        __QUASAR_SSR_CLIENT__: 'readonly',
        __QUASAR_SSR_PWA__: 'readonly',
        Capacitor: 'readonly',
        chrome: 'readonly'
      }
    },
    rules: {
      'prefer-promise-reject-errors': 'off',
      // allow debugger during development only
      'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off'
    }
  },

  // Disable ESLint rules that conflict with Prettier; must stay last.
  prettier
]
