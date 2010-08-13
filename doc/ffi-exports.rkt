#lang racket/base

(define (scheme->prim-js v) v)
(define (procedure->cps-js-fun proc) proc)
(define (procedure->void-js-fun proc) proc)
(define (prim-js->scheme v) v)

(define (js-value? x) #f)
(define (js-object? x) #f)
(define (js-function? x) #f)
(define (js-=== v1 v2) #f)
(define (js-typeof v) "object")
(define (js-instanceof v type) #f)

(define (js-get-global-value name) name)
(define (js-get-field obj selector1 . selectors) (hash-ref obj selector1))
(define js-set-field! hash-set!)
(define (js-new fun . args) fun)
(define js-make-hash
  (case-lambda
    [() (make-hash)]
    [(bindings) (make-hash (map (lambda (b) (cons (car b) (cadr b))) bindings))]))

(define (js-call f this-arg . args) (void))

(provide (all-defined-out))