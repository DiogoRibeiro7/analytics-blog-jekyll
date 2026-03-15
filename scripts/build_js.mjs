import { build } from "esbuild";
import { fileURLToPath } from "url";
import path from "path";
import fs from "fs/promises";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const sourceDir = path.resolve(rootDir, "assets/js");
const outputDir = path.resolve(sourceDir, "dist");
const dataDir = path.resolve(rootDir, "_data");

const entryDefinitions = [
  { name: "core", file: "main.js", category: "core" },
  { name: "loader", file: "loader.js", category: "loader" },
  { name: "search", file: "search.js", category: "feature" },
  { name: "math", file: "math.js", category: "feature" },
  { name: "visualizations", file: "visualizations.js", category: "feature" },
  { name: "notebook", file: "notebook.js", category: "feature" },
  { name: "academic", file: "academic.js", category: "feature" },
  { name: "analytics-dashboard", file: "analytics-dashboard.js", category: "feature" }
];

const entryPoints = entryDefinitions.reduce((memo, definition) => {
  memo[definition.name] = path.resolve(sourceDir, definition.file);
  return memo;
}, {});

const entryByPath = new Map(
  entryDefinitions.map((definition) => [
    path.relative(rootDir, path.resolve(sourceDir, definition.file)).replace(/\\/g, "/"),
    definition
  ])
);

async function prepareDirectories() {
  await fs.rm(outputDir, { recursive: true, force: true });
  await fs.mkdir(outputDir, { recursive: true });
  await fs.mkdir(dataDir, { recursive: true });
}

function buildManifest(meta) {
  const manifest = {
    core: null,
    loader: null,
    features: {},
    entrypoints: {}
  };

  Object.entries(meta.outputs).forEach(([outfile, output]) => {
    if (!output.entryPoint) {
      return;
    }
    const normalizedEntry = output.entryPoint.replace(/\\/g, "/");
    const definition = entryByPath.get(normalizedEntry);
    if (!definition) {
      return;
    }
    const publicPath = `/${outfile.replace(/\\/g, "/")}`;
    manifest.entrypoints[definition.name] = publicPath;
    if (definition.category === "core") {
      manifest.core = publicPath;
    } else if (definition.category === "loader") {
      manifest.loader = publicPath;
    } else if (definition.category === "feature") {
      manifest.features[definition.name] = publicPath;
    }
  });

  return manifest;
}

async function writeOutputs(manifest, meta) {
  const manifestPath = path.resolve(outputDir, "manifest.json");
  const metaPath = path.resolve(outputDir, "meta.json");
  const dataManifestPath = path.resolve(dataDir, "js_manifest.json");
  const dataMetaPath = path.resolve(dataDir, "js_meta.json");

  const manifestJson = `${JSON.stringify(manifest, null, 2)}\n`;
  const metaJson = `${JSON.stringify(meta, null, 2)}\n`;

  await Promise.all([
    fs.writeFile(manifestPath, manifestJson),
    fs.writeFile(metaPath, metaJson),
    fs.writeFile(dataManifestPath, manifestJson),
    fs.writeFile(dataMetaPath, metaJson)
  ]);

  console.log(`Wrote manifest → ${path.relative(rootDir, manifestPath)}`);
  console.log(`Wrote metafile → ${path.relative(rootDir, metaPath)}`);
}

async function buildAll() {
  await prepareDirectories();
  const result = await build({
    entryPoints,
    outdir: outputDir,
    bundle: true,
    minify: true,
    format: "esm",
    splitting: true,
    sourcemap: false,
    target: ["es2017"],
    logLevel: "info",
    legalComments: "none",
    metafile: true,
    entryNames: "[name]",
    chunkNames: "chunks/[name]-[hash]",
    drop: (process.env.NODE_ENV || "production") === "production" ? ["console"] : [],
    define: {
      "process.env.NODE_ENV": JSON.stringify(process.env.NODE_ENV || "production")
    }
  });

  const manifest = buildManifest(result.metafile);
  await writeOutputs(manifest, result.metafile);
}

buildAll().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
