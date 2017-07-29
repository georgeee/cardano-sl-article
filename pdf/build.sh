#!/usr/bin/env bash

pandoc --latex-engine=xelatex       \
       --template=template.tex      \
       -V fontsize=10pt             \
       -V classoption=oneside       \
       -V geometry="margin=1.2in"   \
       -V geometry="headsep=0.5in"  \
       -V geometry="paper=a4paper"  \
       -o article.pdf               \
       ../article.md
