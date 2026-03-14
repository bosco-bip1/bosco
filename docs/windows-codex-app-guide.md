# 在 Windows 上生成（搭建）Codex 应用指南

> 适用对象：希望在 Windows 机器上快速跑起来一个基于 Codex 的命令行应用/项目脚手架。

## 1. 前置准备

1. 安装 **Git for Windows**（包含 Git Bash）。
2. 安装 **Node.js LTS**（建议 20+）。
3. 准备 OpenAI API Key（例如设置为 `OPENAI_API_KEY`）。

## 2. 建议环境

优先使用以下两种方式之一：

- **WSL2 + Ubuntu**（推荐，兼容性更好）
- **PowerShell / Git Bash**（可用，但部分脚本兼容性稍弱）

## 3. 创建项目

在 PowerShell 或 WSL 中执行：

```bash
mkdir my-codex-app
cd my-codex-app
npm init -y
```

安装常用依赖：

```bash
npm install openai dotenv
```

## 4. 配置环境变量

在项目根目录新建 `.env`：

```env
OPENAI_API_KEY=你的key
```

> Windows 临时设置（PowerShell）也可用：
>
> ```powershell
> $env:OPENAI_API_KEY="你的key"
> ```

## 5. 最小可运行示例

新建 `index.mjs`：

```js
import OpenAI from "openai";
import "dotenv/config";

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const resp = await client.responses.create({
  model: "gpt-4.1-mini",
  input: "请给我一个 Windows 下可执行的 hello world Node.js 示例。"
});

console.log(resp.output_text);
```

运行：

```bash
node index.mjs
```

## 6. 常见问题（Windows）

- **命令找不到 (`node` / `npm`)**：重开终端，确认 PATH 生效。
- **权限问题**：用普通用户终端即可，不建议全程管理员权限。
- **代理/公司网络**：若访问 API 失败，先检查网络与证书策略。
- **换行符问题**：建议启用 Git 的自动行尾处理，避免脚本在不同终端报错。

## 7. 下一步（把脚本变成“应用”）

- 增加命令行参数（例如读取 prompt 文件）。
- 封装为可复用函数（`src/` 目录结构）。
- 配置 `npm scripts`（如 `dev`, `start`, `lint`）。
- 需要图形界面时可接入 Electron 或 Web 前端。

---

如果你希望，我可以基于这份指南继续给你生成一个完整可运行的 Windows 版模板（含目录结构、脚本、错误处理和打包命令）。
