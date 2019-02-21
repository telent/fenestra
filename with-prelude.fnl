((require "fun"))
((require "prelude"))

(local fennelview (require "fennelview"))
(global pp (lambda [x] (print (fennelview x))))

((. (require "fennel") :dofile) (. arg 1))
