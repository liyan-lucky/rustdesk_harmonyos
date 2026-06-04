fn main() {
    let target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    let target_env = std::env::var("CARGO_CFG_TARGET_ENV").unwrap_or_default();
    if target_arch == "aarch64" && target_env == "ohos" {
        println!("cargo:rustc-link-arg=-Wl,-z,notext");
    }
}
