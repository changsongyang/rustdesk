use std::{
    env, fs,
    path::{Path, PathBuf},
    println,
};

#[cfg(all(target_os = "linux", feature = "linux-pkg-config"))]
fn link_pkg_config(name: &str) -> Vec<PathBuf> {
    // sometimes an override is needed
    let pc_name = match name {
        "libvpx" => "vpx",
        _ => name,
    };
    let lib = pkg_config::probe_library(pc_name)
        .expect(format!(
            "unable to find '{pc_name}' development headers with pkg-config (feature linux-pkg-config is enabled).
            try installing '{pc_name}-dev' from your system package manager.").as_str());

    lib.include_paths
}
#[cfg(not(all(target_os = "linux", feature = "linux-pkg-config")))]
fn link_pkg_config(_name: &str) -> Vec<PathBuf> {
    unimplemented!()
}

/// Link vcpkg package.
fn link_vcpkg(mut path: PathBuf, name: &str) -> PathBuf {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    let mut target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    if target_arch == "x86_64" {
        target_arch = "x64".to_owned();
    } else if target_arch == "x86" {
        target_arch = "x86".to_owned();
    } else if target_arch == "loongarch64" {
        target_arch = "loongarch64".to_owned();
    } else if target_arch == "aarch64" {
        target_arch = "arm64".to_owned();
    } else {
        target_arch = "arm".to_owned();
    }
    let mut target = if target_os == "macos" {
        if target_arch == "x64" {
            "x64-osx".to_owned()
        } else if target_arch == "arm64" {
            "arm64-osx".to_owned()
        } else {
            format!("{}-{}", target_arch, target_os)
        }
    } else if target_os == "windows" {
        "x64-windows-static".to_owned()
    } else {
        format!("{}-{}", target_arch, target_os)
    };
    if target_arch == "x86" {
        target = target.replace("x64", "x86");
    }
    println!("cargo:info={}", target);
    if let Ok(vcpkg_root) = std::env::var("VCPKG_INSTALLED_ROOT") {
        path = vcpkg_root.into();
    } else {
        path.push("installed");
    }
    path.push(target);
    println!(
        "cargo:rustc-link-lib=static={}",
        name.trim_start_matches("lib")
    );
    println!(
        "cargo:rustc-link-search={}",
        path.join("lib").to_str().unwrap()
    );
    let include = path.join("include");
    println!("cargo:include={}", include.to_str().unwrap());
    include
}

/// Link homebrew package(for Mac M1).
fn link_homebrew_m1(name: &str) -> PathBuf {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    let target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    if target_os != "macos" || target_arch != "aarch64" {
        panic!("Couldn't find VCPKG_ROOT, also can't fallback to homebrew because it's only for macos aarch64.");
    }
    let mut path = PathBuf::from("/opt/homebrew/Cellar");
    path.push(name);
    let entries = if let Ok(dir) = std::fs::read_dir(&path) {
        dir
    } else {
        panic!("Could not find package in {}. Make sure your homebrew and package {} are all installed.", path.to_str().unwrap(),&name);
    };
    let mut directories = entries
        .into_iter()
        .filter(|x| x.is_ok())
        .map(|x| x.unwrap().path())
        .filter(|x| x.is_dir())
        .collect::<Vec<_>>();
    // Find the newest version.
    directories.sort_unstable();
    if directories.is_empty() {
        panic!(
            "There's no installed version of {} in /opt/homebrew/Cellar",
            name
        );
    }
    path.push(directories.pop().unwrap());
    // Link the library.
    println!(
        "cargo:rustc-link-lib=static={}",
        name.trim_start_matches("lib")
    );
    // Add the library path.
    println!(
        "cargo:rustc-link-search={}",
        path.join("lib").to_str().unwrap()
    );
    // Add the include path.
    let include = path.join("include");
    println!("cargo:include={}", include.to_str().unwrap());
    include
}

/// Find package. By default, it will try to find vcpkg first, then homebrew(currently only for Mac M1).
/// If building for linux and feature "linux-pkg-config" is enabled, will try to use pkg-config
/// unless check fails (e.g. NO_PKG_CONFIG_libyuv=1)
fn find_package(name: &str) -> Vec<PathBuf> {
    let no_pkg_config_var_name = format!("NO_PKG_CONFIG_{name}");
    println!("cargo:rerun-if-env-changed={no_pkg_config_var_name}");
    if cfg!(all(target_os = "linux", feature = "linux-pkg-config"))
        && std::env::var(no_pkg_config_var_name).as_deref() != Ok("1")
    {
        link_pkg_config(name)
    } else if let Ok(vcpkg_root) = std::env::var("VCPKG_ROOT") {
        vec![link_vcpkg(vcpkg_root.into(), name)]
    } else {
        // Try using homebrew
        vec![link_homebrew_m1(name)]
    }
}

fn patch_vpx_bindings(content: &str) -> String {
    use regex::Regex;
    let mut patched = content.to_string();
    
    // Patch vpx_codec_enc_cfg struct using regex
    let vpx_enc_cfg_regex = Regex::new(r"pub struct vpx_codec_enc_cfg \{\s*pub _address: u8,\s*\}").unwrap();
    let vpx_enc_cfg_replacement = "pub struct vpx_codec_enc_cfg {
    pub g_usage: ::std::os::raw::c_uint,
    pub g_threads: ::std::os::raw::c_uint,
    pub g_profile: ::std::os::raw::c_uint,
    pub g_w: ::std::os::raw::c_uint,
    pub g_h: ::std::os::raw::c_uint,
    pub g_bit_depth: ::std::os::raw::c_uint,
    pub g_input_bit_depth: ::std::os::raw::c_uint,
    pub g_timebase: vpx_rational,
    pub g_error_resilient: ::std::os::raw::c_uint,
    pub g_pass: ::std::os::raw::c_int,
    pub g_lag_in_frames: ::std::os::raw::c_uint,
    pub rc_dropframe_thresh: ::std::os::raw::c_uint,
    pub rc_resize_allowed: ::std::os::raw::c_uint,
    pub rc_scaled_width: ::std::os::raw::c_uint,
    pub rc_scaled_height: ::std::os::raw::c_uint,
    pub rc_resize_up_thresh: ::std::os::raw::c_uint,
    pub rc_resize_down_thresh: ::std::os::raw::c_uint,
    pub rc_end_usage: ::std::os::raw::c_int,
    pub rc_twopass_stats_in: vpx_fixed_buf_t,
    pub rc_firstpass_mb_stats_in: vpx_fixed_buf_t,
    pub rc_target_bitrate: ::std::os::raw::c_uint,
    pub rc_min_quantizer: ::std::os::raw::c_uint,
    pub rc_max_quantizer: ::std::os::raw::c_uint,
    pub rc_undershoot_pct: ::std::os::raw::c_uint,
    pub rc_overshoot_pct: ::std::os::raw::c_uint,
    pub rc_buf_sz: ::std::os::raw::c_uint,
    pub rc_buf_initial_sz: ::std::os::raw::c_uint,
    pub rc_buf_optimal_sz: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_bias_pct: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_minsection_pct: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_maxsection_pct: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_corpus_complexity: ::std::os::raw::c_uint,
    pub kf_mode: ::std::os::raw::c_int,
    pub kf_min_dist: ::std::os::raw::c_uint,
    pub kf_max_dist: ::std::os::raw::c_uint,
    pub ss_number_layers: ::std::os::raw::c_uint,
    pub ss_enable_auto_alt_ref: [::std::os::raw::c_int; 4usize],
    pub ss_target_bitrate: [::std::os::raw::c_uint; 4usize],
}";
    
    let before = patched.len();
    patched = vpx_enc_cfg_regex.replace(&patched, vpx_enc_cfg_replacement).to_string();
    let after = patched.len();
    if before != after {
        println!("cargo:warning=VPX enc cfg patched: {} -> {}", before, after);
    }
    
    // Patch vpx_codec_dec_cfg struct using regex
    let vpx_dec_cfg_regex = Regex::new(r"pub struct vpx_codec_dec_cfg \{\s*pub _address: u8,\s*\}").unwrap();
    let vpx_dec_cfg_replacement = "pub struct vpx_codec_dec_cfg {
    pub threads: ::std::os::raw::c_uint,
    pub w: ::std::os::raw::c_uint,
    pub h: ::std::os::raw::c_uint,
}";
    
    let before = patched.len();
    patched = vpx_dec_cfg_regex.replace(&patched, vpx_dec_cfg_replacement).to_string();
    let after = patched.len();
    if before != after {
        println!("cargo:warning=VPX dec cfg patched: {} -> {}", before, after);
    }
    
    patched
}

fn patch_aom_bindings(content: &str) -> String {
    use regex::Regex;
    let mut patched = content.to_string();
    
    // Patch aom_codec_enc_cfg struct using regex
    let aom_enc_cfg_regex = Regex::new(r"pub struct aom_codec_enc_cfg \{\s*pub _address: u8,\s*\}").unwrap();
    let aom_enc_cfg_replacement = "pub struct aom_codec_enc_cfg {
    pub g_usage: ::std::os::raw::c_uint,
    pub g_threads: ::std::os::raw::c_uint,
    pub g_profile: ::std::os::raw::c_uint,
    pub g_w: ::std::os::raw::c_uint,
    pub g_h: ::std::os::raw::c_uint,
    pub g_limit: ::std::os::raw::c_uint,
    pub g_forced_max_frame_width: ::std::os::raw::c_uint,
    pub g_forced_max_frame_height: ::std::os::raw::c_uint,
    pub g_bit_depth: ::std::os::raw::c_uint,
    pub g_input_bit_depth: ::std::os::raw::c_uint,
    pub g_timebase: aom_rational,
    pub g_error_resilient: ::std::os::raw::c_uint,
    pub g_pass: ::std::os::raw::c_int,
    pub g_lag_in_frames: ::std::os::raw::c_uint,
    pub rc_dropframe_thresh: ::std::os::raw::c_uint,
    pub rc_resize_mode: ::std::os::raw::c_uint,
    pub rc_resize_denominator: ::std::os::raw::c_uint,
    pub rc_resize_kf_denominator: ::std::os::raw::c_uint,
    pub rc_superres_mode: ::std::os::raw::c_uint,
    pub rc_superres_denominator: ::std::os::raw::c_uint,
    pub rc_superres_kf_denominator: ::std::os::raw::c_uint,
    pub rc_end_usage: ::std::os::raw::c_int,
    pub rc_twopass_stats_in: aom_fixed_buf_t,
    pub rc_target_bitrate: ::std::os::raw::c_uint,
    pub rc_min_quantizer: ::std::os::raw::c_uint,
    pub rc_max_quantizer: ::std::os::raw::c_uint,
    pub rc_undershoot_pct: ::std::os::raw::c_uint,
    pub rc_overshoot_pct: ::std::os::raw::c_uint,
    pub rc_buf_sz: ::std::os::raw::c_uint,
    pub rc_buf_initial_sz: ::std::os::raw::c_uint,
    pub rc_buf_optimal_sz: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_bias_pct: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_minsection_pct: ::std::os::raw::c_uint,
    pub rc_2pass_vbr_maxsection_pct: ::std::os::raw::c_uint,
    pub kf_mode: ::std::os::raw::c_int,
    pub kf_min_dist: ::std::os::raw::c_uint,
    pub kf_max_dist: ::std::os::raw::c_uint,
}";
    
    let before = patched.len();
    patched = aom_enc_cfg_regex.replace(&patched, aom_enc_cfg_replacement).to_string();
    let after = patched.len();
    if before != after {
        println!("cargo:warning=AOM enc cfg patched: {} -> {}", before, after);
    }
    
    // Patch aom_codec_dec_cfg struct using regex
    let aom_dec_cfg_regex = Regex::new(r"pub struct aom_codec_dec_cfg \{\s*pub _address: u8,\s*\}").unwrap();
    let aom_dec_cfg_replacement = "pub struct aom_codec_dec_cfg {
    pub threads: ::std::os::raw::c_uint,
    pub w: ::std::os::raw::c_uint,
    pub h: ::std::os::raw::c_uint,
    pub allow_lowbitdepth: ::std::os::raw::c_uint,
}";
    
    let before = patched.len();
    patched = aom_dec_cfg_regex.replace(&patched, aom_dec_cfg_replacement).to_string();
    let after = patched.len();
    if before != after {
        println!("cargo:warning=AOM dec cfg patched: {} -> {}", before, after);
    }
    
    patched
}

fn generate_bindings(
    ffi_header: &Path,
    include_paths: &[PathBuf],
    ffi_rs: &Path,
    exact_file: &Path,
    regex: &str,
) {
    let mut b = bindgen::builder()
        .header(ffi_header.to_str().unwrap())
        .allowlist_type(regex)
        .allowlist_var(regex)
        .allowlist_function(regex)
        .rustified_enum(regex)
        .trust_clang_mangling(false)
        .layout_tests(false) // breaks 32/64-bit compat
        .generate_comments(false); // comments have prefix /*!\

    for dir in include_paths {
        b = b.clang_arg(format!("-I{}", dir.display()));
    }

    let bindings = b.generate().unwrap();
    
    // Write to OUT_DIR
    bindings.write_to_file(ffi_rs).unwrap();
    
    // Read the generated content
    let content = fs::read_to_string(ffi_rs).unwrap();
    
    // Apply patches based on file name
    let patched_content = if ffi_rs.file_name().unwrap_or_default().to_str().unwrap_or_default() == "vpx_ffi.rs" {
        println!("cargo:warning=Patching vpx bindings");
        patch_vpx_bindings(&content)
    } else if ffi_rs.file_name().unwrap_or_default().to_str().unwrap_or_default() == "aom_ffi.rs" {
        println!("cargo:warning=Patching aom bindings");
        patch_aom_bindings(&content)
    } else {
        content
    };
    
    // Write patched content
    fs::write(ffi_rs, patched_content).unwrap();
    
    // Copy to exact_file (generated/ directory)
    if let Some(parent) = exact_file.parent() {
        fs::create_dir_all(parent).ok();
    }
    fs::copy(ffi_rs, exact_file).ok(); // ignore failure
}

fn gen_vcpkg_package(package: &str, ffi_header: &str, generated: &str, regex: &str) {
    let includes = find_package(package);
    let src_dir = env::var_os("CARGO_MANIFEST_DIR").unwrap();
    let src_dir = Path::new(&src_dir);
    let out_dir = env::var_os("OUT_DIR").unwrap();
    let out_dir = Path::new(&out_dir);

    let ffi_header = src_dir.join("src").join("bindings").join(ffi_header);
    println!("rerun-if-changed={}", ffi_header.display());
    for dir in &includes {
        println!("rerun-if-changed={}", dir.display());
    }

    let ffi_rs = out_dir.join(generated);
    let exact_file = src_dir.join("generated").join(generated);
    generate_bindings(&ffi_header, &includes, &ffi_rs, &exact_file, regex);
}

// If you have problems installing ffmpeg, you can download $VCPKG_ROOT/installed from ci
// Linux require link in hwcodec
/*
fn ffmpeg() {
    // ffmpeg
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    let target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    let static_libs = vec!["avcodec", "avutil", "avformat"];
    static_libs.iter().for_each(|lib| {
        find_package(lib);
    });
    if target_os == "windows" {
        println!("cargo:rustc-link-lib=static=libmfx");
    }

    // os
    let dyn_libs: Vec<&str> = if target_os == "windows" {
        ["User32", "bcrypt", "ole32", "advapi32"].to_vec()
    } else if target_os == "linux" {
        let mut v = ["va", "va-drm", "va-x11", "vdpau", "X11", "stdc++"].to_vec();
        if target_arch == "x86_64" {
            v.push("z");
        }
        v
    } else if target_os == "macos" || target_os == "ios" {
        ["c++", "m"].to_vec()
    } else if target_os == "android" {
        ["z", "m", "android", "atomic"].to_vec()
    } else {
        panic!("unsupported os");
    };
    dyn_libs
        .iter()
        .map(|lib| println!("cargo:rustc-link-lib={}", lib))
        .count();

    if target_os == "macos" || target_os == "ios" {
        println!("cargo:rustc-link-lib=framework=CoreFoundation");
        println!("cargo:rustc-link-lib=framework=CoreVideo");
        println!("cargo:rustc-link-lib=framework=CoreMedia");
        println!("cargo:rustc-link-lib=framework=VideoToolbox");
        println!("cargo:rustc-link-lib=framework=AVFoundation");
    }
}
*/

fn main() {
    // in this crate, these are also valid configurations
    println!("cargo:rustc-check-cfg=cfg(dxgi,quartz,x11)");

    // there is problem with cfg(target_os) in build.rs, so use our workaround
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();

    // note: all link symbol names in x86 (32-bit) are prefixed wth "_".
    // run "rustup show" to show current default toolchain, if it is stable-x86-pc-windows-msvc,
    // please install x64 toolchain by "rustup toolchain install stable-x86_64-pc-windows-msvc",
    // then set x64 to default by "rustup default stable-x86_64-pc-windows-msvc"
    let target = target_build_utils::TargetInfo::new();
    if target.unwrap().target_pointer_width() != "64" {
        // panic!("Only support 64bit system");
    }
    env::remove_var("CARGO_CFG_TARGET_FEATURE");
    env::set_var("CARGO_CFG_TARGET_FEATURE", "crt-static");

    find_package("libyuv");
    gen_vcpkg_package("libvpx", "vpx_ffi.h", "vpx_ffi.rs", "^[vV].*");
    gen_vcpkg_package("aom", "aom_ffi.h", "aom_ffi.rs", "^(aom|AOM|OBU|AV1).*");
    gen_vcpkg_package("libyuv", "yuv_ffi.h", "yuv_ffi.rs", ".*");
    // ffmpeg();

    if target_os == "ios" {
        // nothing
    } else if target_os == "android" {
        println!("cargo:rustc-cfg=android");
    } else if cfg!(windows) {
        // The first choice is Windows because DXGI is amazing.
        println!("cargo:rustc-cfg=dxgi");
    } else if cfg!(target_os = "macos") {
        // Quartz is second because macOS is the (annoying) exception.
        println!("cargo:rustc-cfg=quartz");
    } else if cfg!(unix) {
        // On UNIX we pray that X11 (with XCB) is available.
        println!("cargo:rustc-cfg=x11");
    }
}
