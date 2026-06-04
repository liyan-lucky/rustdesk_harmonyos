#!/usr/bin/env node

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const STATIC_COMPONENT = Buffer.from([
  49, 243, 9, 115, 214, 175, 91, 184,
  211, 190, 177, 88, 101, 131, 192, 119,
]);

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    product: 'default',
    execute: false,
    showSecrets: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith('--')) {
      fail(`Unexpected argument: ${arg}`);
    }

    const key = arg.slice(2);
    if (key === 'execute' || key === 'show-secrets') {
      args[key === 'show-secrets' ? 'showSecrets' : key] = true;
      continue;
    }

    const value = argv[index + 1];
    if (value === undefined || value.startsWith('--')) {
      fail(`Missing value for --${key}`);
    }
    index += 1;

    switch (key) {
      case 'project':
        args.project = value;
        break;
      case 'build-profile':
        args.buildProfile = value;
        break;
      case 'product':
        args.product = value;
        break;
      case 'sdk-root':
        args.sdkRoot = value;
        break;
      case 'java':
        args.java = value;
        break;
      case 'input':
        args.input = value;
        break;
      case 'output':
        args.output = value;
        break;
      case 'write-command':
        args.writeCommand = value;
        break;
      default:
        fail(`Unknown option: --${key}`);
    }
  }

  return args;
}

function resolveExistingPath(candidates) {
  for (const candidate of candidates) {
    if (!candidate) {
      continue;
    }
    const resolved = path.resolve(candidate);
    if (fs.existsSync(resolved)) {
      return resolved;
    }
  }
  return null;
}

function readLocalProperties(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  const result = {};
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
      result[key] = value;
    }
  }
  return result;
}

function readJsonFile(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8').trim();
  if (!raw) {
    fail(`JSON file is empty: ${filePath}`);
  }
  try {
    return JSON.parse(raw);
  } catch (error) {
    fail(`Failed to parse JSON file ${filePath}: ${error.message}`);
  }
}

function resolveConfigPath(baseDir, candidatePath) {
  if (path.isAbsolute(candidatePath)) {
    return path.normalize(candidatePath);
  }
  return path.resolve(baseDir, candidatePath);
}

function getSigningConfig(buildProfile, productName) {
  const app = buildProfile.app || {};
  const products = Array.isArray(app.products) ? app.products : [];
  const signingConfigs = Array.isArray(app.signingConfigs) ? app.signingConfigs : [];
  const product = products.find((item) => item && item.name === productName);
  if (!product) {
    fail(`Product '${productName}' was not found in build-profile.json5`);
  }
  if (!product.signingConfig) {
    fail(`Product '${productName}' does not define a signingConfig`);
  }
  const signingConfig = signingConfigs.find((item) => item && item.name === product.signingConfig);
  if (!signingConfig) {
    fail(`Signing config '${product.signingConfig}' was not found in build-profile.json5`);
  }
  if (!signingConfig.material) {
    fail(`Signing config '${signingConfig.name}' does not define material`);
  }
  return {
    product,
    signingConfig,
  };
}

function readSingleFileBytes(dirPath, label) {
  if (!fs.existsSync(dirPath) || !fs.statSync(dirPath).isDirectory()) {
    fail(`Signing material directory is missing: ${dirPath} (${label})`);
  }
  const entries = fs.readdirSync(dirPath).filter((entry) => entry !== '.DS_Store');
  if (entries.length !== 1) {
    fail(`Signing material directory should contain exactly one file: ${dirPath} (${label})`);
  }
  const filePath = path.join(dirPath, entries[0]);
  return fs.readFileSync(filePath);
}

function readFdBuffers(materialRoot, label) {
  const fdRoot = path.join(materialRoot, 'fd');
  if (!fs.existsSync(fdRoot) || !fs.statSync(fdRoot).isDirectory()) {
    fail(`Signing material fd directory is missing: ${fdRoot} (${label})`);
  }
  const entries = fs.readdirSync(fdRoot).filter((entry) => entry !== '.DS_Store').sort();
  if (entries.length !== 3) {
    fail(`Signing material fd directory should contain exactly 3 entries: ${fdRoot} (${label})`);
  }
  return entries.map((entry) => readSingleFileBytes(path.join(fdRoot, entry), label));
}

function xorBuffers(buffers, label) {
  if (buffers.length === 0) {
    fail(`No signing material buffers were provided (${label})`);
  }
  const bufferLength = buffers[0].length;
  for (const buffer of buffers) {
    if (buffer.length !== bufferLength) {
      fail(`Signing material buffer length mismatch (${label})`);
    }
  }
  const result = Buffer.alloc(bufferLength);
  for (let byteIndex = 0; byteIndex < bufferLength; byteIndex += 1) {
    let value = 0;
    for (const buffer of buffers) {
      value ^= buffer[byteIndex];
    }
    result[byteIndex] = value;
  }
  return result;
}

function decryptPayload(key, encrypted, label) {
  try {
    const encryptedTailLength = ((encrypted[0] & 0xff) << 24)
      | ((encrypted[1] & 0xff) << 16)
      | ((encrypted[2] & 0xff) << 8)
      | (encrypted[3] & 0xff);
    const ivLength = encrypted.length - 4 - encryptedTailLength;
    if (ivLength <= 0 || encryptedTailLength < 16) {
      fail(`Encrypted signing payload is invalid (${label})`);
    }
    const iv = encrypted.subarray(4, 4 + ivLength);
    const cipherText = encrypted.subarray(4 + ivLength, encrypted.length - 16);
    const authTag = encrypted.subarray(encrypted.length - 16);
    const decipher = crypto.createDecipheriv('aes-128-gcm', key, iv);
    decipher.setAuthTag(authTag);
    return Buffer.concat([decipher.update(cipherText), decipher.final()]);
  } catch (error) {
    fail(`Failed to decrypt signing password (${label}): ${error.message}`);
  }
}

function decryptPassword(storeFilePath, encryptedHex, label) {
  if (!encryptedHex || encryptedHex.length < 32 || encryptedHex.length % 2 !== 0) {
    fail(`Encrypted signing password is malformed (${label})`);
  }
  const materialBaseDir = path.resolve(storeFilePath, '..');
  const materialRoot = path.join(materialBaseDir, 'material');
  if (!fs.existsSync(materialRoot) || !fs.statSync(materialRoot).isDirectory()) {
    fail(`Signing material directory was not found: ${materialRoot}`);
  }

  const fdBuffers = readFdBuffers(materialRoot, label);
  const salt = readSingleFileBytes(path.join(materialRoot, 'ac'), label);
  const workMaterial = readSingleFileBytes(path.join(materialRoot, 'ce'), label);
  const rootKeySeed = xorBuffers(fdBuffers.concat([STATIC_COMPONENT]), label);
  const rootKey = crypto.pbkdf2Sync(rootKeySeed.toString('utf8'), salt, 10000, 16, 'sha256');
  const key = decryptPayload(rootKey, workMaterial, `${label} material`);
  const passwordBytes = decryptPayload(key, Buffer.from(encryptedHex, 'hex'), label);
  return passwordBytes.toString('utf8');
}

function resolveSignTool(args, localProperties) {
  const candidates = [
    args.sdkRoot && path.join(args.sdkRoot, 'toolchains', 'lib', 'hap-sign-tool.jar'),
    args.sdkRoot && path.join(args.sdkRoot, 'openharmony', 'toolchains', 'lib', 'hap-sign-tool.jar'),
    process.env.OHOS_BASE_SDK_HOME && path.join(process.env.OHOS_BASE_SDK_HOME, 'toolchains', 'lib', 'hap-sign-tool.jar'),
    process.env.DEVECO_SDK_HOME && path.join(process.env.DEVECO_SDK_HOME, 'openharmony', 'toolchains', 'lib', 'hap-sign-tool.jar'),
    localProperties['sdk.dir'] && path.join(localProperties['sdk.dir'], 'toolchains', 'lib', 'hap-sign-tool.jar'),
    localProperties['hwsdk.dir'] && path.join(localProperties['hwsdk.dir'], 'openharmony', 'toolchains', 'lib', 'hap-sign-tool.jar'),
    'C:\\Program Files\\Huawei\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\lib\\hap-sign-tool.jar',
  ];

  const resolved = resolveExistingPath(candidates);
  if (!resolved) {
    fail('hap-sign-tool.jar was not found. Set --sdk-root or configure local.properties.');
  }
  return resolved;
}

function resolveJavaExecutable(args) {
  const candidates = [
    args.java,
    process.env.JAVA_HOME && path.join(process.env.JAVA_HOME, 'bin', 'java.exe'),
    'C:\\Program Files\\Huawei\\DevEco Studio\\jbr\\bin\\java.exe',
  ];

  const resolved = resolveExistingPath(candidates);
  if (resolved) {
    return resolved;
  }

  try {
    const whereResult = childProcess.spawnSync('where', ['java'], {
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
      shell: true,
    });
    if (whereResult.status === 0) {
      const firstLine = (whereResult.stdout || '').split(/\r?\n/).find(Boolean);
      if (firstLine && fs.existsSync(firstLine.trim())) {
        return firstLine.trim();
      }
    }
  } catch (error) {
    // Fall through to final error.
  }

  fail('java executable was not found. Set --java or JAVA_HOME.');
}

function quotePowerShell(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function buildPowerShellCommand(javaPath, signToolPath, signArgs) {
  const pieces = [
    `& ${quotePowerShell(javaPath)}`,
    '-jar',
    quotePowerShell(signToolPath),
    ...signArgs.map((value) => quotePowerShell(value)),
  ];
  return pieces.join(' ');
}

function buildCommandFileContent(javaPath, signToolPath, signArgs, extension) {
  if (extension === '.cmd' || extension === '.bat') {
    const cmdArgs = ['-jar', signToolPath, ...signArgs].map((value) => `"${String(value).replace(/"/g, '""')}"`);
    return `@echo off\r\n"${javaPath}" ${cmdArgs.join(' ')}\r\n`;
  }

  const lines = [
    `& ${quotePowerShell(javaPath)} -jar ${quotePowerShell(signToolPath)} \\`,
  ];
  for (let index = 0; index < signArgs.length; index += 1) {
    const suffix = index === signArgs.length - 1 ? '' : ' `';
    lines.push(`  ${quotePowerShell(signArgs[index])}${suffix}`);
  }
  return `${lines.join('\r\n')}\r\n`;
}

function maskValue(value, showSecrets) {
  return showSecrets ? value : '<hidden>';
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const scriptDir = __dirname;
  const projectRoot = path.resolve(args.project || path.resolve(scriptDir, '..'));
  const buildProfilePath = path.resolve(args.buildProfile || path.join(projectRoot, 'build-profile.json5'));
  if (!fs.existsSync(buildProfilePath)) {
    fail(`build-profile.json5 was not found: ${buildProfilePath}`);
  }

  const localProperties = readLocalProperties(path.join(projectRoot, 'local.properties'));
  const buildProfile = readJsonFile(buildProfilePath);
  const { product, signingConfig } = getSigningConfig(buildProfile, args.product);
  const material = { ...signingConfig.material };
  const baseDir = path.dirname(buildProfilePath);
  material.storeFile = resolveConfigPath(baseDir, material.storeFile);
  material.certpath = resolveConfigPath(baseDir, material.certpath);
  material.profile = resolveConfigPath(baseDir, material.profile);

  const storePassword = decryptPassword(material.storeFile, material.storePassword, 'storePassword');
  const keyPassword = decryptPassword(material.storeFile, material.keyPassword, 'keyPassword');
  const signToolPath = resolveSignTool(args, localProperties);
  const javaPath = resolveJavaExecutable(args);

  const signArgs = [
    'sign-app',
    '-mode', 'localSign',
    '-keyAlias', material.keyAlias,
    '-keyPwd', keyPassword,
    '-keystoreFile', material.storeFile,
    '-keystorePwd', storePassword,
    '-appCertFile', material.certpath,
    '-profileFile', material.profile,
    '-signAlg', material.signAlg,
  ];

  let inputPath = null;
  let outputPath = null;
  if (args.input) {
    inputPath = path.resolve(args.input);
    if (!fs.existsSync(inputPath)) {
      fail(`Input HAP was not found: ${inputPath}`);
    }
    outputPath = path.resolve(args.output || inputPath.replace(/\.hap$/i, '-manual-signed.hap'));
    signArgs.push('-inFile', inputPath, '-outFile', outputPath);
  } else if (args.output) {
    fail('--output requires --input');
  }

  const redactedSignArgs = signArgs.map((value, index) => {
    const previous = signArgs[index - 1];
    if (previous === '-keyPwd' || previous === '-keystorePwd') {
      return maskValue(value, args.showSecrets);
    }
    return value;
  });

  console.log(`Project root: ${projectRoot}`);
  console.log(`Build profile: ${buildProfilePath}`);
  console.log(`Product: ${product.name}`);
  console.log(`Signing config: ${signingConfig.name}`);
  console.log(`Signing type: ${signingConfig.type || 'OpenHarmony'}`);
  console.log(`Store file: ${material.storeFile}`);
  console.log(`Cert file: ${material.certpath}`);
  console.log(`Profile file: ${material.profile}`);
  console.log(`Sign tool: ${signToolPath}`);
  if (inputPath) {
    console.log(`Input HAP: ${inputPath}`);
    console.log(`Output HAP: ${outputPath}`);
  }
  console.log('DevEco-equivalent signing command:');
  console.log(buildPowerShellCommand(javaPath, signToolPath, redactedSignArgs));

  if (args.writeCommand) {
    const commandPath = path.resolve(args.writeCommand);
    const content = buildCommandFileContent(
      javaPath,
      signToolPath,
      signArgs,
      path.extname(commandPath).toLowerCase(),
    );
    fs.mkdirSync(path.dirname(commandPath), { recursive: true });
    fs.writeFileSync(commandPath, content, 'utf8');
    console.log(`Command file written to: ${commandPath}`);
  }

  if (args.execute) {
    if (!inputPath || !outputPath) {
      fail('--execute requires --input');
    }
    const result = childProcess.spawnSync(
      javaPath,
      ['-jar', signToolPath, ...signArgs],
      { stdio: 'inherit' },
    );
    if (result.status !== 0) {
      process.exit(result.status || 1);
    }
    console.log(`Signed HAP written to: ${outputPath}`);
  }
}

main();
