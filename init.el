;;; init.el --- Anson 的 Emacs 配置 -*- lexical-binding: t; -*-
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

;; Linux / macOS 共用：elan、用户本地 bin、nvm 的 node。
(mapc #'my/add-bin-to-path
      (append
       (list (expand-file-name "~/.elan/bin")
             (expand-file-name "~/.local/bin"))
       (file-expand-wildcards
        (expand-file-name "~/.nvm/versions/node/*/bin"))))

;;; --------------------------------------------------------------------------
;;; 3. 界面
;;; --------------------------------------------------------------------------
(setq inhibit-startup-message t
      visible-bell t
      line-spacing 0.1)
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

(use-package dracula-theme
  :config
  (load-theme 'dracula t))

;; 仅图形界面生效。GTK/WSL 必须用 "Family-SIZE"，只改 :height 不会变。
(setq my/font-family "Maple Mono NF"
      my/font-size 10) ; 单位 pt，建议 8–18

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
(auto-save-visited-mode 1) ; 自动把已访问文件写回磁盘
(put 'upcase-region 'disabled nil)

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
;;; 7. TypeScript / TSX / JS
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

;;; --------------------------------------------------------------------------
;;; 8. Markdown
;;; --------------------------------------------------------------------------
(use-package markdown-mode
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :bind (:map markdown-mode-map
              ("C-c C-c p" . markdown-preview-mode))
  :config
  (setq markdown-command "pandoc"))

(use-package markdown-preview-mode
  :after markdown-mode
  :config
  (setq markdown-preview-stylesheets
        (list "https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.1.0/github-markdown.min.css")
        markdown-preview-javascript
        (list "https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.1.0/github-markdown.min.css")))

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
;;; 9. Lean 4
;;; --------------------------------------------------------------------------
(add-to-list 'load-path (expand-file-name "lean4-mode" user-emacs-directory))
(require 'lean4-mode)
(setq lean4-show-goal-buttons nil)
;; lean4-mode 默认 hook 是 lsp-mode 的 #'lsp，和 eglot 冲突。
(remove-hook 'lean4-mode-hook #'lsp)
(add-hook 'lean4-mode-hook #'my/bind-xref-keys)
(add-hook 'lean4-mode-hook
          (lambda ()
            (local-set-key (kbd "C-c C-g") #'lean4-toggle-info-buffer)
            (local-set-key (kbd "M-/") #'company-complete)))

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
  (setq vterm-shell (or (getenv "SHELL") "/bin/bash")))

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

(when (and (eq system-type 'gnu/linux)
           (getenv "WSL_DISTRO_NAME"))
  (my/add-bin-to-path "/mnt/c/Windows/System32")
  ;; M-w：同时写入 Emacs kill-ring 和 Windows 剪贴板。
  (defun wsl-clipboard-kill-ring-save (beg end)
    (interactive "r")
    (kill-ring-save beg end)
    (let ((text (buffer-substring-no-properties beg end)))
      (with-temp-buffer
        (insert text)
        (call-process-region (point-min) (point-max) "clip.exe"))))
  (global-set-key [remap kill-ring-save] #'wsl-clipboard-kill-ring-save)
  ;; M-v：从 Windows 剪贴板粘贴到 Emacs。
  (defun wsl-paste-from-windows ()
    (interactive)
    (let ((text (shell-command-to-string "powershell.exe -Command Get-Clipboard")))
      (insert text)))
  (global-set-key (kbd "M-v") #'wsl-paste-from-windows))

;;; --------------------------------------------------------------------------
;;; 14. Custom（Emacs 自动写入，保持在文件末尾）
;;; --------------------------------------------------------------------------
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages nil))
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
           (getenv "DISPLAY"))
  (use-package exwm
    :ensure t
    :config

    ;; Basic configuration
    (require 'exwm)
    (require 'exwm-config)
    (require 'exwm-systemtray)
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

    ;; Enable system tray
    (exwm-systemtray-enable)

    ;; Start EXWM
    (exwm-enable)))


(defun open-chrome ()
  "open google chrome browser."
  (interactive)
  (start-process "chrome" nil "chromium-browser"))
;; then bind it to a key
(global-set-key (kbd "C-c w") 'open-chrome)
  
