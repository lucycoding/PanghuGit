# Security Policy

[English](./SECURITY.en.md) | 中文

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.1.x   | ✅ |
| 1.0.x   | ❌ |
| < 1.0   | ❌ |

## Reporting a Vulnerability

**请不要通过 GitHub Issue 报告安全漏洞。**

如果你发现了安全漏洞，请通过以下方式私密报告：

- **GitHub Security Advisory**：使用 [Security Advisories](https://github.com/lucycoding/PanghuGit/security/advisories/new) 提交
- **GitHub Issue**：创建 [Private Issue](https://github.com/lucycoding/PanghuGit/issues/new?template=bug_report.yml)，标题标注 `[Security]`

### 报告内容

请包含以下信息：

1. 漏洞类型（如：代码执行、信息泄露、权限提升）
2. 影响的版本
3. 复现步骤
4. 潜在影响
5. 如有可能，提供修复建议

### 响应时间

- **确认收到**：48 小时内
- **初步评估**：7 天内
- **修复发布**：根据严重程度，通常在 30 天内

### 披露政策

- 修复发布前请勿公开披露漏洞细节
- 我们会在修复发布后致谢报告者（除非你要求匿名）

## 安全架构

PanghuGit 的安全设计要点：

- **Finder Sync 扩展运行在沙盒中**，无法直接执行 Git 命令或访问文件系统
- **主 App 非沙盒**（Git 操作需要），但仅通过 `panghugit://` URL Scheme 接收扩展请求
- **App Group 通信**仅共享设置数据，不传输敏感信息
- **Git 凭证**由 git 自身管理（credential.helper），PanghuGit 不存储或处理密码
- **无网络服务**：PanghuGit 不开启任何网络端口或服务
