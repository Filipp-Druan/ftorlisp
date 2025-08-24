#lang racket

(define (syntax-check code)
  (define symbols (make-hash))

  (define (generate-table)

  (map code 
