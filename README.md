The CertiCoq project
====================

AUTHORS
-------

At its initial prerelease, this software is copyright (c) 2018 by
Abhishek Anand, Andrew Appel, Greg Morrisett, Zoe Paraskevopoulou, Randy
Pollack, Olivier Savary Belanger, and Matthieu Sozeau.

LICENSE
-------

The authors intend to open-source license this software during the first
quarter of 2018.  Until that time: Throughout 2018, you are free to
download, examine, install, and use this software for academic or
research purposes.


INSTALLATION INSTRUCTIONS
=========================

Installing dependencies:
------------------------

  To install the compiler, you need Coq.8.7.1 along with the Template-Coq
and ExtLib packages.  One way to get everything is using opam:

  To add the official Coq repositories, you need:

# opam repo add coq-released https://coq.inria.fr/opam/released
# opam repo add coq-core-dev https://coq.inria.fr/opam/core-dev
# opam repo add coq-extra-dev https://coq.inria.fr/opam/extra-dev

  Then to install coq and certicoq's dependencies:

# opam install coq.8.7.1
# opam pin add coq 8.7.1
# opam install coq-template-coq coq-ext-lib coq-squiggle-eq

The package currently builds with the `coq-template-coq.8.7.dev` package, `coq-ext-lib.0.9.7` and
`coq-squiggle-eq.1.0.3`.

If you have already installed some package manually, you can choose the --fake keyword for opam to assume that it is installed, e.g.:
# opam install --fake coq


Alternatively, you can install Coq from source or download a binary from:

https://coq.inria.fr/coq-87

and install the packages from source:

https://github.com/coq-ext-lib/coq-ext-lib
https://github.com/gmalecha/template-coq (branch : coq-8.7)
https://github.com/aa755/SquiggleEq


Updating dependencies:
------------------------

When the above repositories are updated, you may need to update your installation.
If you chose opam, you can do
# opam update
# opam upgrade coq-template-coq coq-ext-lib coq-squiggle-eq 


Building the compiler:
----------------------
  at `certicoq/`, run

# make -j4 -k

  This will build the compiler and its proofs.

To build the OCaml version of the compiler and the
`CertiCoq Compile` plugin, in `theories/`

# sh make_plugin.sh

Troubleshooting:
----------------------

If the above fails, try the following

0) update the dependencies, as explained above

1) "make clean" at certicoq/ and then try to build again. Try "make cleanCoqc" as well.

2) Ensure that your working copy is EXACTLY the same as the contents of SVN repo. Unversioned files and directories should also be removed because they can 
interfere with how Coq resolves imports and how Makefile tracks dependences (via coqdep).

If you are using a git client to access the SVN repo, "git reset HEAD --hard; git clean -xf" ensures that the working copy exactly matches the state of the repository.

If you use the SVN client, there should be something similar:
http://stackoverflow.com/questions/239340/automatically-remove-subversion-unversioned-files
http://stackoverflow.com/questions/6204572/is-there-a-subversion-command-to-reset-the-working-copy

3) Is your file system case-insensitive? Please consider using a linux VM. Or,  try making all Require Imports/Exports fully qualified,
so that Coq doesn't import the wrong file because its name differes only in capitalization.
There is tool to help with that:
https://github.com/JasonGross/coq-tools/


If errors remain AFTER step 2, please send an email to the certicoq mailing list.
Until step 2, others cannot be sure about the state of the working copy of your machine, so their help may not be applicable.
