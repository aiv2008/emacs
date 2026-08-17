# Emacs 配置

同一份配置给 **Linux（WSL）** 和 **macOS**。

```bash
mv ~/.emacs.d ~/.emacs.d.bak   # 已有配置先备份
git clone --recurse-submodules git@github.com:aiv2008/emacs.git ~/.emacs.d
```

漏了 submodule 时再执行：

```bash
cd ~/.emacs.d && git submodule update --init --recursive
```

- 终端 Emacs（Ghostty）：字体改 `~/.config/ghostty/config` 的 `font-size`
- 图形 Emacs：改 `init.el` 里的 `my/font-size`（Mac 需安装 Maple Mono NF）
- 第一次开 vterm：macOS 上先 `brew install libvterm cmake`
- API 密钥不要写进 `init.el`，用环境变量 `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`

改完 `init.el` 后 `M-x eval-buffer` 或重启 Emacs。

## 快捷键

`C` = Ctrl，`M` = Alt（Mac 上是 Option），`S` = Shift。

### 编辑

| 键 | 作用 |
|---|---|
| `C-z` | 撤销 |
| `F3` | 搜索下一个 |
| `S-F3` | 搜索上一个 |
| `C-c k` | 关掉当前 buffer（不询问） |
| `C-x k` | 关掉 buffer（会询问名字） |
| `C-S-k` | 删除整行 |
| `M-;` | 注释 / 取消注释 |

### 补全（Company 弹出菜单时）

| 键 | 作用 |
|---|---|
| `C-n` / `C-p` | 下一个 / 上一个候选 |
| `Tab` | 确认补全 |
| `M-/` | 手动弹出补全（Lean） |

### 跳转（TS / JS / TSX / Lean）

| 键 | 作用 |
|---|---|
| `M-.` | 跳到定义 |
| `M-?` | 查找引用 |
| `M-,` | 跳回上一处 |

### Lean 4

| 键 | 作用 |
|---|---|
| `C-c C-g` | 打开 / 关闭 infoview |

### 文件树 / 终端

| 键 | 作用 |
|---|---|
| `C-x t t` | 打开 / 关闭 Treemacs |
| `C-x t r` | 刷新 Treemacs |
| `C-x t p` | Treemacs 添加工程 |
| `C-x v` | 打开 vterm |

### Git（Magit）

| 键 | 作用 |
|---|---|
| `C-x g` | 仓库状态 |
| `C-x M-g` | Magit 命令菜单 |
| `C-c M-g` | 当前文件：blame / log / diff |

状态缓冲里：

| 键 | 作用 |
|---|---|
| `s` | stage |
| `u` | unstage |
| `c c` | 写说明并提交 |
| `P p` | 推送 |
| `F p` | 拉取 |
| `b b` | 切分支 |
| `k` | 丢弃改动（需确认） |
| `q` | 退出 |

### AI

Claude Code 使用本机 `claude` CLI（需已登录）。

| 键 | 作用 |
|---|---|
| `C-c c c` | 在工程根目录启动 Claude |
| `C-c c t` | 显示 / 隐藏 Claude 窗口 |
| `C-c c r` | 把选区发给 Claude |
| `C-c g` | 打开 gptel 聊天 |
| `C-c RET` | gptel 发送（可选中区域） |
| `C-u C-c RET` | gptel 选模型 / 后端 |

终端里 `C-c RET` 等价于 `C-c C-m`。
