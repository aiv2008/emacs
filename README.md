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
- AI 走 [CodeRelay](https://coderelay.cn) 中转。密钥不要写进 `init.el`：

```bash
# 控制台复制 API Key 后：
export CODERELAY_API_KEY="sk-..."    # 写进 ~/.zshrc 后重新开终端
# 或：mkdir -p ~/.config/coderelay && 把 key 单独一行写入 ~/.config/coderelay/api-key
```

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

### 跳转（TS / JS / TSX / Vue / Python / Rust / Lean）

| 键 | 作用 |
|---|---|
| `M-.` | 跳到定义（Rust 里连标准库源码一起跳，需 `rust-src`） |
| `M-?` | 查找引用 |
| `M-,` | 跳回上一处 |

### Rust

| 键 | 作用 |
|---|---|
| `M-.` / `M-?` / `M-,` | 定义 / 引用 / 跳回 |
| `C-c r d` | 环境自检（`my/rust-doctor`：工具链、服务器、主模式、工程根） |
| `C-c r r` | 重启 rust-analyzer（改过 `Cargo.toml` 就用它） |
| `C-c r c` | 在工程根跑 `cargo check` |

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

## 换新电脑：环境清单

配置 clone 下来就能用，**语言服务器不在仓库里，要另外装**。装完重启 Emacs 即可，不用改配置。

| 语言 | 装什么 | 命令 |
|---|---|---|
| TS / JS / Vue 2 | typescript-language-server + Volar 2.2.x | `npm i -g typescript-language-server @vue/language-server@2.2.10 typescript` |
| Solidity | Nomic 官方 server（**必须带 `--stdio`**，init.el 里已写好） | `npm i -g @nomicfoundation/solidity-language-server` |
| Python | `pylsp`（jedi 后端） | 见下 |
| Lean 4 | `lake serve`（elan 装的 lean 自带） | init.el 会自动 clone `lean4-mode` |
| Rust | rust-analyzer + rust-src（都是 rustup 组件） | `rustup component add rust-analyzer rust-src` |
| Mojo | `mojo-lsp-server`（pixi） | 改 init.el 里的 `my/mojo-lsp-server` 路径 |
| C / C++ | clangd（可选） | 自行安装 |

### Python：三件事

**1. 一个项目一个 venv，且语言服务器装进同一个 venv**

```powershell
python -m venv D:\workspace\myproj\.venv
D:\workspace\myproj\.venv\Scripts\pip install python-lsp-server pyqpanda3
```

> 为什么反复强调"同一个解释器"：pylsp/jedi 只能解析**它自己那台解释器** site-packages 里的包。
> 服务器和 pyqpanda3 不在同一个环境里，症状就是"能跳到包根 `pyqpanda3\__init__.py`，
> 但 `core.H` / `core.QProg` 既补不出也跳不进"。
> 也**别在同一台机器上重复建好几个装 pyqpanda3 的 venv** —— 排查时很难判断 LSP 用的是哪个。

**2. 让 Emacs 找得到 `pylsp`**

`init.el`（9b 节）已经会自动扫两处：`~/.emacs.d/*-env/Scripts` 和工程里的 `.venv/Scripts`。
venv 建在别处的话，把它的 `Scripts` 目录加进用户 PATH，或直接在配置里注册该路径。

**3. 给 pyqpanda3 打 stub 补丁（每个新环境、每次升级后都要）**

```powershell
pwsh -File ~/.emacs.d/scripts/fix-pyqpanda3-stubs.ps1
```

原因：pyqpanda3 的编译扩展（`.pyd`）只有运行时才知道有哪些符号 —— 靠
`_extension_loader.export_public_symbols()` 动态往 `globals()` 里塞；它自带的包级
`__init__.pyi` 只写了 `__all__` 加一句 "no definition"，真正的签名在同目录 `core.pyi`（19176 行）里。
静态分析器优先读 `.pyi`，于是看到空壳 → `core.H` 找不到。

脚本做的事：给 7 个子包的 `__init__.pyi` 补一行 `from .X import *`（外加 `core\__init__.py`，运行时等价）。
幂等、可重复执行，原文件备份成 `.pystub-orig`。**`pip install -U pyqpanda3` 会覆盖，升级后重跑一次。**

`pyqpanda3.utils` 没提供任何 `.pyi`，`utils.*` 的静态补全无解；`visualization` / `profiling` /
`pilot_os` 是纯 Python，本来就正常。

### Rust：两件事

**1. 装 rust-analyzer 和 rust-src**

```powershell
rustup component add rust-analyzer   # 语言服务器
rustup component add rust-src        # 想 M-. 跳进标准库源码才需要
```

`~/.cargo/bin/rust-analyzer.exe` 只是 rustup 的**代理**，组件没装时它会直接报
`error: Unknown binary 'rust-analyzer.exe' in official toolchain`。
`rustup component add` 卡在 `static.rust-lang.org` 上时换镜像：

```powershell
$env:RUSTUP_DIST_SERVER = "https://rsproxy.cn"
rustup component add rust-analyzer rust-src
```

**2. 主模式别停在 fundamental-mode**

Emacs 31 把 `.rs` 指向 `rust-ts-mode-maybe`：没有 tree-sitter 的 rust 语法时它
**静默退回 fundamental-mode**，于是既没高亮也没有 eglot（eglot 只认
`rust-mode` / `rust-ts-mode`），补全和跳转全无。`init.el` 的 9c 节按下面顺序兜底：

- 有语法 → `rust-ts-mode`（想要语法树：`M-x treesit-install-language-grammar RET rust RET`，需要 git + MSVC 的 `cl.exe`）
- 没语法 → MELPA 的 `rust-mode`（纯 elisp，配置里 `:ensure t` 自动装）
- 都没有 → `fundamental-mode` + 一条提示消息

看一眼当前状态：`M-x my/rust-doctor`（`C-c r d`）。

### 自检三步

1. 打开 `.py`，模式行出现 `[eglot:工程名]` → 服务器连上了
2. `M-.` 跳定义、`M-?` 找引用、`M-,` 跳回来
3. 连不上时：`M-x mvue-events` 看 LSP 收发日志（第一行 `Running language server: ...` 就是它在用谁），
   `M-x eglot` 手动重连，`M-x list-processes` 看语言服务器进程的完整路径/解释器
