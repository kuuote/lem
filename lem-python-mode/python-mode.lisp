(defpackage :lem-python-mode
  (:use :cl :lem :lem.language-mode)
  (:export :python-mode
           :*python-mode-hook*))
(in-package :lem-python-mode)

(defvar *python-mode-hook* '())

(defun tokens (boundary strings)
  (let ((alternation
         `(:alternation ,@(sort (copy-list strings) #'> :key #'length))))
    (if boundary
        `(:sequence ,boundary ,alternation ,boundary)
        alternation)))

(defun make-tm-string-region (sepalator)
  (make-tm-region `(:sequence ,sepalator)
                  `(:sequence ,sepalator)
                  :name 'syntax-string-attribute
                  :patterns (make-tm-patterns (make-tm-match "\\\\."))))

(defun floating-point-literals ()
  (let* ((digitpart "([0-9](_?[0-9])*)")
         (fraction (format nil "\\.(~a)" digitpart))
         (exponent (format nil "((e|E)(\\+|\\-)?(~a))" digitpart))
         (pointfloat (format nil "(((~a)?(~a))|((~a)\\.))" digitpart fraction digitpart))
         (exponentfloat (format nil "(((~a)|(~a))(~a))" digitpart pointfloat exponent)))
    (format nil "\\b((~a)|(~a))\\b" pointfloat exponentfloat)))

#| link : https://docs.python.org/3/reference/lexical_analysis.html |#
(defun make-tmlanguage-python ()
  (let* ((integer-literals "\\b(([1-9](_?[0-9])*)|(0(_?0)*)|(0(b|B)(_?[01])+)|(0(o|O)(_?[0-7])+)|(0(x|X)(_?[0-9a-fA-F])+))\\b")
         (floating-point-literals (floating-point-literals))
         (patterns (make-tm-patterns
                    (make-tm-region "#" "$" :name 'syntax-comment-attribute)
                    (make-tm-match (tokens :word-boundary
                                           '("and" "as"
                                             "assert" "break" "class" "continue" "def"
                                             "del" "elif" "else" "except" "finally"
                                             "for" "from" "global" "if" "import"
                                             "in" "is" "lambda" "nonlocal" "not"
                                             "or" "pass" "raise" "return" "try"
                                             "while" "with" "yield"))
                                   :name 'syntax-keyword-attribute)
                    (make-tm-match (tokens :word-boundary
                                           '("False" "None" "True"))
                                   :name 'syntax-constant-attribute)
                    (make-tm-string-region "\"")
                    (make-tm-string-region "'")
                    (make-tm-string-region "\"\"\"")
                    (make-tm-string-region "'''")
                    (make-tm-match integer-literals
                                   :name 'syntax-constant-attribute)
                    (make-tm-match floating-point-literals
                                   :name 'syntax-constant-attribute)
                    #+nil
                    (make-tm-match (tokens nil '("+" "-" "*" "**" "/" "//" "%" "@"
                                                 "<<" ">>" "&" "|" "^" "~"
                                                 "<" ">" "<=" ">=" "==" "!="))
                                   :name 'syntax-keyword-attribute))))
    (make-tmlanguage :patterns patterns)))

(defvar *python-syntax-table*
  (let ((table (make-syntax-table
                :space-chars '(#\space #\tab #\newline)
                :paren-alist '((#\( . #\))
                               (#\{ . #\})
                               (#\[ . #\]))
                :string-quote-chars '(#\" #\')
                :block-string-pairs '(("\"\"\"" . "\"\"\"")
                                      ("'''" . "'''"))
                :line-comment-string "#"))
        (tmlanguage (make-tmlanguage-python)))
    (set-syntax-parser table tmlanguage)
    table))

(define-major-mode python-mode language-mode
    (:name "python"
     :keymap *python-mode-keymap*
     :syntax-table *python-syntax-table*)
  (setf (variable-value 'enable-syntax-highlight) t
        (variable-value 'indent-tabs-mode) nil
        (variable-value 'tab-width) 4
        (variable-value 'calc-indent-function) 'python-calc-indent
        (variable-value 'line-comment) "#"
        (variable-value 'beginning-of-defun-function) 'beginning-of-defun
        (variable-value 'end-of-defun-function) 'end-of-defun)
  (run-hooks *python-mode-hook*))

#| link : https://www.python.org/dev/peps/pep-0008/ |#
(defun python-calc-indent (point)
  (with-point ((point point))
    (let ((tab-width (variable-value 'tab-width :default point))
          (column (point-column point)))
      (+ column (- tab-width (rem column tab-width))))))

(defun beginning-of-defun (point n)
  (loop :repeat n :do (search-backward-regexp point "^\\w")))

(defun end-of-defun (point n)
  (with-point ((p point))
    (loop :repeat n
          :do (line-offset p 1)
              (unless (search-forward-regexp p "^\\w") (return)))
    (line-start p)
    (move-point point p)))

(pushnew (cons "\\.py$" 'python-mode) *auto-mode-alist* :test #'equal)
(pushnew (cons "wscript" 'python-mode) *auto-mode-alist* :test #'equal)
