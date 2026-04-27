#![cfg(test)]

use hbb_common::config::*;

#[test]
fn test_config_loading() {
    // 测试配置加载功能
    let config = Config::new();
    assert!(config.is_ok());
}

#[test]
fn test_settings_config() {
    // 测试设置配置
    let config = Config::new().unwrap();
    let settings = config.get_settings();
    assert!(settings.is_ok());
}

#[test]
fn test_local_config() {
    // 测试本地配置
    let config = Config::new().unwrap();
    let local = config.get_local();
    assert!(local.is_ok());
}

#[test]
fn test_display_config() {
    // 测试显示配置
    let config = Config::new().unwrap();
    let display = config.get_display();
    assert!(display.is_ok());
}