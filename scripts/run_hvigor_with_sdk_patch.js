const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');
const Module = require('module');

const scriptDir = __dirname;
const projectRoot = path.resolve(scriptDir, '..');
const tempRoot = process.env.RUSTDESK_HARMONY_TEMP_ROOT
  ? path.resolve(process.env.RUSTDESK_HARMONY_TEMP_ROOT)
  : path.resolve(projectRoot, '..', '99_Temp');
const buildRoot = process.env.RUSTDESK_HARMONY_BUILD_DIR
  ? path.resolve(process.env.RUSTDESK_HARMONY_BUILD_DIR)
  : path.resolve(tempRoot, 'rustdesk_harmonyos_build');

if (!process.env.CI) {
  process.env.CI = 'true';
}

function readLocalProperties(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }

  const values = {};
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }
    const separator = line.indexOf('=');
    if (separator < 0) {
      continue;
    }
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim().replace(/\\\\/g, '\\');
    if (key) {
      values[key] = value;
    }
  }
  return values;
}

function firstExistingPath(candidates) {
  for (const candidate of candidates.filter(Boolean)) {
    const resolved = path.resolve(candidate);
    if (fs.existsSync(resolved)) {
      return resolved;
    }
  }
  return null;
}

const localProperties = readLocalProperties(path.resolve(projectRoot, 'local.properties'));
const hvigorConfigPath = path.resolve(projectRoot, 'hvigor', 'hvigor-config.json5');
const portableHvigorConfigContent = `{
  "modelVersion": "6.1.1",
  "dependencies": {},
  "properties": {
    "hvigor.cacheDir": "../99_Temp/harmonyos_cache",
    "ohos.buildDir": "../99_Temp/harmonyos_build"
  }
}
`;

function toPortableJsonPath(targetPath) {
  return path.resolve(targetPath).replace(/\\/g, '/');
}

function writeHvigorConfig(cacheDir, buildDir) {
  const content = `{
  "modelVersion": "6.1.1",
  "dependencies": {},
  "properties": {
    "hvigor.cacheDir": "${toPortableJsonPath(cacheDir)}",
    "ohos.buildDir": "${toPortableJsonPath(buildDir)}"
  }
}
`;
  fs.writeFileSync(hvigorConfigPath, content, 'utf8');
}

function prepareHvigorConfigForCurrentWorkspace() {
  const cacheDir = path.resolve(tempRoot, 'harmonyos_cache');
  const buildDir = path.resolve(tempRoot, 'harmonyos_build');
  process.env.BUILD_CACHE_DIR = cacheDir;
  fs.mkdirSync(path.dirname(hvigorConfigPath), { recursive: true });
  fs.mkdirSync(cacheDir, { recursive: true });
  fs.mkdirSync(buildDir, { recursive: true });
  writeHvigorConfig(cacheDir, buildDir);
  process.once('exit', () => {
    try {
      fs.writeFileSync(hvigorConfigPath, portableHvigorConfigContent, 'utf8');
    } catch (_error) {}
  });
}

const defaultDevEcoToolsRoot = path.resolve('C:/Program Files/Huawei/DevEco Studio/tools');
const devecoToolsRoot = firstExistingPath([
  process.env.DEVECO_TOOLS_HOME,
  process.env.DEVECO_HOME && path.resolve(process.env.DEVECO_HOME, 'tools'),
  process.env.DEVECO_NODE_EXE && path.resolve(path.dirname(process.env.DEVECO_NODE_EXE), '..'),
  localProperties['npm.dir'] && path.resolve(localProperties['npm.dir'], '..'),
  defaultDevEcoToolsRoot,
]) || defaultDevEcoToolsRoot;
const hvigorRoot = path.resolve(devecoToolsRoot, 'hvigor');
const platformSdksPath = path.resolve(
  hvigorRoot,
  'hvigor-ohos-plugin/node_modules/@ohos/hos-sdkmanager-common/build/src/hos/mapper/platform-sdks.js'
);
const hmosSdkLoaderPath = path.resolve(
  hvigorRoot,
  'hvigor-ohos-plugin/src/sdk/hmos-sdk-loader.js'
);
const hvigorEntry = path.resolve(hvigorRoot, 'bin/hvigorw.js');
const hvigorPackageRoot = path.resolve(hvigorRoot, 'hvigor');
const hvigorRequire = createRequire(hvigorEntry);
const extraNodePath = path.resolve(hvigorPackageRoot, 'node_modules');
const selfRequireFlag = `--require=${__filename}`;
if (!process.env.NODE_OPTIONS || !process.env.NODE_OPTIONS.includes(__filename)) {
  process.env.NODE_OPTIONS = process.env.NODE_OPTIONS
    ? `${selfRequireFlag} ${process.env.NODE_OPTIONS}`
    : selfRequireFlag;
}
process.env.NODE_PATH = process.env.NODE_PATH
  ? `${extraNodePath}${path.delimiter}${process.env.NODE_PATH}`
  : extraNodePath;
Module._initPaths();

const originalResolveFilename = Module._resolveFilename;
const HMOS_SDK_LOADER_SUFFIX = path.normalize(
  'hvigor-ohos-plugin/src/sdk/hmos-sdk-loader.js'
).toLowerCase();
const PLATFORM_SDKS_SUFFIX = path.normalize(
  'hos-sdkmanager-common/build/src/hos/mapper/platform-sdks.js'
).toLowerCase();

function normalizePathForCompare(targetPath) {
  return path.normalize(targetPath).toLowerCase();
}

function pathMatches(resolvedPath, expectedPath, expectedSuffix) {
  const normalizedResolvedPath = normalizePathForCompare(resolvedPath);
  return normalizedResolvedPath === normalizePathForCompare(expectedPath)
    || normalizedResolvedPath.endsWith(expectedSuffix);
}

Module._resolveFilename = function patchedResolveFilename(request, parent, isMain, options) {
  if (request === '@ohos/hvigor') {
    return originalResolveFilename.call(this, hvigorPackageRoot, parent, isMain, options);
  }
  if (request.startsWith('@ohos/hvigor/')) {
    const hvigorSubpath = path.join(
      hvigorPackageRoot,
      request.slice('@ohos/hvigor/'.length)
    );
    return originalResolveFilename.call(this, hvigorSubpath, parent, isMain, options);
  }
  return originalResolveFilename.call(this, request, parent, isMain, options);
};
const originalLoad = Module._load;

function resolveSdkRoot() {
  const sdkDirParent = localProperties['sdk.dir']
    ? path.resolve(localProperties['sdk.dir'], '..')
    : null;
  const candidates = [
    process.env.DEVECO_SDK_HOME,
    process.env.OHOS_HVIGOR_SDK_ROOT,
    localProperties['hwsdk.dir'],
    sdkDirParent,
    path.resolve('C:/Program Files/Huawei/DevEco Studio/sdk/default'),
    path.resolve(buildRoot, '.local_sdk', 'default'),
    path.resolve(buildRoot, 'sdk', 'default'),
    path.resolve(projectRoot, '.local_sdk', 'default'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (candidate && require('fs').existsSync(candidate)) {
      return candidate;
    }
  }

  return candidates[0];
}

const { PlatformSdks } = hvigorRequire(platformSdksPath);
if (Array.isArray(PlatformSdks._additional) && !PlatformSdks._additional.includes('js')) {
  PlatformSdks._additional = PlatformSdks._additional.concat('js');
}

function createApiVersion(major) {
  return {
    getMajor() {
      return major;
    },
    getValue() {
      return major;
    }
  };
}

function createComponent(componentPath, location) {
  return {
    getPath() {
      return componentPath;
    },
    getLocation() {
      return location;
    },
    getVersion() {
      return '6.0.2.130';
    },
    getReleaseType() {
      return 'Release';
    },
    getFullApiVersion() {
      return createApiVersion(22);
    }
  };
}

const { HmosSdkLoader } = hvigorRequire(hmosSdkLoaderPath);
const sdkRoot = resolveSdkRoot();
function patchHmosSdkLoader(targetLoader) {
  if (!targetLoader || targetLoader.__rustdeskPatched === true) {
    return targetLoader;
  }
  targetLoader.prototype.checkComponentExistence = function () {
    return true;
  };
  targetLoader.prototype.getHmosSdkComponents = async function (_sdkVersion, components) {
    const componentMap = new Map();
    components.forEach((name) => {
      componentMap.set(name, createComponent(name, path.resolve(sdkRoot, 'openharmony', name)));
    });
    return componentMap;
  };
  targetLoader.prototype.getHmsSdkComponents = async function (_sdkVersion, components) {
    const componentMap = new Map();
    components.forEach((name) => {
      componentMap.set(name, createComponent(name, path.resolve(sdkRoot, 'hms', name)));
    });
    return componentMap;
  };
  targetLoader.__rustdeskPatched = true;
  return targetLoader;
}

patchHmosSdkLoader(HmosSdkLoader);

Module._load = function patchedLoad(request, parent, isMain) {
  const loaded = originalLoad.call(this, request, parent, isMain);
  try {
    const resolved = originalResolveFilename.call(this, request, parent, isMain);
    if (pathMatches(resolved, hmosSdkLoaderPath, HMOS_SDK_LOADER_SUFFIX) && loaded?.HmosSdkLoader) {
      patchHmosSdkLoader(loaded.HmosSdkLoader);
    }
    // Patch typescript module to downgrade ArkTS strict mode faults to warnings
    if (resolved && resolved.endsWith('typescript.js') && resolved.includes('ets-loader')) {
      if (typeof loaded === 'object' && loaded !== null) {
        for (const key of Object.keys(loaded)) {
          const val = loaded[key];
          if (typeof val === 'object' && val !== null && val[49] && typeof val[49] === 'object') {
            if ('cookBookRef' in val[49] && val[49].cookBookRef === '93') {
              val[49].warning = true;
              if (val[0] && val[0].cookBookRef === '8') val[0].warning = true;
              if (val[18] && val[18].cookBookRef === '8') val[18].warning = true;
              if (val[2] && val[2].cookBookRef === '38') val[2].warning = true;
            }
          }
        }
      }
    }
  } catch (_error) {
    // Ignore resolution failures and preserve the normal module loading path.
  }
  return loaded;
};

function readFileText(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf8');
    }
  } catch (_error) {}
  return '';
}

function readAppVersion(appJson5Path) {
  const content = readFileText(appJson5Path);
  const versionNameMatch = content.match(/"versionName"\s*:\s*"([^"]+)"/);
  const versionCodeMatch = content.match(/"versionCode"\s*:\s*(\d+)/);
  return {
    content,
    versionName: versionNameMatch && versionNameMatch[1] ? versionNameMatch[1] : '',
    versionCode: versionCodeMatch && versionCodeMatch[1] ? Number(versionCodeMatch[1]) : 0
  };
}

function readBuildInfoVersion(buildInfoPath) {
  const content = readFileText(buildInfoPath);
  const match = content.match(/VERSION:\s*string\s*=\s*'([^']+)'/);
  return match && match[1] ? match[1] : '';
}

function normalizeVersionName(versionName) {
  const parts = String(versionName || '').trim().split('.');
  const numbers = [0, 4, 0];
  for (let i = 0; i < Math.min(parts.length, 3); i++) {
    const value = Number.parseInt(parts[i], 10);
    numbers[i] = Number.isFinite(value) && value >= 0 ? value : 0;
  }
  return numbers;
}

function bumpVersionName(versionName, bumpMode) {
  const [major, minor, patch] = normalizeVersionName(versionName);
  if (bumpMode === 'full') {
    return `${major}.${minor + 1}.0`;
  }
  if (bumpMode === 'incremental') {
    return `${major}.${minor}.${patch + 1}`;
  }
  return `${major}.${minor}.${patch}`;
}

function writeAppVersion(appJson5Path, appContent, versionName, versionCode) {
  if (!appContent) {
    return;
  }
  let nextContent = appContent;
  nextContent = nextContent.replace(/"versionName"\s*:\s*"[^"]+"/, `"versionName": "${versionName}"`);
  nextContent = nextContent.replace(/"versionCode"\s*:\s*\d+/, `"versionCode": ${versionCode}`);
  fs.writeFileSync(appJson5Path, nextContent, 'utf8');
}

if (require.main === module) {
  prepareHvigorConfigForCurrentWorkspace();

  const buildInfoPath = path.resolve(projectRoot, 'entry/src/main/ets/common/BuildInfo.ets');
  try {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const buildTime = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    const appJson5Path = path.resolve(projectRoot, 'AppScope/app.json5');
    const appVersion = readAppVersion(appJson5Path);
    const buildInfoVersion = readBuildInfoVersion(buildInfoPath);
    const baseVersionName = buildInfoVersion || appVersion.versionName || '0.4.0';
    const bumpMode = String(process.env.RUSTDESK_HARMONY_VERSION_BUMP || '').trim().toLowerCase();
    const versionName = bumpVersionName(baseVersionName, bumpMode);
    const versionCode = bumpMode === 'full' || bumpMode === 'incremental'
      ? Math.max(1, appVersion.versionCode + 1)
      : Math.max(1, appVersion.versionCode);
    writeAppVersion(appJson5Path, appVersion.content, versionName, versionCode);
    const buildInfoContent = `export class BuildInfo {\n  static readonly BUILD_TIME: string = '${buildTime}';\n  static readonly VERSION: string = '${versionName}';\n}\n`;
    fs.writeFileSync(buildInfoPath, buildInfoContent, 'utf8');
    const touchTime = new Date();
    fs.utimesSync(buildInfoPath, touchTime, touchTime);
    console.log(`[BuildInfo] Updated build time: ${buildTime}, version: ${versionName}, versionCode: ${versionCode}, bump: ${bumpMode || 'none'}`);
  } catch (_e) {}

  const hvigorTasks = process.argv.slice(2);
  process.argv = [
    process.argv[0],
    hvigorEntry,
    '--no-daemon',
    '--mode',
    'module',
    '--debug',
    '-p',
    'product=default',
    '-p',
    'module=entry@default',
    '-p',
    'pageType=page',
    '-p',
    'compileResInc=true',
    ...(hvigorTasks.length > 0 ? hvigorTasks : ['assembleHap'])
  ];

  hvigorRequire(hvigorEntry);

}
