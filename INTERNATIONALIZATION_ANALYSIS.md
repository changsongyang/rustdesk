# 国际化实现分析报告

## 1. 现有国际化实现

### 1.1 核心实现架构

RustDesk 采用了混合国际化架构：

- **Flutter 端**：使用自定义的 `translate()` 函数，通过 `platformFFI.translate()` 调用底层 Rust 实现的国际化逻辑
- **Android 端**：使用标准的 Android 字符串资源系统
- **Web 端**：使用 `window.navigator.language` 获取语言

### 1.2 支持的语言

从 `common.dart` 中可以看到，应用支持以下语言：
- 英语 (en_US)
- 简体中文 (zh_CN)
- 繁体中文 (zh_TW)
- 新加坡中文 (zh_SG)
- 法语 (fr)
- 德语 (de)
- 意大利语 (it)
- 日语 (ja)
- 捷克语 (cs)
- 波兰语 (pl)
- 韩语 (ko)
- 匈牙利语 (hu)
- 葡萄牙语 (pt)
- 俄语 (ru)
- 斯洛伐克语 (sk)
- 印尼语 (id)
- 丹麦语 (da)
- 世界语 (eo)
- 土耳其语 (tr)

### 1.3 现有问题

1. **Android 端语言支持不完整**：
   - 仅在 `values/strings.xml` 中提供了英文资源
   - 缺少其他语言的资源文件

2. **字符串资源管理分散**：
   - Flutter 端通过 Rust 实现国际化
   - Android 端使用标准 Android 资源系统
   - 两者之间存在重复和不一致的风险

3. **缺少语言切换机制**：
   - 未在应用内提供语言切换选项
   - 完全依赖系统语言设置

## 2. 已完成的改进

### 2.1 新增中文语言资源

已为 Android 端添加了完整的中文语言资源：
- 文件：`flutter/android/app/src/main/res/values-zh/strings.xml`
- 包含所有权限管理和安全审计相关的字符串
- 与英文资源保持结构一致

### 2.2 统一字符串资源使用

已确保 `PermissionManager.kt` 和 `SecurityAuditor.kt` 正确使用字符串资源：
- 替换了所有硬编码字符串
- 使用 `activity.getString(R.string.*)` 引用资源
- 确保日志消息使用英文（便于调试）

## 3. 建议的后续优化

### 3.1 完善 Android 语言支持

1. **添加更多语言资源**：
   - 为所有支持的语言创建对应的 `values-<lang>/strings.xml` 文件
   - 确保翻译质量和一致性

2. **实现语言切换功能**：
   - 在应用设置中添加语言选择选项
   - 确保 Android 端和 Flutter 端语言同步

### 3.2 优化国际化架构

1. **统一字符串资源管理**：
   - 考虑使用 Flutter 的 `intl` 包管理所有字符串
   - 或建立统一的字符串资源同步机制

2. **改进语言检测**：
   - 增强语言检测逻辑，支持更多地区变体
   - 提供语言回退机制

### 3.3 最佳实践建议

1. **字符串资源命名规范**：
   - 使用语义化的资源名称
   - 按照功能模块组织资源

2. **翻译质量保证**：
   - 请专业翻译人员审核翻译
   - 考虑使用翻译管理工具

3. **测试策略**：
   - 为每种支持的语言进行界面测试
   - 确保文本在不同语言下的布局正常

## 4. 技术实现细节

### 4.1 Flutter 端国际化流程

```dart
// 调用流程
String translate(String name) {
  if (name.startsWith('Failed to') && name.contains(': ')) {
    return name.split(': ').map((x) => translate(x)).join(': ');
  }
  return platformFFI.translate(name, localeName);
}

// 语言检测
// web端: window.navigator.language
// 原生端: Platform.localeName
```

### 4.2 Android 端国际化流程

```kotlin
// 使用字符串资源
val title = activity.getString(R.string.permission_audio_title)

// 系统自动根据设备语言选择对应资源文件
// values/strings.xml (默认，英文)
// values-zh/strings.xml (中文)
// values-fr/strings.xml (法语)
```

## 5. 结论

RustDesk 已经具备基本的国际化能力，但在 Android 端的语言支持和整体架构一致性方面仍有提升空间。通过本次改进，已为 Android 端添加了完整的中文支持，并统一了字符串资源的使用方式。

建议按照上述优化建议进一步完善国际化实现，以提供更好的多语言用户体验。