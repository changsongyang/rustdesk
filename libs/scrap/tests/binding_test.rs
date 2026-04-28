//! 测试 FFI 绑定修补机制

#[cfg(target_os = "windows")]
#[test]
fn test_aom_bindings_patched() {
    use scrap::aom::{aom_codec_enc_cfg, aom_codec_dec_cfg};
    
    // 测试 aom_codec_enc_cfg 结构体字段访问
    let mut enc_cfg: aom_codec_enc_cfg = unsafe { std::mem::zeroed() };
    enc_cfg.g_w = 1920;
    enc_cfg.g_h = 1080;
    enc_cfg.g_threads = 4;
    enc_cfg.rc_target_bitrate = 5000000;
    
    // 测试 aom_codec_dec_cfg 结构体字段访问
    let mut dec_cfg: aom_codec_dec_cfg = unsafe { std::mem::zeroed() };
    dec_cfg.threads = 4;
    dec_cfg.w = 1920;
    dec_cfg.h = 1080;
    dec_cfg.allow_lowbitdepth = 1;
    
    // 验证字段值是否正确设置
    assert_eq!(enc_cfg.g_w, 1920);
    assert_eq!(enc_cfg.g_h, 1080);
    assert_eq!(enc_cfg.g_threads, 4);
    assert_eq!(enc_cfg.rc_target_bitrate, 5000000);
    
    assert_eq!(dec_cfg.threads, 4);
    assert_eq!(dec_cfg.w, 1920);
    assert_eq!(dec_cfg.h, 1080);
    assert_eq!(dec_cfg.allow_lowbitdepth, 1);
    
    println!("AOM bindings test passed");
}
