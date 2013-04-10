# prowlcaml

Currently, a command-line tool for sending notifications through the prowl API
(http://prowlapp.com). 

Requires Jane Street's `Core` and `Async` (http://janestreet.github.io) and the
`ocaml-cohttp` package (https://github.com/avsm/ocaml-cohttp), all available
through `opam`.

When I have the time, this will become a command-line tool and library (and
will be packaged for `opam`), but right now it's just the former.

To build:
  opam install core async cohttp
  git clone git://github.com/pygatea/prowlcaml.git
  cd prowlcaml
  ocamlbuild -use-ocamlfind prowl.native
