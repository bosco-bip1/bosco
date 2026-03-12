# 如何写一个“下载 X 视频”的浏览器插件（学习版）

> 仅用于下载你有权保存的内容（例如你自己的视频、已授权素材）。请遵守 X 平台条款与当地法律。

## 1. 目标

做一个最小可用的 Chrome/Edge 插件，在 X 视频播放页面上：

1. 识别页面里可下载的视频直链（常见为 `.mp4`）。
2. 提供一个“下载视频”按钮。
3. 点击后通过浏览器下载 API 保存文件。

---

## 2. 目录结构

```txt
x-video-downloader/
├─ manifest.json
├─ content.js
├─ background.js
└─ icons/
   └─ icon128.png   （可选）
```

---

## 3. 插件代码

### 3.1 `manifest.json`

```json
{
  "manifest_version": 3,
  "name": "X Video Downloader (Learning)",
  "version": "0.1.0",
  "description": "Detect and download playable MP4 resources on X pages.",
  "permissions": ["downloads", "scripting", "activeTab"],
  "host_permissions": [
    "https://x.com/*",
    "https://twitter.com/*"
  ],
  "background": {
    "service_worker": "background.js"
  },
  "content_scripts": [
    {
      "matches": ["https://x.com/*", "https://twitter.com/*"],
      "js": ["content.js"],
      "run_at": "document_idle"
    }
  ]
}
```

### 3.2 `background.js`

```js
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg?.type === "DOWNLOAD" && msg.url) {
    chrome.downloads.download(
      {
        url: msg.url,
        filename: msg.filename || `x-video-${Date.now()}.mp4`,
        saveAs: true
      },
      (downloadId) => {
        if (chrome.runtime.lastError) {
          sendResponse({ ok: false, error: chrome.runtime.lastError.message });
        } else {
          sendResponse({ ok: true, downloadId });
        }
      }
    );
    return true;
  }
});
```

### 3.3 `content.js`

```js
(function () {
  const BTN_ID = "x-video-download-btn";

  function findMp4Url() {
    const videos = Array.from(document.querySelectorAll("video"));

    for (const v of videos) {
      const src = v.currentSrc || v.src;
      if (src && src.includes(".mp4")) return src;

      const source = v.querySelector("source");
      if (source?.src && source.src.includes(".mp4")) return source.src;
    }

    // 兜底：扫描页面脚本文本中的 mp4
    const html = document.documentElement.innerHTML;
    const m = html.match(/https:\\/\\/[^"'\\s]+\\.mp4[^"'\\s]*/i);
    return m ? m[0].replace(/\\u0026/g, "&") : null;
  }

  function ensureButton() {
    if (document.getElementById(BTN_ID)) return;

    const btn = document.createElement("button");
    btn.id = BTN_ID;
    btn.textContent = "下载视频";
    Object.assign(btn.style, {
      position: "fixed",
      right: "16px",
      bottom: "16px",
      zIndex: "999999",
      padding: "10px 14px",
      border: "none",
      borderRadius: "8px",
      cursor: "pointer",
      background: "#1d9bf0",
      color: "#fff",
      fontSize: "14px"
    });

    btn.onclick = () => {
      const url = findMp4Url();
      if (!url) {
        alert("未找到可直接下载的视频链接（可能是分段流或受限内容）");
        return;
      }

      chrome.runtime.sendMessage(
        {
          type: "DOWNLOAD",
          url,
          filename: `x-video-${Date.now()}.mp4`
        },
        (resp) => {
          if (!resp?.ok) {
            alert(`下载失败：${resp?.error || "未知错误"}`);
          }
        }
      );
    };

    document.body.appendChild(btn);
  }

  const observer = new MutationObserver(() => ensureButton());
  observer.observe(document.documentElement, { childList: true, subtree: true });
  ensureButton();
})();
```

---

## 4. 安装与调试

1. 新建文件夹 `x-video-downloader`，把上面 3 个文件放进去。
2. 打开 Chrome/Edge：`扩展程序` → `管理扩展程序`。
3. 打开右上角 `开发者模式`。
4. 点 `加载已解压的扩展程序`，选择该文件夹。
5. 打开一个 X 视频页面，右下角会出现“下载视频”按钮。

---

## 5. 常见问题

1. **找不到 MP4 链接**：很多视频是 HLS (`.m3u8`) 分段播放，不一定有直链 mp4。
2. **下载失败/403**：请求可能依赖登录态、Referer 或短时签名参数。
3. **页面改版后失效**：X 的 DOM 和数据结构会变，需更新选择器或解析逻辑。

---

## 6. 可改进方向

- 支持抓取 `.m3u8` 并提示“使用 ffmpeg 合并”。
- 提供多清晰度选择（如果能识别多码率流）。
- 加入开关：仅在视频详情页展示按钮。
- 增加失败日志面板，方便排查。

---

## 7. 合规提示

- 不要绕过付费、版权保护或访问控制。
- 不要批量抓取、传播他人受版权保护内容。
- 仅在你拥有许可的情况下下载与使用视频。
