#lang racket

(require (for-syntax syntax/parse))

(provide apat
         standardize/shallow)

(define-syntax (apat stx)
  (define-syntax-class attribute-pattern
    #:description "attribute pattern"
    (pattern (attrname:id ... . other-attrs:id)))
  
  (syntax-parse stx
    [(_ (tag:id () . elementsid:id) 
        body:expr)
     #'(cons (quote tag) 
             (standardize/shallow
              (lambda (tagid attrs . elementsid)
                (match attrs
                  [(list'@) body]
                  [other (error 'apat "expected no attributes, got ~a" other)]))))]
    [(_ (tag:id attpat:attribute-pattern . elementsid:id) 
        body:expr)
     #'(cons (quote tag) 
             (standardize/shallow
              (lambda (tagid attrs . elementsid)
                (match attrs
                  [(cons '@
                         (list-no-order (list (quote attpat.attrname) attpat.attrname) ... 
                                        attpat.other-attrs (... ...)))
                   body]
                  [other (error 'apat "missing required attribute from ~a" 
                                (quote (attpat.attrname ...)))]))))]))

;; take a function *requiring* sxml attributes
;; and make it work for sxml without attributes
(define (standardize/shallow fun)
  (lambda (tag . others)
    (match others
      [`((@ ,attrs ...) ,elements ...)
       (apply fun tag (cons '@ attrs) elements)]
      [elements
       (apply fun tag (cons '@ '()) elements)])))

(module+ test
  (require rackunit)
  (check-equal? (apply
                 (standardize/shallow (lambda (a b . rest)
                                        (list a b rest)))
                 `(tag (@ (attr1 "zip") (attr2 "zap")) "a" "b"))
                (list 'tag
                      '(@ (attr1 "zip") (attr2 "zap"))
                      '("a" "b")))
  (check-equal? (apply
                 (standardize/shallow (lambda (a b . rest)
                                        (list a b rest)))
                 `(tag  "a" "b"))
                (list 'tag
                      '(@ )
                      '("a" "b")))

;; regular match:
(check-equal?
 (apply 
  (cdr 
   [apat
    (w1:segment (width height .  others) . content)
    13])
  `(w1:segment (@ (width "32") (height "49")) "a" "b"))
 13)
;; missing required attribute:
(check-exn
 (lambda (exn)
   (regexp-match #px"missing required attribute" (exn-message exn)))
 (lambda ()
   (apply 
    (cdr 
     [apat
      (w1:segment (width height .  others) . content)
      13])
    `(w1:segment (@ (width "32")) "a" "b"))))
;; extras should be okay:
(check-equal?
 (apply 
  (cdr 
   [apat
    (w1:segment (width height .  others) . content)
    others])
  `(w1:segment (@ (height "49") (boogle "rap") (width "32")) "a" "b"))
 `((boogle "rap")))
;; we can actually access the attributes:
(check-equal?
 (apply 
  (cdr 
   [apat
    (w1:segment (width height .  others) . content)
    (list (+ (string->number width) (string->number height)) content)])
  `(w1:segment (@ (height "49") (boogle "rap") (width "32")) "a" "b"))
 (list 81 (list "a" "b")))
;; one set of attrs
(check-equal?
 (apply 
  (cdr 
   [apat
    (w1:segment attrs . content)
    (list attrs content)])
  `(w1:segment (@ (height "49") (boogle "rap") (width "32")) "a" "b"))
 (list '((height "49") (boogle "rap") (width "32")) (list "a" "b")))


;; force no attrs
(check-equal? 
 (apply 
  (cdr 
   [apat
    (w1:id () . content)
    13])
  `(w1:id "abc" "def"))
 13)
(check-exn
 (lambda (exn)
   (regexp-match #px"expected no attributes" (exn-message exn)))
 (lambda ()
   (apply 
    (cdr 
     [apat
      (w1:id () . content)
      13])
    `(w1:id (@ (foo "13")) "abc" "def"))))

  
  
  
  )