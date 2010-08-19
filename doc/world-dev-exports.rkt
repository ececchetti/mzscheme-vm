#lang racket

(define (make-world-config startup
                           shutdown
                           (pause #f)
                           (restart #f))
  #f)
(define (world-config? x) #f)

(define-struct bb-info (toplevel-node
                        change-world
                        call-with-pausing
                        unsafe-change-world))

(define (make-effect-type name super-type field-cnt implementation guard)
  (make-struct-type name super-type field-cnt 0 #f '() (current-inspector) #f '() guard))
(define (effect-type? x) #f)
(define (effect? x) #f)
(define (compound-effect? x)
  (or (effect? x)
      (and (list? x)
           (andmap compound-effect? x))))
(define (world-with-effects e w) w)

(define (make-render-effect-type name super-type field-cnt implementation guard)
  (make-struct-type name super-type field-cnt 0 #f '() (current-inspector) #f '() guard))
(define (render-effect-type? x) #f)
(define (render-effect? x) #f)

(provide (all-defined-out))
#;(provide/contract [make-world-config (procedure?
                                      procedure?
                                      (or/c procedure? false?)
                                      (or/c procedure? false?)
                                      . -> .
                                      any)]
                  [world-config? (any/c . -> . boolean?)]
                  [world-with-effects (any/c any/c . -> . any/c)]
                  [struct bb-info ((toplevel-node any/c)
                                   (change-world (procedure? . -> . void?))
                                   (call-with-pausing (-> any))
                                   (unsafe-change-world ((-> any/c any/c)
                                                         . -> . void?)))])