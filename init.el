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
          "ANTHROPIC_API_KEY" "OPENAI_API_KEY" "OPENROUTER_API_KEY"))
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

;;; --------------------------------------------------------------------------
;;; 5. 补全
;;; --------------------------------------------------------------------------
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
;;; 8. LSP（eglot）
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
(use-package treemacs
  :config
  (treemacs-follow-mode t)
  (treemacs-filewatch-mode t)
  (treemacs-git-mode 'simple)
  (setq treemacs-position 'left)
  :bind
  ("C-x t t" . treemacs)
  ("C-x t r" . treemacs-refresh)
  ("C-x t p" . treemacs-add-project))

(use-package vterm
  :bind ("C-x v" . vterm)
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

;;; --------------------------------------------------------------------------
;;; 12. AI
;;; --------------------------------------------------------------------------
;; 密钥不要写进本文件。任选其一：
;;   环境变量 ANTHROPIC_API_KEY / OPENAI_API_KEY
;;   ~/.authinfo ：machine api.anthropic.com login apikey password sk-ant-...
;; Claude Code 用本机 CLI（~/.local/bin/claude），不从 GitHub 拉包
;; （:vc 在这边会 Empty checkout，拖垮整个 init.el）。

(defvar my/claude-buffer "*claude-code*")

(defun my/claude-project-root ()
  (or (when-let ((p (project-current nil)))
        (project-root p))
      default-directory))

(defun my/claude-start ()
  "在当前工程根目录启动 Claude Code。"
  (interactive)
  (let ((root (my/claude-project-root))
        (buf my/claude-buffer))
    (if (get-buffer buf)
        (pop-to-buffer buf)
      (let ((default-directory root))
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
        gptel-api-key (lambda ()
                        (or (getenv "ANTHROPIC_API_KEY")
                            (getenv "OPENAI_API_KEY")
                            (getenv "OPENROUTER_API_KEY"))))
  (when (or (getenv "ANTHROPIC_API_KEY")
            (file-exists-p (expand-file-name "~/.authinfo"))
            (file-exists-p (expand-file-name "~/.authinfo.gpg")))
    (setq gptel-model 'claude-sonnet-4-6
          gptel-backend (gptel-make-anthropic "Claude"
                          :stream t
                          :key gptel-api-key))))
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
