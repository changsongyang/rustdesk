# RustDesk CI/CD 工作流审查 - 验证清单

## 验证检查点

- [x] Checkpoint 1: macOS 构建任务中 vcpkg 缓存配置已取消注释
- [x] Checkpoint 2: 所有工作流都使用 actions/github-script@v7
- [x] Checkpoint 3: 所有工作流都使用 Swatinem/rust-cache@v2
- [x] Checkpoint 4: 所有工作流都使用 lukka/run-vcpkg@v11
- [x] Checkpoint 5: 所有 vcpkg 配置都设置 doNotCache=false
- [x] Checkpoint 6: GitHub Actions 缓存环境变量导出步骤在所有工作流中存在
- [x] Checkpoint 7: 缓存配置步骤在依赖安装和构建之前执行
- [x] Checkpoint 8: 所有 YAML 文件语法正确
- [x] Checkpoint 9: 工作流之间的配置一致性得到保持
- [x] Checkpoint 10: Rust 版本在相关工作流中保持一致（1.75）
- [x] Checkpoint 11: vcpkgGitCommitId 与环境变量 VCPKG_COMMIT_ID 一致
- [x] Checkpoint 12: 没有引入新的语法错误或格式问题
- [x] Checkpoint 13: 所有修改都是最小化且针对性的
- [x] Checkpoint 14: 没有破坏现有的功能逻辑
