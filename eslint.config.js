import js from "@eslint/js";
import globals from "globals";

export default [
  js.configs.recommended,
  // Browser JS (assets/js/)
  {
    files: ["assets/js/**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.browser,
        MathJax: "readonly",
        Prism: "readonly",
        DatalogMath: "readonly",
        Plotly: "readonly",
        Bokeh: "readonly",
        Chart: "readonly",
        process: "readonly", // replaced by esbuild at build time
      },
    },
    rules: {
      "no-unused-vars": ["warn", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_|^error$|^e$" }],
      "no-console": "off",
      "no-undef": "error",
      "no-useless-assignment": "off",
      "eqeqeq": ["warn", "smart"],
      "no-var": "error",
      "prefer-const": "warn",
    },
  },
  // Root tooling configuration files (Node)
  {
    files: ["*.config.js", "*.config.mjs"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.node,
      },
    },
  },
  // Node.js scripts
  {
    files: ["scripts/**/*.{js,mjs}"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.node,
      },
    },
    rules: {
      "no-unused-vars": ["warn", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_|^error$|^e$" }],
      "no-console": "off",
      "no-undef": "error",
      "no-useless-assignment": "off",
      "preserve-caught-error": "off",
      "no-var": "error",
      "prefer-const": "warn",
    },
  },
  // Test files
  {
    files: ["tests/**/*.{js,mjs}"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node,
        MathJax: "readonly",
        Prism: "readonly",
        DatalogMath: "readonly",
        Plotly: "readonly",
        Bokeh: "readonly",
        Chart: "readonly",
        // Vitest globals
        describe: "readonly",
        it: "readonly",
        test: "readonly",
        expect: "readonly",
        vi: "readonly",
        beforeEach: "readonly",
        afterEach: "readonly",
        beforeAll: "readonly",
        afterAll: "readonly",
      },
    },
    rules: {
      "no-unused-vars": ["warn", { argsIgnorePattern: "^_", caughtErrorsIgnorePattern: "^_|^error$|^e$" }],
      "no-console": "off",
      "no-undef": "error",
      "no-useless-catch": "off",
    },
  },
  {
    ignores: [
      "assets/js/dist/",
      "node_modules/",
      "_site/",
      "vendor/",
      "coverage/",
    ],
  },
];
