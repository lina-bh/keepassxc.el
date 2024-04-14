;; -*- lexical-binding: t; -*-
(defgroup keepassxc nil
  "Get KeePass credentials from inside Emacs.")

(defcustom keepassxc-database nil
  "The path to your KeePass database."
  :group 'keepassxc
  :type '(file :must-match t))

(defun keepassxc--get-database ()
  (expand-file-name keepassxc-database))

(defun keepassxc--get-passphrase ()
  (or keepassxc--passphrase
      (error "`keepassxc--passphrase' nil")))

(defun keepassxc--call (&rest args)
  (with-temp-buffer
    (let* ((exit (apply #'call-process-region
                        (concat (keepassxc--get-passphrase) "\n")
                        nil "keepassxc-cli" nil t nil args))
           (output (progn
                     (goto-char (point-min))
                     (search-forward "\n")
                     (buffer-substring (point) (- (point-max) 1)))))
      (if (= exit 0)
          output
        (error "%s" output)))))

(defun keepassxc--ls ()
  "Return a list of all entries in `keepassxc-database'."
  (string-lines (keepassxc--call "ls" "-Rf" (keepassxc--get-database))))

(defun keepassxc--show-attribute (entry key)
  "Return attribute KEY in ENTRY from `keepassxc-database'."
  (keepassxc--call "show" "-a" key (keepassxc--get-database) entry))

(defun keepassxc--show-totp (entry)
  "Return TOTP code from ENTRY in `keepassxc-database'."
  (keepassxc--call "show" "-t" (keepassxc--get-database) entry))

(defmacro keepassxc--with-password (&rest body)
  "Read passphrase from minibuffer and execute BODY."
  `(if keepassxc-database
       (let ((keepassxc--passphrase (read-passwd "Passphrase: ")))
         (unwind-protect
             (progn ,@body)
           (clear-string keepassxc--passphrase)))
     (user-error "Set `keepassxc-database' to the path to your database.")))

(defun keepassxc--read-entry ()
  (completing-read "Entry: " (keepassxc--ls) nil t))

;;;###autoload
(defun keepassxc-password ()
  "Insert password from KeePass database."
  (interactive)
  (insert (keepassxc--with-password
           (keepassxc--show-attribute (keepassxc--read-entry) "Password"))))

;;;###autoload
(defun keepassxc-totp ()
  "Copy TOTP 2FA code from KeePass database."
  (interactive)
  (let ((totp (keepassxc--with-password
               (keepassxc--show-totp (keepassxc--read-entry)))))
    (kill-new totp)
    (message "%s saved to kill ring" totp)))

(provide 'keepassxc)
