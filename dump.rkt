#!/usr/bin/env racket
#lang racket

(require "common.rkt"
         "compiler/compile.rkt"
         "compiler/assemble.rkt"
         "compiler/bootstream.rkt")

(define bootstream? (make-parameter #f))
(define symbols? (make-parameter #f))

(define input-file
  (command-line
   #:once-each
   [("-b" "--bootstream") "print bootstream"
    (bootstream? #t)]
   [("-s" "--symbols") "include symboltable"
    (symbols? #t)]
   #:args (filename)
   filename))

(define (comma-join things)
  (when (vector? things)
    (set! things (vector->list things)))
  (string-join (for/list ((thing things))
                 (cond ((string? thing)
                        thing)
                       ((number? thing)
                        (number->string thing))
                                        ;(else (raise "invalid thing"))
                       (else (format "~a" thing))
                       ))
               ","))

(define (compiled->json compiled)
  (comma-join
   (for/list ((node compiled))
     (format "'~a' : [~a]"
             (node-coord node)
             (comma-join (let ((mem (node-mem node)))
                           (for/list ((i (range (node-len node))))
                             (let ((word (vector-ref mem i)))
                               (if (vector? word)
                                   (format "[~a]"
                                           (comma-join (for/list ((w word))
                                                         (format "'~a'" w))))
                                   word)))))))))

(define (boot-descriptors->json compiled)
  (comma-join
   (for/list ((node compiled))
     (format " '~a' : {~a}"
             (node-coord node)
             (comma-join (list (format "'a' : ~a" (node-a node))
                               (format "'b' : ~a" (node-b node))
                               (format "'io' : ~a" (node-io node))
                               (format "'p' : ~a" (node-p node))
                               (format "\n'stack' : ~a \n"
                                       (if (node-stack node)
                                           (format "[~a]"
                                                   (comma-join (node-stack node)))
                                           #f))))))))

(define (assembled->json assembled)
  (comma-join (for/list ((node assembled))
                (format "'~a' : [~a]"
                        (node-coord node)
                        (comma-join (let ((mem (node-mem node)))
                                      (for/list ((i (range (node-len node))))
                                        (vector-ref mem i))))))))

(define compiled (compile (file->string input-file)))
(define compiled-json (compiled->json compiled))
(define boot-descriptors-json (boot-descriptors->json compiled))
(define assembled (assemble compiled))
(define assembled-json (assembled->json assembled))
(define bootstream (make-bootstream assembled))

(printf "{~a}\n"
        (comma-join
         (list (format "'file' : '~a'\n" input-file)
               (format "'compiled': {~a}\n" compiled-json)
               (format "'boot-descriptors' : {~a}\n" boot-descriptors-json)
               (format "'assembled': {~a}\n" assembled-json)
               (format "'bootstream' : [~a] " (comma-join bootstream))
               )))