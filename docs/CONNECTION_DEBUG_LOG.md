# Connection Debug Log

> Current focused record for connection and video-stream verification. Keep this file updated when device-side behavior is tested.

## 2026-06-13 core-70 verification

- Core source: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-70`
- Core asset: `librustdesk_core.a`, `131,263,476` bytes, SHA256 `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`
- Core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27459455573`, conclusion `success`
- App HAP build: version `0.13.40`, signed HAP `18,746,449` bytes, SHA256 `A927DA8F54806F0AA53AEAD16575016AE6F535B8AED5FCA537AD7F219E35F070`
- HAP verification: native libraries and signature passed with `scripts\verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs`
- Device target: `192.168.11.100:36169`
- Install result: `install bundle successfully`
- Launch result: blocked by lock screen, `Error Code:10106102`
- Package state from `bm dump -n com.open.rundesk`: installed `versionName=0.13.40`, `versionCode=1000071`, native library path `entry/libs/arm64`
- Process state: `pidof com.open.rundesk` returned no process after the blocked launch
- Hilog capture: `reports/hilog_latest_after_core70.txt`; no `coreReady`, `session-connected`, `video-frame`, panic, crash, or RustDesk runtime evidence because the app did not start

## Current conclusion

The core-70 artifact and HAP packaging path are valid. The remaining connection/video-stream check is blocked by device lock screen, not by build or install failure. After unlocking the device, rerun launch/install and validate `coreReady=true`, `session-connected`, `peer-info`, `video-refresh-requested`, and `video-frame`.

## Online app build status

- Latest app release: `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/harmonyos-20260612-065038`
- Latest app workflow run checked: `https://github.com/liyan-lucky/rustdesk_harmonyos/actions/runs/27443845710`
- Run state: failed on old commit `0000da60074323447862ac75774b6ebe26a95ea3`; it does not include the locally verified core-70 and staged-signing/HAP-only updates
- Required next online verification: push current app changes, trigger `Build HarmonyOS HAP Linux`, confirm artifact/release contains only `.hap`
