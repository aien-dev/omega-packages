;;; omega.scm -- omc, the Omega compiler, born from the 408-byte seed of aien-dev/omega-mv.
;;; Copyright 2026 Drake Stapleton
;;; SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
;;;
;;; Guix builds its own world from a small audited seed; this package does the same for omc.
;;; The build runs omega-mv's seed/omega-from-seed.sh (seed0 -> hex1 -> asm2 -> om4 -> omc ->
;;; omc -> omc) with only sh, printf, sed, stat, cmp and sha256sum, then refuses any omc whose
;;; sha256 is not the pinned one. No C compiler, assembler or linker writes a byte of omc.

(define-module (aien omega)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:))

(define %omega-mv-commit "e5b32567a7aff3ce594e3254a622a846a6cd190b")
(define %omc-sha256 "2c82480596bbdc50cda9626866209ef662d5834f278f839ff4ce0250c495029f")

(define-public omc
  (package
    (name "omc")
    (version (git-version "0.0.0" "0" %omega-mv-commit))
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/aien-dev/omega-mv/archive/"
                           %omega-mv-commit ".tar.gz"))
       (file-name (string-append "omega-mv-" %omega-mv-commit ".tar.gz"))
       (sha256
        (base32 "0p59ahifnlb46pm93pb5sdh68h4m2jcxiaaklahng3bjzv7bc8f6"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:strip-binaries? #f
      #:validate-runpath? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'patch-source-shebangs)
          (replace 'build
            (lambda _
              (invoke "sh" "seed/omega-from-seed.sh")
              (invoke "sh" "-c"
                      (string-append "echo '" #$%omc-sha256
                                     "  seed/out/omc' | sha256sum -c -"))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (call-with-output-file "hello.om"
                  (lambda (port)
                    (display "global out uchar 4
fn main to int
put out 0 111
put out 1 107
put out 2 10
w = write 1 out 0 3
ret 0
end
" port)))
                (invoke "sh" "-c" "./seed/out/omc < hello.om > hello && chmod +x hello")
                (invoke "sh" "-c" "test \"$(./hello)\" = ok"))))
          (replace 'install
            (lambda _
              (install-file "seed/out/omc" (string-append #$output "/bin")))))))
    (supported-systems '("aarch64-linux"))
    (home-page "https://github.com/aien-dev/omega-mv")
    (synopsis "Omega compiler, born from a 408-byte hand-written seed")
    (description
     "omc compiles Omega (@file{.om}) source read on standard input into a
static AArch64 Linux ELF written to standard output.  This package builds it
from the 408-byte hand-written seed0 of omega-mv through hex1, asm2 and om4,
then has omc rebuild itself to a fixpoint, and checks the result against a
pinned sha256.  It runs and emits code for AArch64 Linux only.")
    (license license:asl2.0)))
