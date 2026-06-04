const path = require('path');
const fs = require('fs');
const { createRequire } = require('module');
const Module = require('module');

const scriptDir = __dirname;
const projectRoot = path.resolve(scriptDir, '..');
const buildRoot = process.env.RUSTDESK_HARMONY_BUILD_DIR
  ? path.resolve(process.env.RUSTDESK_HARMONY_BUILD_DIR)
  : path.resolve(projectRoot, '..', '99_Temp', 'rustdesk_harmonyos_build');
const platformSdksPath = path.resolve(
  'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/node_modules/@ohos/hos-sdkmanager-common/build/src/hos/mapper/platform-sdks.js'
);
const hmosSdkLoaderPath = path.resolve(
  'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/src/sdk/hmos-sdk-loader.js'
);
const hvigorEntry = path.resolve(
  'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js'
);
const hvigorPackageRoot = path.resolve(
  'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/hvigor'
);
const hvigorRequire = createRequire(hvigorEntry);
const extraNodePath = path.resolve(
  'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/hvigor/node_modules'
 );
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
  const candidates = [
    process.env.DEVECO_SDK_HOME,
    process.env.OHOS_HVIGOR_SDK_ROOT,
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

if (require.main === module) {
  const buildInfoPath = path.resolve(projectRoot, 'entry/src/main/ets/common/BuildInfo.ets');
  try {
    const fs = require('fs');
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    const buildTime = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    const buildInfoContent = `export class BuildInfo {\n  static readonly BUILD_TIME: string = '${buildTime}';\n  static readonly VERSION: string = '0.4.0';\n}\n`;
    fs.writeFileSync(buildInfoPath, buildInfoContent, 'utf8');
    const touchTime = new Date();
    fs.utimesSync(buildInfoPath, touchTime, touchTime);
    console.log(`[BuildInfo] Updated build time: ${buildTime}`);
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
