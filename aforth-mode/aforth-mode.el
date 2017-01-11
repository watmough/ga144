(require 'jit-lock)
(require 'aforth-parse)

(defvar aforth-mode-hook nil)

(setq aforth-instruction-list '("ret" "nop""ex" "jump" "call" "unext" "next" "if"
                                "and" "or" "drop" "dup" "pop" "over" "a" "push"
                                "@+" "!+" "+*" "2*" "2/" "!p"  "!b" "!" "-if"
                                ";" "." "-" "+"  "@p" "@b" "@" "b!" "a!"))

(setq aforth-port-list '("up" "left" "down" "right" "io"
                         "north" "east" "south" "west"))

(setq aforth-directive-list '("start" "for" "begin" "then" "here"
                              "while"  "reclaim" "leap"
                              ".." "#swap" "-while" "," "-until"
                              "---u" "--l-" "--lu" "-d--" "-d-u"
                              "-dl-" "-dlu" "r---" "r--u" "r-l-"
                              "r-lu" "rd--" "rd-u" "rdl-" "rdlu"
                              "node" "org" "::"))

(setq boot-descriptors-list '("/b" "/a" "/io" "/p" "/stack"))

(defun list-to-set (lst)
  (let ((ht (make-hash-table :test 'equal :size (* (length lst) 2))))
    (dolist (x lst)
      (puthash x t ht))
    ht))

(defun set-member? (set key)
  (gethash key set))

(setq aforth-instruction-map (list-to-set aforth-instruction-list))
(setq aforth-port-map (list-to-set aforth-port-list))
(setq aforth-directive-map (list-to-set aforth-directive-list))
(setq boot-descriptors-map (list-to-set boot-descriptors-list))


(defface aforth-instruction-face '((((background light)) (:foreground "green"))
                                   (((background dark)) (:foreground "green")))
  "Default face for arrayforth instructions")

(defface aforth-directive-face '((((background light)) (:foreground "yellow"))
                                 (((background dark)) (:foreground "yellow")))
  "Default face for arrayforth compiler directives")

(defface aforth-number-face '((((background light)) (:foreground "LightGreen"))
                              (((background dark)) (:foreground "LightGreen")))
  "Default face for arrayforth numbers")

(defface aforth-word-face '((((background light)) (:foreground "red"))
                            (((background dark)) (:foreground "red")))
  "Default face for arrayforth word definitions")

(defface aforth-boot-descriptor-face '((((background light))
                                        (:foreground "maroon"))
                                       (((background dark))
                                        (:foreground "maroon")))
  "Default face for arrayforth boot descriptors")

(defface aforth-word-reference-face '((((background light))
                                       (:foreground "DeepPink"))
                                      (((background dark))
                                       (:foreground "DeepPink")))
  "Default face for arrayforth boot descriptors")

(defface aforth-comment-face '((((background light))
                                (:foreground "grey"))
                               (((background dark))
                                (:foreground "grey")))
  "Default face for arrayforth comments")

(defface aforth-remote-coord-face '((((background light))
                                     (:foreground "orange"))
                                    (((background dark))
                                     (:foreground "orange")))
  "Default face for arrayforth boot descriptors")


(setq aforth-instruction-face 'aforth-instruction-face)
(setq aforth-directive-face 'aforth-directive-face)
(setq aforth-word-face 'aforth-word-face)
(setq aforth-number-face 'aforth-number-face)
(setq aforth-boot-descriptor-face 'aforth-boot-descriptor-face)
(setq aforth-remote-coord-face 'aforth-remote-coord-face)
(setq aforth-comment-face 'aforth-comment-face)

(setq aforth-buffer-words nil)
(setq aforth-next-id nil)
(setq aforth-current-str nil)
(setq aforth-current-pt nil)

(make-variable-buffer-local 'aforth-buffer-words)
(make-variable-buffer-local 'aforth-next-id)
(make-variable-buffer-local 'aforth-current-str)
(make-variable-buffer-local 'aforth-current-pt)

(defun aforth-get-token-face (token)
  (cond ((equal token ":") aforth-word-face)
        ((gethash token aforth-instruction-map) aforth-instruction-face)
        ((gethash token aforth-port-map) aforth-instruction-face)
        ((gethash token aforth-directive-map) aforth-directive-face)
        ((gethash token boot-descriptors-map) aforth-boot-descriptor-face)
        ((string-match "^\\(\\(0x[0-9a-fA-F]+\\)\\|\\(0b[01]+\\)\\|[0-9]+\\)$" token) aforth-number-face)
        ((string-match "&[a-zA-Z0-9]+" token)  aforth-word-reference-face)
        ;;TODO: <word>@<node> word=white @node=green

        ))

(defun aforth-make-overlay (beg end)
  (let ((overlay (make-overlay beg end)))
    (overlay-put overlay 'aforth-id aforth-next-id)
    (setq aforth-next-id (1+ aforth-next-id))
    overlay))

(defun aforth-overlay-id (overlay)
  (overlay-get overlay 'aforth-id))

;;TODO: make buffer local

(setq aforth-parse-data (make-hash-table)) ;;map lines to token listss

(defun aforth-current-node (&optional forward)
  (let ((found nil)
        (node nil)
        (re "node[ \t\n]+\\([0-9]+\\)")
        p)
    (save-excursion
      ;;(end-of-line)
      (while (not found)
        (if (if forward
                (re-search-forward re nil :noerror)
              (re-search-backward re nil :noerror))
            (progn (setq node (match-string 1))
                   (unless (aforth-comment-at-point-p (point))
                     (setq p (point)
                           found t)))
          (setq found t))))
    (and node (cons (string-to-number node) p))))

(defun aforth-back-to-node ()
  (interactive)
  (let ((point (aforth-current-node)))
    (when point
      (goto-char (cdr point)))))

(defun aforth-goto-next-node ()
  (interactive)
  (let ((point (aforth-current-node :forward)))
    (when point
      (goto-char (cdr point)))))

(defun test ()
  (interactive)
  (aforth-back-to-node))



(defsubst pop! (lst)
  (prog1 (car lst)
    (setcar lst (cadr lst))
    (setcdr lst (cddr lst))))

(defun aforth-make-error (message token)
  )


(defun aforth-error (msg)
  (message "aforth-error: %s" msg)
  (error msg))

(defun get-token-faces (type)
  (cond ((eq type 'r-reference) ;; & name @ node
         '(aforth-word-reference-face
           aforth-word-reference-face
           aforth-directive-face
           aforth-directive-face))
        ((eq type 'r-call)  ;; name @ node
         '(nil
           aforth-directive-face
           aforth-directive-face))
        (t (error "unknown sub token type: %s" type)))  )

(defun aforth-update-overlays (tokens)
  "list of TOKENS from `aforth-parse-region`"
  (let (start end face type o points faces point subtoks o)
    (dolist (token tokens)
      (setq type (aforth-token-type token)
            beg (aforth-token-start token)
            end (aforth-token-end token)
            subtoks (aforth-token-subtoks token)
            face (cond ((or (eq type 'directive)
                            (eq type 'compile-def))
                        aforth-directive-face)
                       ((eq type 'word-def)
                        aforth-word-face)
                       ((eq type 'number)
                        aforth-number-face)
                       ((eq type 'op)
                        aforth-instruction-face)
                       ((eq type 'comment)
                        aforth-comment-face)
                       ((eq type 'reference)
                        aforth-word-reference-face)
                       ((eq type 'boot-descriptor)
                        aforth-boot-descriptor-face)
                       ((or (eq type 'r-reference)
                            (eq type 'r-call)
                            (eq type 'call))
                        nil)
                       (t  (error "unknown token type: %s" type))))
      (when subtoks
        (dolist (face (get-token-faces type))
          (setq point (car subtoks)
                subtoks (cdr subtoks))
          (when face
            (setq o (make-overlay (car point) (cdr point)))
            (overlay-put o 'face face))))

      ;;for subtok tokens face is nil, create this overlay anyways for token position reference
      (assert (and beg end))
      (setq o (make-overlay beg end))
      (and face (overlay-put o 'face face))
      (setf (aforth-token-overlay token) o)
      )))

(defun aforth-parse-buffer ()
  (widen)
  (save-excursion
    (aforth-parse-region (point-min) (point-max))))

(defun aforth-remove-overlays (beg end)
  (dolist (o (overlays-in beg end))
    (delete-overlay o)
    ))

(defun aforth-update-region (beg end &optional _old-len)
  "After-change function updating overlays"
  (let ((start-time (current-time))
        (beg-line (save-excursion (goto-char beg) (line-beginning-position)))
        (end-line (save-excursion (goto-char end) (line-end-position)))
        tokens)
    ;;multiple token constructs may span multiple lines, but that style is ugly and not supported. syntax coloring may break
    (aforth-remove-overlays beg-line end-line)
    (set-text-properties beg-line end-line nil)
    (setq tokens (aforth-parse-region beg-line end-line))
    (aforth-update-overlays tokens)
    (message "parsed region [%s %s] in %s seconds (%s tokens)" beg end (float-time (time-since start-time)) (length tokens)))
  )

(defun aforth-update-region (beg end &optional _old-len)
  (condition-case err
      (aforth-update-region3 beg end _old-len)
    (error (message "mbs error: %s" err))))

(defun aforth-create-index ()
  (let* ((aforth-defining-words-regexp
	  ;;(concat "\\<\\(" (regexp-opt aforth-defining-words) "\\)\\>")
          (concat "\\(" (regexp-opt aforth-defining-words) "\\)")
          )
	 (index nil))
    (goto-char (point-min))
    (while (aforth-next-definition-starter)
      (if (looking-at "[ \t]*\\([^ \t\n]+\\)")
	  (setq index (cons (cons (match-string 1) (point)) index))))
    index))

(setq aforth-mode-map
      (let ((map (make-sparse-keymap 'aforth-mode-map)))
        (define-key map (kbd "C-M-a") 'aforth-back-to-node)
        (define-key map (kbd "C-M-e") 'aforth-goto-next-node)
        map))

(define-derived-mode aforth-mode prog-mode "aforth2"
  "Major mode for editing aforth files"

  (setq imenu-create-index-function 'aforth-create-index)
  (widen)
  (use-local-map aforth-mode-map)
  (progn (jit-lock-register 'aforth-update-region)
         (setq aforth-buffer-words (make-hash-table)
               aforth-next-id 1))
  ;;(jit-lock-unregister 'aforth-update-region))

  (setq imenu-create-index-function 'aforth-create-index)

  (aforth-update-region (point-min) (point-max))
  (run-hooks 'aforth-mode-hook))

(add-to-list 'auto-mode-alist '("\\.aforth\\'" . aforth-mode))

(provide 'aforth-mode)
