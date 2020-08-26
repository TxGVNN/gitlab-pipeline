;;; gitlab-pipeline.el --- Get infomations of Gitlab pipelines

;; Copyright (C) 2020 Giap Tran <txgvnn@gmail.com>

;; Author: Giap Tran <txgvnn@gmail.com>
;; URL: https://github.com/TxGVNN/gitlab-pipeline
;; Version: 1.0.0
;; Package-Requires: ((emacs "25.1") (ghub "3.3.0"))
;; Keywords: comm, tools, git

;; This file is NOT part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; M-x gitlab-pipeline-show-sha

;;; Code:

(require 'glab)
(require 'ansi-color)

(defun gitlab-pipeline-show-pipeline-from-sha(project-id sha)
  "Show pipeline at SHA of PROJECT-ID in new buffer."
  (with-current-buffer (get-buffer-create (format "*Gitlab-CI:/projects/%s/pipelines?sha=%s" project-id sha))
    (erase-buffer)
    (let ((pipelines) (pipeline) (pipeline_id)
          (jobs) (job) (job_id) (i 0) (j))
      (setq pipelines (glab-get (format "/projects/%s/pipelines?sha=%s" project-id sha)))
      (while (< i (length pipelines))
        (setq pipeline (elt pipelines i))
        (setq pipeline_id (cdr (assoc 'id pipeline)))
        (insert (format "* [%s] pipeline: %s %s\n" (cdr (assoc 'status pipeline)) pipeline_id (cdr (assoc 'web_url pipeline))))
        (setq jobs (glab-get (format "/projects/%s/pipelines/%s/jobs" project-id pipeline_id)))
        (setq j 0)
        (while (< j (length jobs))
          (setq job (elt jobs j))
          (setq job_id (cdr (assoc 'id job)))
          (insert (format "   - [%s] job: %s@%s %s:%s"  (cdr (assoc 'status pipeline))
                          job_id
                          (cdr (assoc 'ref job))
                          (cdr (assoc 'stage job))
                          (cdr (assoc 'name job))))
          (put-text-property (line-beginning-position) (+ (line-beginning-position) 1) 'invisible (format "/projects/%s/jobs/%s/trace" project-id job_id))
          (end-of-line)
          (insert "\n")
          (setq j (+ j 1)))
        (insert "\n")
        (setq i (+ i 1))))
    (goto-char (point-min))
    (switch-to-buffer (current-buffer))))

;;;###autoload
(defun gitlab-pipeline-show-sha ()
  "Gitlab-pipeline-show-sha-at-point (support magit buffer)."
  (interactive)
  (let* ((origin (shell-command-to-string "git remote get-url origin"))
         (repo (url-hexify-string (replace-regexp-in-string "^.*+gitlab.com[:/]?\\(.*\\)\\(\.git\\)\n?" "\\1" origin)))
         (sha))
    (if (fboundp 'magit-commit-at-point) (setq sha (magit-commit-at-point)))
    (unless (string-match-p "gitlab.com" origin)
      (error "Only support gitlab service"))
    (unless sha (setq sha (read-string "Rev: ")))
    (setq sha (replace-regexp-in-string "\n" "" (shell-command-to-string (format "git rev-parse %s" sha))))
    (gitlab-pipeline-show-pipeline-from-sha repo sha)))

;;;###autoload
(defun gitlab-pipeline-job-trace-at-point ()
  "Gitlab pipeline job trace at point."
  (interactive)
  (let ((path (get-text-property (line-beginning-position) 'invisible)))
    (when path
      (with-current-buffer (get-buffer-create (format "*Gitlab-CI:%s" path))
        (erase-buffer)
        (insert (cdr (car (glab-get path))))
        (goto-char (point-min))
        (while (re-search-forward "" nil t)
          (replace-match "\n" nil nil))
        (ansi-color-apply-on-region (point-min) (point-max))
        (switch-to-buffer (current-buffer))))))

;;;###autoload
(defun gitlab-pipeline-job-cancel-at-point ()
  "Gitlab pipeline job cancel at point."
  (interactive)
  (let ((path (get-text-property (line-beginning-position) 'invisible)))
    (when path
      (with-current-buffer (get-buffer-create (format "*Gitlab-CI:%s:DELETE" path))
        (erase-buffer)
        (insert (cdr (car (glab-delete path))))
        (goto-char (point-min))
        (while (re-search-forward "" nil t)
          (replace-match "\n" nil nil))
        (ansi-color-apply-on-region (point-min) (point-max))
        (switch-to-buffer (current-buffer))))))

;;; gitlab-pipeline.el ends here
(provide 'gitlab-pipeline)
