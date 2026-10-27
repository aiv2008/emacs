;; init.el --- Anson 的 Emacs 配置 -*- lexical-binding: t; -*-
;;;
;;; 同一份配置给 Linux（WSL）和 macOS 用。
;;; 终端 Emacs（Ghostty 里跑 emacs）：字体改 ~/.config/ghostty/config 的 font-size。
;;; 图形 Emacs：字体改下面 my/font-size。Mac 需先安装 Maple Mono NF。
;;; 改完本文件后：M-x eval-buffer，或重启 Emacs。

;;; --------------------------------------------------------------------------
;;; 1. 包管理
;;; --------------------------------------------------------------------------
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu"   . "https://elpa.gnu.org/packages/")))
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;;; --------------------------------------------------------------------------
;;; 2. PATH（eglot 子进程要能找到 lake / node）
;;; --------------------------------------------------------------------------
(defun my/add-bin-to-path (bin)
  "把 BIN 加到 exec-path 和 PATH，已存在则跳过。"
  (when (and (file-directory-p bin) (not (member bin exec-path)))
    (add-to-list 'exec-path bin)
    (setenv "PATH" (concat bin path-separator (getenv "PATH")))))

;; macOS Homebrew。Apple Silicon: /opt/homebrew；Intel: /usr/local。
(when (eq system-type 'darwin)
  (mapc #'my/add-bin-to-path
        '("/opt/homebrew/bin" "/opt/homebrew/sbin" "/usr/local/bin")))

;; Dock / Spotlight 打开的图形 Emacs 没有 shell 的 PATH，从登录 shell 拷一份。
;; 终端里启动的 Emacs 本身 PATH 已正确，不会走到这里。
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :init
  (setq exec-path-from-shell-variables
        '("PATH" "MANPATH"
          "CODERELAY_API_KEY"
          "ANTHROPIC_API_KEY" "ANTHROPIC_AUTH_TOKEN" "ANTHROPIC_BASE_URL"
          "OPENAI_API_KEY" "OPENROUTER_API_KEY"))
  :config
  (exec-path-from-shell-initialize))

;; 三平台共用：elan、cargo（rust-analyzer / rustfmt / clippy-driver）、用户本地 bin、
;; nvm 的 node。~/.cargo/bin 里那几个是 rustup 的代理程序，真正的二进制在
;; ~/.rustup/toolchains/<toolchain>/bin —— 代理必须能被找到，见「9c. Rust」。
(mapc #'my/add-bin-to-path
      (append
       (list (expand-file-name "~/.elan/bin")
             (expand-file-name "~/.cargo/bin")
             (expand-file-name "~/.local/bin"))
       (file-expand-wildcards
        (expand-file-name "~/.nvm/versions/node/*/bin"))))

;;; --------------------------------------------------------------------------
;;; 3. 界面
;;; --------------------------------------------------------------------------
(setq inhibit-startup-message t
      visible-bell t
      line-spacing 0.8)
;; macOS 菜单在系统顶栏，关掉会少一排系统菜单；Linux 仍隐藏。
(if (eq system-type 'darwin)
    (menu-bar-mode 1)
  (menu-bar-mode -1))
(tool-bar-mode -1)
(global-display-line-numbers-mode 1)

;; emacs-mac 端口：Option = Meta，Command = Super。GNU NS 端口默认已是这样。
(when (eq system-type 'darwin)
  (setq ns-pop-up-frames nil)
  (when (boundp 'mac-option-modifier)
    (setq mac-option-modifier 'meta
          mac-command-modifier 'super)))

;; (use-package draculatheme
;;   :config
;;   (load-theme 'dracula t))

;; 主题：换主题改 my/theme 一行即可；可用名字用 M-x customize-themes 看
(setq my/theme 'catppuccin)          ; 例：'modus-vivendi、'ef-dark、'doom-one
(unless (eq my/theme 'modus-vivendi) ; modus-* 是内置的，不用装
  (use-package catppuccin-theme :ensure t :defer t))
(load-theme my/theme t)              ; t = 以后别每次问

(use-package catppuccin-theme
  :ensure t
  :config
  (setq catppuccin-flavor 'frappe) ; mocha / macchiato / frappe / latte
  (load-theme 'catppuccin t))

;; 仅图形界面生效。GTK/WSL 必须用 "Family-SIZE"，只改 :height 不会变。
(setq my/font-family "Maple Mono NF"
      my/font-size 11) ; 单位 pt，建议 8–18

(defun my/setup-fonts (&optional frame)
  "给 FRAME（默认当前 frame）套 Maple Mono。终端帧直接跳过。"
  (interactive)
  (let* ((frame (or frame (selected-frame)))
         (spec (format "%s-%s" my/font-family my/font-size)))
    (when (display-graphic-p frame)
      (setq default-frame-alist
            (cons (cons 'font spec)
                  (assq-delete-all 'font default-frame-alist)))
      (with-selected-frame frame
        (set-frame-font spec nil t)
        (set-face-attribute 'default nil :font spec)))))

(setq inhibit-compacting-font-caches t)
(my/setup-fonts)
(add-hook 'after-make-frame-functions #'my/setup-fonts)

;; 窗口分隔改成实线（覆盖 Treemacs / 分屏之间默认的虚线边框）。
;; GTK 下 1px 仍可能发虚，所以宽度用 2，并把 first/last pixel 涂成同一色。
(defun my/setup-window-dividers ()
  "用像素实线替换默认的 vertical-border 虚线。"
  (setq window-divider-default-places t
        window-divider-default-right-width 2
        window-divider-default-bottom-width 1)
  (window-divider-mode 1)
  (let ((color "#44475a")) ; Dracula current-line，可改
    (dolist (face '(window-divider
                    window-divider-first-pixel
                    window-divider-last-pixel
                    vertical-border))
      (set-face-foreground face color)
      (set-face-background face color))))
(my/setup-window-dividers)

;;; --------------------------------------------------------------------------
;;; 4. 编辑习惯
;;; --------------------------------------------------------------------------
(setq-default indent-tabs-mode nil
              tab-width 2)
;; 自动保存已访问文件，但增加保存间隔避免频繁触发
(auto-save-visited-mode 1)
(setq auto-save-visited-interval 30) ; 从默认 5 秒改为 30 秒

;; 在 vterm 终端模式下禁用自动保存，避免焦点跳转
(add-hook 'vterm-mode-hook
          (lambda () (auto-save-visited-mode -1)))
(put 'upcase-region 'disabled nil)

;; ----------------各个语言强制缩进2空格----------------
;; C/C++/Java
(setq c-basic-offset 2)
;; JavaScript / Typescript
(setq js-indent-level 2)
;; HTML XML
(setq sgml-basic-offset 2)
;; Python 注意：PEP8标准是4空格，如果你确定要2空格才改
(setq python-indent-offset 2)

;; 开启智能自动缩进，回车自动对齐
(electric-indent-mode 1)

;; C-z 默认是 suspend，改成撤销。C-x k 仍是默认的 kill-buffer（会询问名字）。
(global-set-key (kbd "C-z") 'undo)
(global-set-key (kbd "<f3>") 'isearch-repeat-forward)
(global-set-key (kbd "<S-f3>") 'isearch-repeat-backward)
(global-set-key (kbd "C-c k") 'kill-current-buffer) ; 直接关当前 buffer
(global-set-key (kbd "C-S-k") 'kill-whole-line)     ; 删整行

(use-package comment-dwim-2
  :bind ("M-;" . comment-dwim-2))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; ---- 让 GUI Emacs 找到 mise 管理的命令行工具（prettier 等）----
(dolist (dir (list (expand-file-name "~/.local/share/mise/shims")
                   (expand-file-name "~/.local/share/mise/installs/node/latest/bin")))
  (when (file-directory-p dir)
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir ":" (getenv "PATH")))))

;; 自动格式化代码。支持多种语言，保存时自动格式化。
;; 需要安装对应的格式化工具：
;;   - JavaScript/TypeScript: npm install -g prettier
;;   - Python: pip install black
;;   - Rust: rustup component add rustfmt
;;   - Go: go install golang.org/x/tools/cmd/goimports@latest
(use-package format-all
  :commands format-all-mode
  :hook (prog-mode . format-all-mode)
  :config
  (setq-default format-all-formatters
                '(("JavaScript" prettier)
                  ("TypeScript" prettier)
                  ("TSX" prettier)
                  ("JSON" prettier)
                  ("CSS" prettier)
                  ("HTML" prettier)
                  ("Vue" prettier)
                  ("Markdown" prettier)
                  ("Python" black)
                  ("Rust" rustfmt)
                  ("Go" goimports))))

;;; --------------------------------------------------------------------------
;;; 5. 补全
;;; --------------------------------------------------------------------------
;; which-key：延迟显示可用快捷键，帮助记忆。
(use-package which-key
  :init
  (which-key-mode)
  :config
  (setq which-key-idle-delay 0.5
        which-key-sort-order 'which-key-key-order-alpha))

;; vertico：更好的 minibuffer 补全界面（替代默认的 *Completions*）。
(use-package vertico
  :init
  (vertico-mode)
  :config
  (setq vertico-cycle t))

;; orderless：模糊匹配补全样式，支持空格分隔的多个关键词。
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; marginalia：在 minibuffer 补全候选旁边显示额外信息（文件大小、命令说明等）。
(use-package marginalia
  :init
  (marginalia-mode))

;; company：代码补全。
(use-package company
  :init
  (global-company-mode t)
  :config
  (setq company-minimum-prefix-length 1
        company-idle-delay 0.2
        company-show-numbers t
        company-tooltip-align-annotations t
        company-async-timeout 30) ; Lean LSP 补全经常超过默认 2s
  :bind
  (:map company-active-map
        ("C-n" . company-select-next)
        ("C-p" . company-select-previous)
        ("<tab>" . company-complete)))

;;; --------------------------------------------------------------------------
;;; 6. 跳转（各语言共用，避免每个 mode 写一遍）
;;; --------------------------------------------------------------------------
(defun my/bind-xref-keys ()
  "统一 M-. 定义 / M-? 引用 / M-, 返回，覆盖 major mode 自带绑定。"
  (local-unset-key (kbd "M-."))
  (local-unset-key (kbd "M-?"))
  (local-set-key (kbd "M-.") #'xref-find-definitions)
  (local-set-key (kbd "M-?") #'xref-find-references)
  (local-set-key (kbd "M-,") #'xref-pop-marker-stack))

;;; --------------------------------------------------------------------------
;;; 7. TypeScript / TSX / JS / Vue
;;; --------------------------------------------------------------------------
(use-package typescript-mode
  :mode "\\.ts\\'"
  :hook (typescript-mode . my/bind-xref-keys))

;; .tsx 必须用独立 major mode，否则 eglot 的 languageId 是 typescript 而不是
;; typescriptreact，JSX 的 < 会被 tsserver 当成小于号。
(define-derived-mode typescriptreact-mode typescript-mode "TSX")
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . typescriptreact-mode))
(add-hook 'typescriptreact-mode-hook #'my/bind-xref-keys)
(add-hook 'js-mode-hook #'my/bind-xref-keys)

;; Vue.js 支持（Vue 2 & Vue 3）
;; 需要安装 volar 语言服务器：npm install -g @vue/language-server
(use-package web-mode
  :mode ("\\.html\\'")
  :hook (web-mode . my/bind-xref-keys)
  :config
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2
        web-mode-style-padding 2
        web-mode-script-padding 2
        web-mode-block-padding 0
        web-mode-enable-auto-closing t
        web-mode-enable-auto-pairing t
        web-mode-enable-auto-quoting t
        web-mode-enable-current-element-highlight t
        web-mode-enable-current-column-highlight t
        ;; Vue 2 使用 element-ui 等库时，识别自定义标签
        web-mode-enable-html-entities-fontification t
        web-mode-enable-css-colorization t
        web-mode-enable-comment-interpolation t
        web-mode-enable-heredoc-fontification t)
  ;; .vue 交给文件末尾「7b. Vue 2」那一节处理（vue2-web-mode + eglot/Volar）
  )

;; 注：Vue 相关的 eglot 配置已挪到文件末尾「7b. Vue 2」一节
(use-package company
  :config
  ;; 核心：补全候选排序函数，优先前缀匹配
  (setq company-transformers '(company-sort-prefer-same-case-prefix))
  ;; 如果你还有其他 transformer，可以追加，例如：
  ; (setq company-transformers '(company-sort-prefer-same-case-prefix company-sort-by-occurrence))
  )

;;; --------------------------------------------------------------------------
;;; 8. Markdown
;;; --------------------------------------------------------------------------
(use-package markdown-mode
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :bind (:map markdown-mode-map
              ("C-c C-c l" . markdown-live-preview-mode)  ; Live preview in Emacs
              ("C-c C-c v" . markdown-preview))            ; Export and view HTML
  :config
  (setq markdown-command "pandoc"
        ;; View markdown files in Emacs instead of opening browser
        markdown-open-command nil
        ;; Use EWW (Emacs Web Wowser) for preview - works without xwidget
        markdown-live-preview-window-function 'markdown-live-preview-window-eww))

;;; --------------------------------------------------------------------------
;;; 9. LSP（eglot）
;;; --------------------------------------------------------------------------
;; 大仓库用 lakefile / package.json 当工程根，避免 eglot 跑到 git 根目录。
(setq project-vc-extra-root-markers
      '("lakefile.toml" "lean-toolchain" "package.json"))

(use-package eglot
  :hook
  ((js-mode . eglot-ensure)
   (typescript-mode . eglot-ensure)
   (typescriptreact-mode . eglot-ensure)
   (lean4-mode . eglot-ensure))
  :config
  ;; Lean 首次 elaboration / 跳进标准库经常超过 jsonrpc 默认 10s。
  (setq eglot-autoshutdown nil
        eglot-extend-to-xref t
        eglot-connect-timeout 120
        jsonrpc-default-request-timeout 120)
  (add-to-list 'eglot-server-programs
               '(lean4-mode . ("lake" "serve")))
  (add-to-list 'eglot-server-programs
               '(typescriptreact-mode . ("typescript-language-server" "--stdio")))
  ;; 交给 LSP 补全，避免 dabbrev 抢候选。
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (setq-local company-backends '(company-capf)))))

;;; --------------------------------------------------------------------------
;;; 9b. Python（eglot）
;;; 为什么 .py 里既跳不动也没补全（以及怎么修）：
;;;   ① python 必须挂 eglot。上面 use-package eglot 的 :hook 只有 js / ts / tsx /
;;;      lean4；没有 eglot 连接 ⇒ xref 没 backend（M-. 不动）+ company 没 capf
;;;      后端（没补全）。所以下面几行 add-hook 是必需的。
;;;   ② 语言服务器不在仓库里，要自己装。Emacs 31 的 eglot 已内置 python-mode /
;;;      python-ts-mode 的候选，不用再注册 eglot-server-programs：
;;;        rass / pylsp / pyls / basedpyright-langserver / pyright-langserver /
;;;        pyrefly / ty / jedi-language-server / ruff / ruff-lsp
;;;      推荐把 pylsp 装进「项目自己的 venv」—— 它用 jedi 做运行时内省，
;;;      对 pyqpanda3 这种 pybind11 编译扩展比纯静态的 pyright 更管用：
;;;        python -m venv .venv
;;;        .venv\Scripts\pip install python-lsp-server
;;;   ③ 编译扩展的 stub 是空壳：pyqpanda3 的 <子包>\__init__.pyi 只写了 __all__，
;;;      真正的签名在同目录 <子包>.pyi，运行时才被动态注入 —— 静态分析器看不见，
;;;      于是 core.H / core.QProg 既补不出也跳不进。每个环境打一次补丁：
;;;        pwsh -File ~/.emacs.d/scripts/fix-pyqpanda3-stubs.ps1
;;; 换新电脑的完整清单见 README.md「换新电脑：环境清单」一节。
;;; --------------------------------------------------------------------------
;; MS Store 版 Python 把 pip 装的命令行工具丢在
;;   %LOCALAPPDATA%\Packages\PythonSoftwareFoundation.Python.3.*\
;;     LocalCache\local-packages\Python3*\Scripts
;; （本机是 Python 3.13，pyqpanda3 也装在这个解释器里）。这个目录虽然会进
;; 用户 PATH，但 GUI Emacs 拿到的是"启动那一刻"的 PATH，而且路径带版本号，
;; 所以这里显式扫一遍补进 exec-path —— pylsp 就落在这儿。
(when (eq system-type 'windows-nt)
  (when-let* ((localappdata (getenv "LOCALAPPDATA")))
    (dolist (dir (file-expand-wildcards
                  (expand-file-name
                   (concat "Packages/PythonSoftwareFoundation.Python.3.*/"
                           "LocalCache/local-packages/Python3*/Scripts")
                   localappdata)))
      (my/add-bin-to-path dir))))

;; venv 里的 pylsp 靠 exec-path 才能被 eglot 找到，而图形界面 Emacs 的 PATH
;; 里通常没有 venv。这里补两处：~/.emacs.d/*-env/Scripts（本机惯例）和当前
;; 工程的 .venv/Scripts。hook 按注册顺序跑，所以先补 PATH 再 eglot-ensure。
(dolist (dir (file-expand-wildcards
              (expand-file-name "*-env/Scripts" user-emacs-directory)))
  (my/add-bin-to-path dir))

(defun my/python-venv-path ()
  "把最近的 .venv/Scripts 补进 exec-path。
从工程根（拿不到就用 default-directory）逐级向上找 —— .py 在 src/ 里时，
.venv 通常还在上一层。"
  (let* ((proj (and (fboundp 'project-current) (project-current nil)))
         (dir (file-name-as-directory (or (and proj (project-root proj))
                                          default-directory)))
         (found nil)
         (hops 0))
    (while (and (not found) dir (< hops 8))
      (setq hops (1+ hops))
      (let ((venv (expand-file-name ".venv/Scripts" dir)))
        (if (file-directory-p venv)
            (setq found venv)
          (setq dir (file-name-parent-directory (directory-file-name dir))))))
    (when found (my/add-bin-to-path found))))

(add-hook 'python-mode-hook #'my/python-venv-path)
(add-hook 'python-ts-mode-hook #'my/python-venv-path)
(add-hook 'python-mode-hook #'eglot-ensure)
(add-hook 'python-ts-mode-hook #'eglot-ensure)

;;; --------------------------------------------------------------------------
;;; 9c. Rust（eglot + rust-analyzer）：补全 / 跳转 / 诊断
;;; 打开 .rs 既没补全、M-. 也跳不动，通常是下面三件事之一，本机 ①② 都踩过：
;;;   ① 主模式根本不对。Emacs 31 把 .rs 指向 rust-ts-mode-maybe：没有 tree-sitter
;;;      的 rust 语法时它【静默退回 fundamental-mode】—— 既没高亮，也没有 eglot
;;;      （eglot 只认 rust-mode / rust-ts-mode 这两个模式），补全和跳转自然全无。
;;;      本机就是这种情况：M-x treesit-language-available-p RET rust RET ⇒ nil。
;;;      两条路这里都接好了，装了哪条用哪条：
;;;        a) 内置 rust-ts-mode（推荐，高亮/缩进靠语法树更准）——先装语法：
;;;             M-x treesit-install-language-grammar RET rust RET
;;;           要 git + cc（即 MSVC 的 cl.exe）；也可以手动把预编译的
;;;           libtree-sitter-rust.dll 放进 ~/.emacs.d/tree-sitter/。
;;;        b) MELPA 的 rust-mode（纯 elisp，不依赖 tree-sitter，首次启动自动装）。
;;;   ② rust-analyzer 没装。~/.cargo/bin/rust-analyzer.exe 只是 rustup 的代理，
;;;      组件缺失时它自己会报
;;;        error: Unknown binary 'rust-analyzer.exe' in official toolchain
;;;      装上（国内网络常在 static.rust-lang.org 卡住，可换镜像）：
;;;        rustup component add rust-analyzer
;;;        $env:RUSTUP_DIST_SERVER="https://rsproxy.cn"; rustup component add rust-analyzer
;;;      想 M-. 跳进标准库源码，再加一个 rustup component add rust-src。
;;;   ③ 没有 eglot 连接 ⇒ xref 没 backend（M-. 不动）+ company 没 capf（不补全）。
;;;      所以下面 mode-hook 里的 eglot-ensure 是必需的；服务器映射 eglot 已内置
;;;      ((rust-ts-mode rust-mode) . ("rust-analyzer"))，不用再 add-to-list。
;;; 自检：M-x my/rust-doctor      看 LSP 收发日志：M-x eglot-events-buffer
;;; --------------------------------------------------------------------------
(defun my/rust-ts-available-p ()
  "本机能否使用 tree-sitter 的 rust 语法（决定 rust-ts-mode 还是 rust-mode）。"
  (and (require 'treesit nil t)
       (treesit-available-p)
       (treesit-language-available-p 'rust)))

;; ① 兜底主模式：纯 elisp，不需要 tree-sitter。有语法时用不上它。
(use-package rust-mode
  :ensure t
  :defer t
  :if (not (my/rust-ts-available-p)))

(defun my/rust-auto-mode ()
  "为 .rs 选一个「能用且 eglot 认识」的主模式，绝不停在 fundamental-mode。"
  (cond
   ((my/rust-ts-available-p) (rust-ts-mode))
   ((fboundp 'rust-mode) (rust-mode))
   (t (fundamental-mode)
      (message "Rust: 既没有 tree-sitter 的 rust 语法，也没装 rust-mode，\
补全/跳转不可用。装语法：M-x treesit-install-language-grammar RET rust RET"))))

;; 盖掉 Emacs 31 自带的 ("\\.rs\\'" . rust-ts-mode-maybe)：它没有语法时直接退回
;; fundamental-mode，eglot 找不到服务器，功能全无。add-to-list 会抢在最前面。
(add-to-list 'auto-mode-alist '("\\.rs\\'" . my/rust-auto-mode))

(defun my/rust-setup-buffer ()
  "让 .rs buffer 用好 eglot：eldoc 组合信息 + 缩进。
★ 内联类型提示不用在这儿开：eglot 在连上服务器的同时（`eglot--maybe-activate-
editing-mode'）自己会开 `eglot-inlay-hints-mode'。提前在这里开会在没连接的
buffer 上抛 \"No current JSON-RPC connection\"，并且把后面的 eglot-ensure 一起
带崩 —— 症状就是打开 .rs 既没连上也没补全（本机实测踩过）。"
  ;; 光标停一下就能看到 类型 / 函数签名（eglot 的 hover）。
  (setq-local eldoc-documentation-strategy #'eldoc-documentation-compose)
  (setq-local indent-tabs-mode nil))

;; 服务器端配置。★ 坑：eglot 是在【临时 buffer】里读 eglot-workspace-configuration
;; 的（default-directory 设成工程根，再套 .dir-locals.el），所以在这个 .rs buffer
;; 里 setq-local 完全无效 —— 只能设全局值，或者写进工程的 .dir-locals.el。
;; keyword 会被 eglot 转成 camelCase 键名发给服务器；函数值收到 server 对象。
(defun my/rust-workspace-configuration (server)
  "rust-analyzer 的服务器端配置；其它语言服务器返回 nil（等于什么都没配）。"
  (when (seq-some (lambda (m) (memq m '(rust-mode rust-ts-mode)))
                  (ignore-errors (eglot--major-modes server)))
    '(:rust-analyzer
      (:check (:command "clippy")        ; 保存后跑 clippy（组件已装）
       :cargo (:allFeatures t)           ; 别按 features 裁剪，否则 cfg 掉代码
       :procMacro (:enable t)            ; 让 derive/serde 这类宏能展开
       :imports (:granularity "module")  ; 自动 import 写成 use x::y，不必全路径
       :inlayHints (:typeHints (:enable t))))))

(setq-default eglot-workspace-configuration #'my/rust-workspace-configuration)

;; 三条 hook 的先后无所谓：`eglot-ensure' 只登记一个 post-command-hook，真正的
;; 连接发生在当前命令结束之后（所以上面 buffer 里的设置一定先就位）。
(dolist (hook '(rust-mode-hook rust-ts-mode-hook))
  (add-hook hook #'my/rust-setup-buffer)
  (add-hook hook #'my/bind-xref-keys)   ; M-. 定义 / M-? 引用 / M-, 返回
  (add-hook hook #'eglot-ensure))

(defun my/rust-project-root ()
  "当前 Rust 工程根目录：优先 project.el，其次往上找 Cargo.toml。
（eglot 的 rootUri 也取自 project.el；不加 project-vc-extra-root-markers 时
就是 git 根，cargo workspace 正好；非 git 的单 crate 由 Cargo.toml 兜底。）"
  (or (ignore-errors (project-root (project-current)))
      (locate-dominating-file default-directory "Cargo.toml")))

(defun my/rust-cargo-check ()
  "在工程根跑 cargo check（看编译错误比 clippy 快）。"
  (interactive)
  (let ((default-directory
         (file-name-as-directory (or (my/rust-project-root) default-directory))))
    (compile "cargo check --message-format=short")))

(defun my/rust-restart-server ()
  "重启当前工程的 rust-analyzer（改过 Cargo.toml / 加完依赖用它）。"
  (interactive)
  (if-let* ((server (eglot-current-server)))
      (progn (eglot-shutdown server) (eglot-ensure))
    (eglot-ensure)))

(defun my/rust--tool-version (program)
  "返回 PROGRAM --version 的首行；没装、或 rustup 代理缺组件时返回提示。
（`call-process' 的 DESTINATION 为 t 时 stdout 与 stderr 一起收进 buffer，
 rustup 代理的报错正是写在 stderr 上的。）"
  (let ((exe (executable-find program)))
    (cond
     ((null exe)
      (format "❌ 找不到（~/.cargo/bin 没进 exec-path？）"))
     (t
      (let ((out (string-trim
                  (or (ignore-errors
                        (with-temp-buffer
                          (call-process exe nil t nil "--version")
                          (buffer-string)))
                      ""))))
        (cond
         ((string-empty-p out) "❌ 跑不起来")
         ((string-match-p "Unknown binary" out)
          (format "❌ rustup 代理里没有这个组件，执行：rustup component add %s"
                  program))
         (t (car (split-string out "\n")))))))))

(defun my/rust-doctor ()
  "Rust + eglot 环境自检：工具链、语言服务器、主模式、工程根。"
  (interactive)
  (let* ((root (my/rust-project-root))
         (lines
          (list
           (format "Emacs: %s / eglot: %s" emacs-version
                   (or (ignore-errors (file-name-directory (locate-library "eglot")))
                       "内置"))
           (format "rustc: %s" (my/rust--tool-version "rustc"))
           (format "cargo: %s" (my/rust--tool-version "cargo"))
           (format "rustfmt: %s" (my/rust--tool-version "rustfmt"))
           (format "rust-analyzer: %s" (my/rust--tool-version "rust-analyzer"))
           (format "tree-sitter rust 语法: %s"
                   (if (my/rust-ts-available-p)
                       "✅ 有（用 rust-ts-mode）"
                     "❌ 没有（已退回 rust-mode；要语法树就 M-x treesit-install-language-grammar RET rust RET）"))
           (format "工程根: %s" (if root
                                   (abbreviate-file-name root)
                                 "❌ 没找到（eglot 会用文件所在目录）"))
           (format "Cargo.toml: %s"
                   (or (locate-dominating-file default-directory "Cargo.toml")
                       "❌ 上方没找到"))
           (format "当前 buffer: %s / %s / eglot=%s"
                   (buffer-name) major-mode
                   (if (eglot-current-server) "已连接" "未连接")))))
    (with-output-to-temp-buffer "*rust-doctor*"
      (princ "Rust + eglot 环境自检\n────────────────────\n")
      (dolist (line lines) (princ (concat line "\n"))))
    (with-current-buffer "*rust-doctor*" (special-mode))))

(defvar-keymap my/rust-command-map
  :doc "Rust 辅助命令"
  "d" #'my/rust-doctor
  "r" #'my/rust-restart-server
  "c" #'my/rust-cargo-check)

;; rust-ts-mode / rust-mode 都自带 keymap，但只有真加载了才有 —— 所以用
;; with-eval-after-load，别在 init 里直接 keymap-set（会抢先 defvar 掉空表）。
(with-eval-after-load 'rust-ts-mode
  (keymap-set rust-ts-mode-map "C-c r" my/rust-command-map))
(with-eval-after-load 'rust-mode
  (keymap-set rust-mode-map "C-c r" my/rust-command-map))

;;; --------------------------------------------------------------------------
;;; 9. Lean 4
;;; --------------------------------------------------------------------------
;; lean4-mode 不在 MELPA，需要克隆到 ~/.emacs.d/lean4-mode。
;; 依赖 dash / magit-section / lsp-mode；实际 LSP 仍用上面的 eglot。
(use-package dash :ensure t)
(use-package magit-section :ensure t)
(use-package lsp-mode :ensure t :defer t)

(defvar my/lean4-mode-dir
  (expand-file-name "lean4-mode" user-emacs-directory))

(defun my/ensure-lean4-mode ()
  "若缺少 lean4-mode 则 git clone。成功可加载时返回非 nil。"
  (let ((lib (expand-file-name "lean4-mode.el" my/lean4-mode-dir)))
    (unless (file-exists-p lib)
      (if (not (executable-find "git"))
          (message "lean4-mode 未安装，且找不到 git")
        (message "正在克隆 lean4-mode…")
        (make-directory user-emacs-directory t)
        (let ((status (call-process
                       "git" nil "*lean4-mode-install*" t
                       "clone" "--depth" "1"
                       "https://github.com/leanprover-community/lean4-mode.git"
                       my/lean4-mode-dir)))
          (unless (eq status 0)
            (message "克隆 lean4-mode 失败，见 *lean4-mode-install*")))))
    (when (file-exists-p lib)
      (add-to-list 'load-path my/lean4-mode-dir)
      t)))

;; ★ 运行当前 .lean 文件（C-c C-x）：
;; 原生的 C-c C-x / C-c C-l（lean4-execute）在 WinGet 装的 elan 上会报
;;   Incorrect `lean4-rootdir' value, path '...\WinGet\bin\lean.exe' does not exist
;; 因为 lean4-mode 从 shim 路径 ...\WinGet\Links\lean.exe 反推 rootdir=...\WinGet\，
;; 再拼 bin\lean.exe 就找不到（真正的 toolchain 在 ~/.elan/toolchains/...）。
;; 这里直接用 PATH 里的 lake —— elan 会按项目 lean-toolchain 选工具链，
;; 不依赖 lean4-rootdir，升级 toolchain 也不用改配置。
;; 若你更想用原生的 lean4-execute，可以额外加一行（版本号需跟着 toolchain 改）：
;;   (setq lean4-rootdir "C:/Users/anson/.elan/toolchains/leanprover--lean4---v4.31.0/")
(defun my/lean-run (&optional arg)
  "用 lake 跑当前 .lean 文件；有前缀参数（C-u）则加 --run 执行文件里的 main。
不依赖 `lean4-rootdir'，工具链由项目里的 lean-toolchain 决定。"
  (interactive "P")
  (let* ((file (or buffer-file-name (user-error "当前 buffer 没有关联文件")))
         (root (or (and (fboundp 'lean4-lake-find-dir) (lean4-lake-find-dir))
                   (file-name-directory file)))
         (extra (if arg "--run " ""))
         (cmd (format "lake env lean %s%s" extra (shell-quote-argument file))))
    (let ((default-directory (file-name-as-directory root)))
      (compile cmd))))

(defun my/lean-info-at-point ()
  "把光标处的类型 / 期望类型 / 证明目标显示到 *Lean Info* 里。
走 eglot 的 textDocument/hover、$/lean/plainTermGoal、$/lean/plainGoal，
所以不依赖 lsp-mode（lean4-mode 自带的 lean4-toggle-info 是 lsp-mode 实现，
在 eglot 下会报 \"does not support method $/lean/plainGoal\"）。"
  (interactive)
  (let ((server (or (eglot-current-server) (user-error "当前 buffer 没有 eglot 连接")))
        (params (eglot--TextDocumentPositionParams))
        (pos (format "%s:%d" (buffer-name) (line-number-at-pos))))
    (let* ((hover (ignore-errors (eglot--request server :textDocument/hover params :timeout 15)))
           (term  (ignore-errors (eglot--request server "$/lean/plainTermGoal" params :timeout 15)))
           (goal  (ignore-errors (eglot--request server "$/lean/plainGoal" params :timeout 15)))
           (buf (get-buffer-create "*Lean Info*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "位置：%s\n\n" pos))
          (let ((hv (and hover (plist-get (plist-get hover :contents) :value))))
            (when (and hv (not (string-empty-p hv)))
              (insert "── 光标处类型 ──\n" hv "\n\n")))
          (when-let* ((g (plist-get term :goal)))
            (insert "── 期望类型 ──\n" g "\n\n"))
          (when-let* ((gs (plist-get goal :goals)))
            (insert "── 证明目标 ──\n"
                    (if (listp gs) (mapconcat #'identity gs "\n") (format "%s" gs))
                    "\n\n"))
          (when (= (point-min) (point-max))
            (insert "这里没有可显示的信息。\n")))
        (special-mode)
        (goto-char (point-min)))
      (display-buffer buf))))

(if (my/ensure-lean4-mode)
    (progn
      (require 'lean4-mode)
      (setq lean4-show-goal-buttons nil)
      ;; lean4-mode 默认 hook 是 lsp-mode 的 #'lsp，和 eglot 冲突。
      (remove-hook 'lean4-mode-hook #'lsp)
      (add-hook 'lean4-mode-hook #'my/bind-xref-keys)
      (add-hook 'lean4-mode-hook
                (lambda ()
                  ;; C-c C-g：自写的 eglot 版信息面板（类型 / 期望类型 / 证明目标）。
                  ;; 不用 lean4-toggle-info：那是 lsp-mode 的实现，eglot 下会报
                  ;; "does not support method $/lean/plainGoal"；
                  ;; 也不用 lean4-toggle-info-buffer：它要 buffer 参数，不是交互命令。
                  (local-set-key (kbd "C-c C-g") #'my/lean-info-at-point)
                  ;; 原生 C-c C-x / C-c C-l（lean4-execute）在 WinGet 版 elan 下会因
                  ;; lean4-rootdir 推导错误而失败，换成走 PATH 里 lake 的版本。
                  (local-set-key (kbd "C-c C-x") #'my/lean-run)   ; 跑整个文件（看 #eval）
                  (local-set-key (kbd "C-c C-l") #'my/lean-run)   ; 同上
                  (local-set-key (kbd "M-/") #'company-complete))))
  (message "lean4-mode 未加载。可手动执行：git clone --depth 1 https://github.com/leanprover-community/lean4-mode.git ~/.emacs.d/lean4-mode"))

;;; ==================== Mojo（自包含：主模式 + LSP + 补全 + 跳转） ====================
;;; 用这一段【整体替换】init.el 里旧的 Mojo 一节。
;;; 旧的那段范围：从 `;;; mojo-emacs-completion-fix.el ---` 那行开始，
;;;               到 `(add-hook 'mojo-mode-hook #'eglot-ensure)` 那一行为止。
;;;
;;; 相比你现在的配置，改了三个地方：
;;;   1) ★ 补回 (setq eglot-send-changes-idle-time 0)
;;;      —— 原来的 0.5 秒 > company-idle-delay 的 0.2 秒，导致 didChange
;;;         还没发出去、补全请求先到了，Mojo LSP 回 -32801 ContentModified
;;;         ("outdated request")，补全全灭。
;;;   2) mojo-mode-hook 只留【一个】接线函数，不再两个 hook 互相覆盖 backends。
;;;   3) 补回 my/mojo-format-buffer（之前被覆盖掉，但 C-c C-f 还绑着它 → void-function）。

(require 'seq)
(require 'eglot)

;;; ---------------------------------------------------------------------------
;;; 1. 主模式 + 文件关联
;;; ---------------------------------------------------------------------------
(define-derived-mode mojo-mode python-mode "Mojo"
  "Major mode for editing Mojo files."
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)
  (font-lock-add-keywords
   nil
   '(("\\_<\\(fn\\|struct\\|trait\\|alias\\|var\\|comptime\\|raises\\|owned\\|borrowed\\|inout\\|async\\|await\\)\\_>"
      0 font-lock-keyword-face)
     ("\\_<\\(True\\|False\\|None\\|Self\\|self\\)\\_>" 0 font-lock-constant-face)
     ("\\(@[a-zA-Z_][a-zA-Z0-9_]*\\)" 1 font-lock-preprocessor-face))
   'append))

;; 没有这一行，打开 .mojo 就是 Fundamental mode（无高亮、无 LSP）。
(add-to-list 'auto-mode-alist '("\\.mojo\\'" . mojo-mode))

;;; ---------------------------------------------------------------------------
;;; 2. 工程根：让 eglot 认得出 pixi 项目
;;; ---------------------------------------------------------------------------
(dolist (marker '("pixi.toml" "mojoproject.toml" "magic.toml"))
  (add-to-list 'project-vc-extra-root-markers marker))

;;; ---------------------------------------------------------------------------
;;; 3. PATH：pixi 的 shim 目录（只加这个，别加 envs/*/bin 里的裸二进制）
;;; ---------------------------------------------------------------------------
(dolist (dir (list (expand-file-name "~/.pixi/bin")))
  (when (fboundp 'my/add-bin-to-path)
    (my/add-bin-to-path dir)))

;;; ---------------------------------------------------------------------------
;;; 4. 语言服务器：走项目 pixi 环境，并带上社区验证过的 -I .
;;; ---------------------------------------------------------------------------
(setq eglot-server-programs
      (cons '(mojo-mode . ("pixi" "run" "mojo-lsp-server" "-I" "."))
            (assq-delete-all 'mojo-mode eglot-server-programs)))

;;; ---------------------------------------------------------------------------
;;; 5. ★ 同步时机（本次修复的核心）
;;; ---------------------------------------------------------------------------
;; 必须让 didChange 先于 completion/hover 请求发出去。
;; 0 = 一有空闲立刻推文档；务必小于 company-idle-delay（下面设的 0.2）。
;; 若仍然偶发 outdated request，可改成 (setq eglot-send-changes-idle-time 0.1)
;; 并把 company-idle-delay 放宽到 0.5，用"拉大间距"的方式彻底避免竞争。
(setq eglot-send-changes-idle-time 0)

;;; ---------------------------------------------------------------------------
;;; 6. mojo CLI（C-c C-f 格式化用）
;;; ---------------------------------------------------------------------------
(defvar my/mojo-cli (or (executable-find "mojo")
                        (expand-file-name "~/.pixi/envs/mojo/bin/mojo"))
  "mojo CLI 路径。")

(defun my/mojo-format-buffer ()
  "用 mojo format 格式化当前文件并刷新 buffer。"
  (interactive)
  (let ((file (buffer-file-name))
        (mojo (expand-file-name my/mojo-cli)))
    (unless file (user-error "Buffer is not visiting a file"))
    (unless (file-executable-p mojo) (user-error "mojo not found: %s" mojo))
    (when (buffer-modified-p) (save-buffer))
    (let* ((log (get-buffer-create "*mojo-format*"))
           (code (progn (with-current-buffer log (erase-buffer))
                        (call-process mojo nil log nil "format" file))))
      (if (zerop code)
          (progn (revert-buffer t t t) (message "mojo format: ok"))
        (display-buffer log)
        (message "mojo format failed (exit %s), see *mojo-format*" code)))))

;;; ---------------------------------------------------------------------------
;;; 7. .mojo buffer 的接线（只此一个函数，别再拆成两个）
;;; ---------------------------------------------------------------------------
(defun my/mojo-setup-buffer ()
  "给 .mojo buffer 接上 company 与 xref。"
  (when (fboundp 'format-all-mode) (format-all-mode -1))
  ;; LSP 优先；LSP 出错/无候选时退到缓冲区词，保证打字一定有弹窗
  (setq-local company-backends '(company-capf company-dabbrev-code))
  (setq-local company-idle-delay 0.2)       ; 必须 > eglot-send-changes-idle-time
  (setq-local company-minimum-prefix-length 1)
  (setq-local company-async-timeout 30)
  (company-mode 1)
  ;; M-. 别弹「找哪个」直接跳
  (setq-local xref-prompt-for-identifier nil)
  (setq-local eldoc-documentation-strategy #'eldoc-documentation-compose)
  ;; 手动触发键固定成 company-complete（默认 M-/ 是 dabbrev-expand，和 LSP 无关）
  (local-set-key (kbd "M-/") #'company-complete)
  (local-set-key (kbd "C-c C-f") #'my/mojo-format-buffer)
  ;; M-. 定义 / M-? 引用 / M-, 返回（你第 6 节定义的那个通用函数）
  (when (fboundp 'my/bind-xref-keys) (my/bind-xref-keys)))

;;; ---------------------------------------------------------------------------
;;; 8. 接线：先配 company，再起 eglot
;;; ---------------------------------------------------------------------------
(add-hook 'mojo-mode-hook #'my/mojo-setup-buffer)
(add-hook 'mojo-mode-hook #'eglot-ensure)
;;; ==================== Mojo 配置结束 ====================


;;; ---------------------------------------------------------------------------
;;; 7. 可选
;;; ---------------------------------------------------------------------------
;; 7a. 万一 Mojo LSP 实在不返回候选，加 dabbrev 兜底（写在第 5 节的
;;     my/mojo-completion-setup 里面，否则会被它覆盖）：
;; (setq-local company-backends '(company-capf company-dabbrev-code))
;;
;; 7b. 想让服务器版本跟着项目走，可以不用全局二进制，改成让 pixi 代劳
;;     （pixi run 若往 stdout 输出任何东西都会破坏 LSP 分帧，需自行验证）：
;; (setq eglot-server-programs
;;       (cons '(mojo-mode . ("pixi" "run" "mojo-lsp-server"))
;;             (assq-delete-all 'mojo-mode eglot-server-programs)))

(provide 'mojo-emacs-completion-fix)
;;; mojo-emacs-completion-fix.el ends here


;;; --------------------------------------------------------------------------
;;; 10. 文件树 / 终端
;;; --------------------------------------------------------------------------
(use-package nerd-icons
  :ensure t
  :init
  (setq nerd-icons-font-family "Maple Mono NF"))

(use-package treemacs-nerd-icons
  :ensure t
  :after treemacs nerd-icons)

(defun my/treemacs-clean-gutter ()
  "去掉文件树左侧的行号、fringe 和 || 竖线。"
  (display-line-numbers-mode -1)
  (when (display-graphic-p)
    (set-window-fringes (selected-window) 0 0)))

(use-package treemacs
  :ensure t
  :bind
  ("C-x t t" . treemacs)
  ("C-x t r" . treemacs-refresh)
  ("C-x t p" . treemacs-add-project)
  :hook
  (treemacs-mode . my/treemacs-clean-gutter)
  :config
  (require 'treemacs-nerd-icons)
  (treemacs-load-theme "nerd-icons")
  (treemacs-follow-mode t)
  (treemacs-filewatch-mode t)
  (treemacs-git-mode 'simple)
  (treemacs-fringe-indicator-mode -1)
  (setq treemacs-position 'left
        treemacs-indentation 1
        treemacs-indentation-string " "))

(use-package vterm
  :bind ("C-c t" . vterm)
  :config
  (setq vterm-shell (or (getenv "SHELL") "/bin/bash"))
  ;; pyim 会在当前 buffer 里 insert 预览字符串。vterm 的内容由 libvterm 独占，
  ;; 一插入中文/拼音就会和重绘打架，Emacs 马上卡死。所以 vterm 里禁止开 pyim。
  (advice-remove 'vterm--self-insert #'my/vterm-self-insert-with-ime)
  (add-hook 'vterm-mode-hook #'deactivate-input-method)
  (defun my/vterm-send-utf8 (text)
    "把 TEXT 写入 PTY，不往 vterm buffer 里 insert，也不等待进程。"
    (when (and vterm--term (stringp text) (> (length text) 0))
      (let ((inhibit-redisplay t)
            (inhibit-read-only t))
        (dolist (char (string-to-list text))
          (vterm--update vterm--term (char-to-string char)))
        (setq vterm--redraw-immediately t))))
  (defun my/vterm-pyim-read-and-send ()
    "在 minibuffer 里用 pyim 组字，再发给 vterm。"
    (interactive)
    (let ((text (minibuffer-with-setup-hook
                    (lambda () (activate-input-method "pyim"))
                  (read-from-minibuffer "发给终端: "))))
      (unless (string-empty-p text)
        (my/vterm-send-utf8 text))))
  (define-key vterm-mode-map (kbd "C-\\") #'my/vterm-pyim-read-and-send)
  (define-key vterm-mode-map (kbd "C-c i") #'my/vterm-pyim-read-and-send))

;;; --------------------------------------------------------------------------
;;; 11. Git（Magit）
;;; --------------------------------------------------------------------------
;; 状态里常用：s stage，c c 写说明并提交，P p 推送，F p 拉取，b b 切分支。
(use-package magit
  :bind (("C-x g" . magit-status)          ; 仓库状态
         ("C-x M-g" . magit-dispatch)      ; Magit 命令菜单
         ("C-c M-g" . magit-file-dispatch))) ; 当前文件：blame / log / diff

;; git-gutter：在行号旁显示 git diff 状态（新增/修改/删除）。
(use-package git-gutter
  :config
  (global-git-gutter-mode +1)
  (setq git-gutter:update-interval 0.5)
  :bind (("C-x v =" . git-gutter:popup-hunk)  ; 显示当前 hunk 的 diff
         ("C-x v p" . git-gutter:previous-hunk)
         ("C-x v n" . git-gutter:next-hunk)
         ("C-x v r" . git-gutter:revert-hunk)  ; 撤销当前 hunk
         ("C-x v s" . git-gutter:stage-hunk))) ; stage 当前 hunk

;;; --------------------------------------------------------------------------
;;; 12. AI（CodeRelay 中转：https://coderelay.cn）
;;; --------------------------------------------------------------------------
;; 密钥不要写进本文件。复制控制台的 key 后任选其一：
;;   export CODERELAY_API_KEY="sk-..."     # 推荐，写进 ~/.zshrc
;;   或把 key 单独一行放到 ~/.config/coderelay/api-key
;; Claude Code 用本机 CLI；gptel 走 OpenAI 兼容接口 /v1/chat/completions。

(defvar my/coderelay-host "coderelay.cn")
(defvar my/coderelay-base-url "https://coderelay.cn")

(defun my/coderelay-api-key ()
  "读取 CodeRelay 密钥，不把密钥写进 init.el。"
  (or (getenv "CODERELAY_API_KEY")
      (let ((file (expand-file-name "~/.config/coderelay/api-key")))
        (when (file-readable-p file)
          (string-trim
           (with-temp-buffer
             (insert-file-contents file)
             (buffer-string)))))))

(defvar my/claude-buffer "*claude-code*")

(defun my/claude-project-root ()
  (or (when-let ((p (project-current nil)))
        (project-root p))
      default-directory))

(defun my/claude-start ()
  "在当前工程根目录启动 Claude Code，请求走 CodeRelay。"
  (interactive)
  (let ((root (my/claude-project-root))
        (buf my/claude-buffer)
        (key (my/coderelay-api-key)))
    (unless key
      (user-error "未找到 CodeRelay 密钥。请 export CODERELAY_API_KEY 或写入 ~/.config/coderelay/api-key"))
    (if (get-buffer buf)
        (pop-to-buffer buf)
      (let ((default-directory root)
            (process-environment
             (append
              (list (concat "ANTHROPIC_AUTH_TOKEN=" key)
                    (concat "ANTHROPIC_BASE_URL=" my/coderelay-base-url)
                    "ANTHROPIC_API_KEY=")
              process-environment)))
        (vterm buf)
        (run-with-timer
         0.4 nil
         (lambda ()
           (when (buffer-live-p (get-buffer buf))
             (with-current-buffer buf
               (vterm-send-string "claude")
               (vterm-send-return)))))))))

(defun my/claude-toggle ()
  "显示或隐藏 Claude 窗口。"
  (interactive)
  (if-let ((win (get-buffer-window my/claude-buffer)))
      (delete-window win)
    (my/claude-start)))

(defun my/claude-send-region ()
  "把选区发给 Claude。"
  (interactive)
  (unless (use-region-p)
    (user-error "请先选中区域"))
  (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
    (unless (get-buffer my/claude-buffer)
      (my/claude-start)
      (sit-for 1.2))
    (with-current-buffer my/claude-buffer
      (vterm-send-string text)
      (vterm-send-return))
    (pop-to-buffer my/claude-buffer)))

(defvar-keymap my/claude-command-map
  :doc "Claude Code 快捷键"
  "c" #'my/claude-start
  "t" #'my/claude-toggle
  "r" #'my/claude-send-region)

(keymap-set global-map "C-c c" my/claude-command-map)

;; 对话 / 改写。C-c g 开聊天；选中文字后 C-c RET 发送；C-u C-c RET 选模型。
(use-package gptel
  :bind (("C-c g" . gptel)
         ("C-c RET" . gptel-send))
  :config
  (setq gptel-default-mode 'org-mode
        gptel-api-key #'my/coderelay-api-key
        gptel-model 'claude-sonnet-4-6
        gptel-backend
        (gptel-make-openai "CodeRelay"
          :host my/coderelay-host
          :protocol "https"
          :endpoint "/v1/chat/completions"
          :stream t
          :key #'my/coderelay-api-key
          :models '(claude-sonnet-4-6
                    claude-sonnet-4-5
                    claude-opus-4-6
                    gpt-4o))))

;;; --------------------------------------------------------------------------
;;; 13. 剪贴板（WSL 与 Windows 互通）
;;; --------------------------------------------------------------------------
(setq select-enable-clipboard t
      select-enable-primary t)

;; WSLg 会把 X/Wayland 剪贴板同步到 Windows，M-w 后可在 Windows 里粘贴。
;; 不要再同步调用 clip.exe / powershell.exe：会把 weston 打崩，GTK Emacs 跟着闪退。
(when (and (eq system-type 'gnu/linux)
           (getenv "WSL_DISTRO_NAME"))
  (defun my/wsl-wl-copy (text &optional _push)
    (when (and (executable-find "wl-copy") (getenv "WAYLAND_DISPLAY"))
      (let ((process-connection-type nil)
            (proc (start-process "wl-copy" nil "wl-copy" "-n")))
        (process-send-string proc text)
        (process-send-eof proc))))
  (defun my/wsl-wl-paste ()
    (when (and (executable-find "wl-paste") (getenv "WAYLAND_DISPLAY"))
      (let ((text (string-chop-newline
                   (shell-command-to-string "wl-paste -n 2>/dev/null"))))
        (unless (string-empty-p text) text))))
  ;; 图形 Emacs：原生 CLIPBOARD 已由 WSLg 同步到 Windows。
  ;; 终端 Emacs：没有 X 选区，改走 wl-copy / wl-paste。
  (defun my/wsl-setup-terminal-clipboard ()
    (unless (display-graphic-p)
      (setq interprogram-cut-function #'my/wsl-wl-copy
            interprogram-paste-function #'my/wsl-wl-paste)))
  (add-hook 'tty-setup-hook #'my/wsl-setup-terminal-clipboard)
  (my/wsl-setup-terminal-clipboard)
  (defun wsl-paste-from-clipboard ()
    "从 Wayland/X 剪贴板粘贴（WSLg 会同步 Windows）。"
    (interactive)
    (let ((text (or (ignore-errors (gui-get-selection 'CLIPBOARD))
                    (my/wsl-wl-paste))))
      (if text (insert text)
        (user-error "Clipboard is empty"))))
  (global-set-key (kbd "M-v") #'wsl-paste-from-clipboard))

;;; --------------------------------------------------------------------------
;;; 14. Custom（Emacs 自动写入，保持在文件末尾）
;;; --------------------------------------------------------------------------
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(catppuccin-theme catppuccin-theme comment-dwim-2 company
                      exec-path-from-shell exwm format-all git-gutter
                      gptel lsp-mode magit marginalia orderless
                      org-inline-pdf pyim pyim-basedict
                      rainbow-delimiters rg solidity-mode
                      treemacs-nerd-icons typescript-mode vertico
                      vterm web-mode xr)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


;;; -------------------------------------------------------------------------
;;; 15. EXWM (X Window Manager) - 仅在图形界面 X11 环境启用
;;; -------------------------------------------------------------------------
;; EXWM 需要真正的 X server。WSL 终端、macOS 和 SSH 会话中都不适用。
;; 如需在 WSL 中使用，需先安装 X server（如 VcXsrv）并设置 DISPLAY。
(when (and (eq window-system 'x)
           (getenv "DISPLAY")
           (not (getenv "WSL_DISTRO_NAME")))  ; WSLg 下 window-system 也是 x，需排除 WSL
  (use-package exwm
    :ensure t
    :config

    ;; Basic configuration
    (require 'exwm)
    (require 'exwm-randr)

    ;; Set workspace number
    (setq exwm-workspace-number 4)

    ;; Make class name the buffer name
    (add-hook 'exwm-update-class-hook
              (lambda ()
                (exwm-workspace-rename-buffer exwm-class-name)))

    ;; Global keybindings (available everywhere)
    (setq exwm-input-global-keys
          `(
            ;; Reset to line-mode (pass keys to Emacs)
            ([?\s-r] . exwm-reset)

            ;; Switch workspace
            ([?\s-w] . exwm-workspace-switch)

            ;; Launch applications
            ([?\s-&] . (lambda (command)
                        (interactive (list (read-shell-command "$ ")))
                        (start-process-shell-command command nil command)))

            ;; Switch to workspace N
            ,@(mapcar (lambda (i)
                       `(,(kbd (format "s-%d" i)) .
                         (lambda ()
                           (interactive)
                           (exwm-workspace-switch-create ,i))))
                     (number-sequence 0 9))))

    ;; Line-mode keybindings (when keys go to Emacs)
    (setq exwm-input-simulation-keys
          '(
            ;; Movement
            ([?\C-b] . [left])
            ([?\C-f] . [right])
            ([?\C-p] . [up])
            ([?\C-n] . [down])
            ([?\C-a] . [home])
            ([?\C-e] . [end])
            ([?\M-v] . [prior])
            ([?\C-v] . [next])
            ([?\C-d] . [delete])
            ([?\C-k] . [S-end delete])
            ;; Cut/paste
            ([?\C-w] . [?\C-x])
            ([?\M-w] . [?\C-c])
            ([?\C-y] . [?\C-v])
            ;; Search
            ([?\C-s] . [?\C-f])))

    

    ;; Start EXWM
    ;; (exwm-enable)
    ))


(defun open-chrome ()
  "open google chrome browser."
  (interactive)
  (start-process "chrome" nil "chromium-browser"))
;; then bind it to a key
(global-set-key (kbd "C-c w") 'open-chrome)
  
;; 全局默认行间距，GUI图形窗口生效，终端-nnw无效
(setq-default line-spacing 0.4)

;; 替换原来所有 chinese-pyim 相关的配置
(use-package pyim
  :ensure t
  :demand t
  :custom
  (pyim-default-scheme 'quanpin)      ; 全拼;双拼用户改成 'shuangpin
  (pyim-page-length 9)
  :config
  (setq default-input-method "pyim")  ; 注意:是 "pyim",不是 "chinese-pyim"
  (global-set-key (kbd "C-\\") 'toggle-input-method))

(use-package pyim-basedict            ; 拼音词库,不加它打不出候选字
  :ensure t
  :config
  (pyim-basedict-enable))

;; ── 读写一律 UTF-8：两个平台都建议 ──
(prefer-coding-system 'utf-8-unix)
(set-language-environment "UTF-8")

;; ── 只对 Windows 生效：绕开系统 ANSI 代码页（GBK）接管写文件 ──
(when (eq system-type 'windows-nt)
  (setq default-process-coding-system '(utf-8-unix . utf-8-unix)
        coding-system-for-write 'utf-8-unix))

;; ── 可选：让新 buffer 默认 UTF-8 换行。放 after-init-hook，
;;     免得被 language-environment 后续覆盖 ──
(add-hook 'after-init-hook
          (lambda () (setq-default buffer-file-coding-system 'utf-8-unix)))

;;; --------------------------------------------------------------------------
;;; 7b. Vue 2：.vue 主模式 + eglot/Volar（代码来自 emacs-vue2/vue2.el）
;;;
;;; 项目侧一次性准备（服务器必须是 2.2.x，Volar 3.1 起已删掉 Vue 2 支持，
;;; 3.0 起又要求编辑器桥接 tsserver，eglot 桥不了）：
;;;   npm i -D @vue/language-server@2.2.10 typescript@~5.6.3
;;; tsconfig.json / jsconfig.json：
;;;   "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["src/*"] } }
;;;   "vueCompilerOptions": { "target": 2.7 }      // Vue 2.6 写 2
;;; 自检：M-x mvue-doctor        LSP 日志：C-c v e
;;; --------------------------------------------------------------------------

(require 'eglot)
(require 'project)
(require 'json)
(require 'seq)
(require 'cl-lib)
(require 'web-mode)

;;; --------------------------------------------------------------------------
;;; 7b.1. 可调参数
;;; --------------------------------------------------------------------------
(defgroup mvue nil
  "Vue 2 开发环境（eglot + Volar）。"
  :group 'languages
  :prefix "mvue-")

(defcustom mvue-node-program nil
  "node 可执行文件路径。nil 表示自动在 `exec-path' 里找。"
  :type '(choice (const :tag "自动" nil) file))

(defcustom mvue-server-package "node_modules/@vue/language-server"
  "工程内语言服务器包相对工程根的路径。"
  :type 'string)

(defcustom mvue-tsdk-subdir "node_modules/typescript/lib"
  "传给 volar 的 TypeScript SDK 目录（相对工程根）。"
  :type 'string)

(defcustom mvue-prettier-on-save t
  "非 nil 时保存 .vue 前用项目里的 prettier 格式化。"
  :type 'boolean)

(defcustom mvue-prettier-program "prettier"
  "prettier 可执行文件名。"
  :type 'string)

(defcustom mvue-default-indent 2
  "Vue/HTML/CSS/JS 缩进宽度。"
  :type 'integer)

;;; --------------------------------------------------------------------------
;;; 7b.2. PATH：让 eglot 的子进程找得到 node / npm / 全局命令
;;;    （图形界面启动的 Emacs 拿不到 shell 的 PATH，Windows 尤其明显）
;;; --------------------------------------------------------------------------
(defun mvue--add-to-path (dir)
  "把 DIR 加到 `exec-path' 和 PATH，已存在则跳过。"
  (when (and dir (stringp dir) (file-directory-p dir))
    (unless (member dir exec-path) (add-to-list 'exec-path dir))
    (let ((cur (or (getenv "PATH") "")))
      (unless (string-match-p (regexp-quote dir) cur)
        (setenv "PATH" (concat dir path-separator cur))))))

(defun mvue--node-dir ()
  "从当前 `executable-find' 推断 node 所在目录。"
  (when-let* ((node (executable-find "node")))
    (file-name-directory (file-truename node))))

(defun mvue--setup-paths ()
  "补齐常见的 node 全局 bin 目录。"
  (dolist (dir (delq nil
                     (list (mvue--node-dir)
                           ;; Windows 官方 npm 全局目录
                           (when-let* ((appdata (getenv "APPDATA")))
                             (expand-file-name "npm" appdata))
                           ;; nvm4w / nvm-windows
                           (when-let* ((node (executable-find "node")))
                             (file-name-directory (file-truename node)))
                           ;; mise
                           (expand-file-name "~/.local/share/mise/shims")
                           ;; nvm (Unix)
                           (expand-file-name "~/.local/bin"))))
    (mvue--add-to-path dir))
  ;; nvm 的 node 目录是带版本号的
  (dolist (bin (file-expand-wildcards
                (expand-file-name "~/.nvm/versions/node/*/bin")))
    (mvue--add-to-path bin)))

(mvue--setup-paths)

;;; --------------------------------------------------------------------------
;;; 7b.3. 工程根：别让 eglot 一路找到 git 根目录去
;;; --------------------------------------------------------------------------
(defvar mvue-project-markers
  '("package.json" "tsconfig.json" "jsconfig.json"
    "vite.config.js" "vite.config.ts" "vue.config.js")
  "能当作前端工程根的标志文件。")

(dolist (marker (reverse mvue-project-markers))
  (add-to-list 'project-vc-extra-root-markers marker))

(defun mvue--locate-root (&optional dir)
  "从 DIR 向上找第一个带工程标志文件的目录。
比 `project-root' 更贴近前端工程：文件在 src/ 里也能找到上一层带
package.json 的目录，不会一路跑到 git 根目录。
走到盘符根都找不到时就返回最上一级目录（永远返回字符串，不会返回 nil）。"
  (let* ((start (file-name-as-directory (or dir default-directory)))
         (dir start)
         (prev nil)
         (found nil))
    (while (and (not found) dir (not (equal dir prev)))
      (setq prev dir)
      (if (seq-some (lambda (marker) (file-exists-p (expand-file-name marker dir)))
                    mvue-project-markers)
          (setq found dir)
        ;; 注意："d:/" 再往上 `file-name-parent-directory' 会返回 nil，
        ;; 所以这里必须判断 dir 非 nil 才能继续，否则会把 nil 当路径用。
        (setq dir (file-name-parent-directory dir))))
    (or found prev start)))

;;; --------------------------------------------------------------------------
;;; 7b.4. .vue 主模式
;;;    eglot 会按 major-mode 找服务器，所以这里派生一个专属模式：
;;;    .html 仍旧是 web-mode（languageId=html），.vue 才是 languageId=vue。
;;; --------------------------------------------------------------------------
(defun mvue--setup-web-mode-defaults ()
  "web-mode 的通用排版设置（缩进、标签高亮等）。"
  (setq-default web-mode-markup-indent-offset mvue-default-indent
                web-mode-css-indent-offset mvue-default-indent
                web-mode-code-indent-offset mvue-default-indent
                web-mode-script-padding mvue-default-indent
                web-mode-style-padding mvue-default-indent
                web-mode-block-padding 0
                web-mode-enable-auto-closing t
                web-mode-enable-auto-pairing t
                web-mode-enable-auto-quoting t
                web-mode-enable-current-element-highlight t
                web-mode-enable-current-column-highlight t
                web-mode-enable-css-colorization t
                web-mode-enable-comment-interpolation t))

(mvue--setup-web-mode-defaults)

(define-derived-mode vue2-web-mode web-mode "Vue2"
  "Vue 2 单文件组件（.vue）主模式：web-mode + eglot/Volar。
只负责把 .vue 从 web-mode 里分出来，好让 eglot 用 languageId \"vue\"
找到 Volar，同时不影响 .html。"
  (setq-local js-indent-level mvue-default-indent))

;; 抢在其它配置前面注册 .vue（先删掉已有的 *vue* 映射，避免被后加载的配置覆盖）
(setq auto-mode-alist
      (cons '("\\.vue\\'" . vue2-web-mode)
            (seq-remove (lambda (entry)
                          (and (stringp (car entry))
                               (string-match-p "vue" (car entry))))
                        auto-mode-alist)))

;;; --------------------------------------------------------------------------
;;; 7b.5. 语言服务器：找到「认识 Vue 2」的 vue-language-server
;;; --------------------------------------------------------------------------
(defvar mvue--version-cache (make-hash-table :test #'equal)
  "缓存 `mvue--probe-version' 的结果，避免每次连接都起进程。")

(defun mvue--read-json (file)
  "读 FILE 里的 JSON，返回 alist；失败返回 nil。"
  (when (file-readable-p file)
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (json-parse-buffer :object-type 'alist :null-object nil :false-object nil))
      (error nil))))

(defun mvue--probe-version (program)
  "执行 PROGRAM --version 取版本号（结果缓存）。"
  (or (gethash program mvue--version-cache)
      (puthash program
               (let ((out (ignore-errors
                            (with-temp-buffer
                              (when (zerop (call-process program nil t nil "--version"))
                                (string-trim (buffer-string)))))))
                 (or (and out (car (split-string out))) ""))
               mvue--version-cache)))

(defun mvue--local-server (root)
  "在工程 ROOT 里找 node_modules 下的 @vue/language-server。
返回 (VERSION . JS-ENTRY)；没有则 nil。"
  (let* ((dir (expand-file-name mvue-server-package root))
         (pkg (expand-file-name "package.json" dir))
         (js (expand-file-name "bin/vue-language-server.js" dir)))
    (when (and (file-exists-p js) (file-readable-p pkg))
      (cons (or (alist-get 'version (mvue--read-json pkg)) "") js))))

(defun mvue--node ()
  "要用的 node 可执行文件。"
  (or mvue-node-program (executable-find "node") "node"))

(defun mvue--tsdk (root)
  "工程里 typescript 的 lib 目录，没有则 nil。"
  (let ((dir (expand-file-name mvue-tsdk-subdir root)))
    (and (file-directory-p dir) dir)))

(defun mvue--initialization-options (root version)
  "给服务器 VERSION 用的 initializationOptions。
Volar 2.x 在 `vue.hybridMode' 为 false 时自带 TypeScript，不需要编辑器
再桥接一个 tsserver —— eglot 能用；1.x 只认 typescript.tsdk。"
  (let ((opts (list :typescript (list :tsdk (or (mvue--tsdk root)
                                                (expand-file-name mvue-tsdk-subdir root))))))
    (when (string-prefix-p "2." version)
      (setq opts (append opts (list :vue (list :hybridMode :json-false)))))
    opts))

(defun mvue--server-contact (_interactive project)
  "eglot 的 CONTACT 函数：按工程挑服务器和参数。"
  (let* ((root (file-name-as-directory
                (or (mvue--locate-root)
                    (and project (project-root project))
                    default-directory)))
         (local (mvue--local-server root))
         (version (car local))
         (js (cdr local)))
    (cond
     ;; 1) 工程内（推荐：版本随项目走）
     (js
      (mvue--check-server-version version root)
      (append (list (mvue--node) js "--stdio")
              (list :initializationOptions (mvue--initialization-options root version))))
     ;; 2) 全局 vue-language-server
     ((executable-find "vue-language-server")
      (let ((program (executable-find "vue-language-server")))
        (setq version (mvue--probe-version program))
        (mvue--check-server-version version root)
        (append (list program "--stdio")
                (list :initializationOptions (mvue--initialization-options root version)))))
     (t (user-error "找不到 vue-language-server。请在项目里执行：npm i -D @vue/language-server@2.2.10 typescript")))))

(defun mvue--check-server-version (version root)
  "VERSION 不认 Vue 2 就直接报错，别让 eglot 干等（Volar 3 会一直挂着）。"
  (when (string-prefix-p "3." version)
    (user-error
     (concat "检测到 @vue/language-server %s（%s）。\n"
             "Volar 3.1 起已删除 Vue 2 支持，3.0 起又要求编辑器桥接 tsserver（eglot 不桥接）。\n"
             "请在项目里执行：npm i -D @vue/language-server@2.2.10 typescript@~5.6.3")
     version (abbreviate-file-name root))))

;;; 注册服务器：.vue -> vue2-web-mode -> languageId "vue" -> Volar
(add-to-list 'eglot-server-programs
             (cons (list 'vue2-web-mode :language-id "vue")
                   #'mvue--server-contact))

;;; 注册服务器 solidity
;; nomicfoundation-solidity-language-server 必须带 --stdio：
;; 它的 ConnectionStrategy 只在 argv 里有参数时才解析，裸跑会直接
;; "Connection input stream is not set" 退出（exit 1），
;; eglot 于是报 "[eglot] -1: Server died"，M-. 没有 backend，自然跳不动。
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '(solidity-mode . ("nomicfoundation-solidity-language-server" "--stdio"))))
(add-hook 'solidity-mode-hook #'eglot-ensure)
(setq eglot-extend-to-xref t)


;;; --------------------------------------------------------------------------
;;; 7b.6. 每个 .vue buffer 的接线：eglot、company、xref 快捷键
;;; --------------------------------------------------------------------------
(defun mvue--bind-keys ()
  "统一 M-. / M-? / M-,，覆盖 major mode 自带绑定。"
  (local-unset-key (kbd "M-."))
  (local-unset-key (kbd "M-?"))
  (local-set-key (kbd "M-.") #'xref-find-definitions)
  (local-set-key (kbd "M-?") #'xref-find-references)
  (local-set-key (kbd "M-,") #'xref-go-back)
  (local-set-key (kbd "M-g .") #'xref-find-definitions-other-window))

(defvar mvue--warned-no-server nil
  "只提示一次「没装服务器」。")

(defun mvue--ensure-eglot ()
  "有可用的服务器才连；连不上只提示，不打断开文件。"
  (cond
   ((or (mvue--local-server (mvue--locate-root))
        (executable-find "vue-language-server"))
    (condition-case err
        (eglot-ensure)
      (error (message "[vue2] 语言服务器未启动：%s"
                      (error-message-string err)))))
   ((not mvue--warned-no-server)
    (setq mvue--warned-no-server t)
    (message (concat "[vue2] 没找到 vue-language-server。请在项目里执行："
                     "npm i -D @vue/language-server@2.2.10 typescript@~5.6.3")))))

(defun mvue--setup-buffer--1 ()
  "vue2-web-mode 的 buffer 级设置（真正干活的部分）。"
  ;; 补全交给 LSP，避免 dabbrev / 其他后端抢候选
  (when (fboundp 'company-mode)
    (setq-local company-backends '(company-capf))
    (setq-local company-minimum-prefix-length 1)
    (setq-local company-idle-delay 0.1))
  ;; M-. 别弹「找哪个」直接跳
  (setq-local xref-prompt-for-identifier nil)
  ;; 大工程 volar 首次索引会慢，超时放宽
  (when (< eglot-connect-timeout 60) (setq-local eglot-connect-timeout 120))
  (mvue--bind-keys)
  (when mvue-prettier-on-save
    (add-hook 'before-save-hook #'mvue-prettier-buffer nil t)))

(defun mvue--setup-buffer ()
  "vue2-web-mode 的 buffer 级设置。
包一层 `condition-case`：万一某一步出岔子，也不会把 mode hook 里排在后面的
`mvue--ensure-eglot' 一起带崩（现象是打开 .vue 报 File mode specification error）。"
  (condition-case err
      (mvue--setup-buffer--1)
    (error (message "[vue2] buffer 设置出错（不影响继续用）：%s"
                    (error-message-string err)))))

(add-hook 'vue2-web-mode-hook #'mvue--setup-buffer)
(add-hook 'vue2-web-mode-hook #'mvue--ensure-eglot)

;;; --------------------------------------------------------------------------
;;; 7b.7. 保存时用 prettier 格式化（走项目里的 prettier，找不到就安静跳过）
;;; --------------------------------------------------------------------------
(defun mvue-prettier-buffer ()
  "用 prettier 格式化当前 .vue buffer，保持光标位置不变。"
  (interactive)
  (when-let* ((file (buffer-file-name))
              (program (executable-find mvue-prettier-program)))
    (let ((point-before (point))
          (out (generate-new-buffer " *mvue-prettier*")))
      (unwind-protect
          (let ((status (ignore-errors
                          (call-process-region (point-min) (point-max)
                                               program nil out nil
                                               "--stdin-filepath" file))))
            (when (and (numberp status) (zerop status))
              (let ((text (with-current-buffer out (buffer-string))))
                (when (and (not (string-empty-p text))
                           (not (string= text (buffer-string))))
                  (let ((inhibit-message t))
                    (save-restriction
                      (widen)
                      (delete-region (point-min) (point-max))
                      (insert text)
                      (goto-char (min point-before (point-max)))))))))
        (kill-buffer out)))))

;;; --------------------------------------------------------------------------
;;; 7b.8. 排障命令
;;; --------------------------------------------------------------------------
(defun mvue--tsconfig-file (root)
  "工程里第一个存在的 tsconfig/jsconfig。"
  (seq-find #'file-exists-p
            (mapcar (lambda (f) (expand-file-name f root))
                    '("tsconfig.json" "jsconfig.json" "tsconfig.app.json"))))

(defun mvue--diagnose (&optional directory)
  "返回一份环境自检报告（字符串列表）。"
  (let* ((root (file-name-as-directory (or directory (mvue--locate-root))))
         (local (mvue--local-server root))
         (tsconfig (mvue--tsconfig-file root))
         (vue-pkg (mvue--read-json (expand-file-name "node_modules/vue/package.json" root)))
         (buf (get-buffer-create " *mvue-diag*"))
         (lines nil))
    (cl-flet ((add (fmt &rest args) (push (apply #'format fmt args) lines)))
      (add "工程根: %s" (abbreviate-file-name root))
      (add "Emacs: %s / eglot: %s" emacs-version
           (or (ignore-errors (file-name-directory (locate-library "eglot"))) "内置"))
      (add "node: %s" (or (executable-find "node") "❌ 找不到 node"))
      (add "vue (项目): %s" (or (alist-get 'version vue-pkg) "❌ 没装 vue"))
      (cond
       (local (add "语言服务器: %s (%s)"
                   (cdr local)
                   (if (string-prefix-p "2." (car local))
                       (concat "v" (car local) " ✅ 支持 Vue 2")
                     (format "v%s %s" (car local)
                             (if (string-prefix-p "1." (car local))
                                 "✅ Volar 1（Vue 2.6）"
                               "❌ Volar 3 不认 Vue 2，请降到 2.2.10")))))
       ((executable-find "vue-language-server")
        (add "语言服务器: %s (v%s，全局)"
             (executable-find "vue-language-server")
             (mvue--probe-version (executable-find "vue-language-server"))))
       (t (add "语言服务器: ❌ 没找到，执行 npm i -D @vue/language-server@2.2.10")))
      (add "typescript sdk: %s" (or (mvue--tsdk root) "❌ 工程里没装 typescript"))
      (if tsconfig
          (with-temp-buffer
            (insert-file-contents tsconfig)
            (let ((target (and (re-search-forward
                                "\"target\"[ \t]*:[ \t]*\\([0-9.]+\\)" nil t)
                               (match-string 1))))
              (add "%s: vueCompilerOptions.target = %s %s"
                   (file-name-nondirectory tsconfig)
                   (or target "❌ 未设置")
                   (cond ((null target) "→ 会报 Target version mismatch")
                         ((and (equal target "2.7") (string-prefix-p "2.7" (or (alist-get 'version vue-pkg) ""))) "✅")
                         ((and (equal target "2") (string-prefix-p "2." (or (alist-get 'version vue-pkg) ""))) "✅")
                         (t "⚠ 请与项目 vue 版本对应（2.6→2，2.7→2.7）")))))
        (add "❌ 没有 tsconfig.json / jsconfig.json（别名 @/ 与 vueCompilerOptions 都要放这里）"))
      (add "prettier: %s" (or (executable-find mvue-prettier-program) "（可选）未安装"))
      (add "当前 buffer: %s / %s / eglot=%s"
           (buffer-name) major-mode
           (if (eglot-current-server) "已连接" "未连接")))
    (kill-buffer buf)
    (nreverse lines)))

(defun mvue-doctor (&optional directory)
  "显示环境自检报告。"
  (interactive)
  (with-output-to-temp-buffer "*mvue-doctor*"
    (princ "Vue 2 + eglot 环境自检\n")
    (princ "────────────────────\n")
    (dolist (line (mvue--diagnose directory)) (princ (concat line "\n"))))
  (with-current-buffer "*mvue-doctor*" (special-mode)))

(defun mvue-events ()
  "打开当前 eglot 连接的 LSP 收发日志（排障用）。"
  (interactive)
  (if-let* ((server (eglot-current-server)))
      (pop-to-buffer (jsonrpc-events-buffer server))
    (user-error "当前 buffer 没有 eglot 连接")))

(defun mvue-restart-server ()
  "重启当前工程的语言服务器。"
  (interactive)
  (if-let* ((server (eglot-current-server)))
      (progn (eglot-shutdown server) (eglot-ensure))
    (eglot-ensure)))

(defun mvue--goto-lsp-range (range)
  "把 point 移到 LSP RANGE 的起点（RANGE 是 plist）。"
  (when range
    (let ((start (plist-get range :start)))
      (goto-char (point-min))
      (forward-line (or (plist-get start :line) 0))
      (move-to-column (or (plist-get start :character) 0)))))

(defun mvue--definition-at-point ()
  "取当前位置的定义，返回 (FILE . RANGE)；拿不到返回 nil。"
  (let* ((res (ignore-errors
                (eglot--request (eglot-current-server) :textDocument/definition
                                (eglot--TextDocumentPositionParams) :timeout 30)))
         (item (car (append res nil)))
         (uri (or (plist-get item :targetUri) (plist-get item :uri))))
    (when (and uri (string-prefix-p "file:" uri))
      (cons (eglot-uri-to-path uri)
            (or (plist-get item :targetSelectionRange)
                (plist-get item :targetRange)
                (plist-get item :range))))))

(defun mvue-find-component ()
  "从 .vue 里的组件标签/符号一路跳到它真正的文件。
Volar 的 definition 是一跳一跳给的（模板标签 → script 里 `components: {...}'
的注册处 → import 的名字 → 组件文件），这里把这几跳自动走完，
等价于 VSCode 里 Ctrl+点击组件标签。"
  (interactive)
  (unless (eglot-current-server) (user-error "当前 buffer 没有 eglot 连接"))
  (let ((origin (or buffer-file-name (user-error "当前 buffer 没有关联文件")))
        (hops 0)
        (arrived nil))
    (catch 'done
      (while (< hops 6)
        (setq hops (1+ hops))
        (let ((def (mvue--definition-at-point)))
          (cond
           ((null def) (throw 'done nil))          ; 没有结果，退出后用 xref 兜底
           ((file-equal-p (car def) origin)        ; 还在本文件里，继续追
            (mvue--goto-lsp-range (cdr def)))
           (t (xref-push-marker-stack)
              (find-file (car def))
              (mvue--goto-lsp-range (cdr def))
              (setq arrived t)
              (throw 'done nil))))))
    (unless arrived
      (call-interactively #'xref-find-definitions))))

(defvar-keymap mvue-command-map
  :doc "Vue 2 辅助命令"
  "d" #'mvue-doctor
  "e" #'mvue-events
  "r" #'mvue-restart-server
  "f" #'mvue-prettier-buffer
  "g" #'mvue-find-component)

;; 注意：major mode 不会 provide feature，所以这里直接 keymap-set，
;; 不要用 with-eval-after-load（那样子永远不会执行）。
(keymap-set vue2-web-mode-map "C-c v" mvue-command-map)


;;; --------------------------------------------------------------------------
;;; 8. 加入rg搜索配置
;;; --------------------------------------------------------------------------
(use-package rg
  :ensure t
  :config
  ;; 调用系统rg，scoop装的rg自动在PATH，直接识别

  ;; Windows 专用：命令行参数必须按系统 ANSI 代码页（本机 936/GBK）编码。
  ;; 否则中文关键字会被 cmdproxy 丢弃——缓冲区里会出现
  ;; "warning: extra args ignored after ..."，rg 实际搜不到东西、退出码 1，
  ;; 于是编译框架报 "rg exited abnormally with code 1"。
  (when (eq system-type 'windows-nt)
    (defun my/rg-ansi-command-line (fn &rest args)
      "Bind `coding-system-for-write' to the ANSI codepage around rg."
      (let ((coding-system-for-write
             (coding-system-change-eol-conversion
              (intern (format "cp%d" (if (boundp 'w32-ansi-code-page)
                                         w32-ansi-code-page
                                       936)))
              'dos)))
        (apply fn args)))
    (advice-add 'rg-run :around #'my/rg-ansi-command-line)
    (advice-add 'rg-recompile :around #'my/rg-ansi-command-line))
  )
