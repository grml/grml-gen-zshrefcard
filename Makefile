ZSHRCS=../grml-etc-core/etc/zsh/zshrc

all: grml-zsh-refcard.tex

grml-zsh-refcard.tex: grml-zsh-refcard.tex.in genrefcard.pl $(ZSHRCS)
	cat $(ZSHRCS) | ./genrefcard.pl > grml-zsh-refcard.tex

clean:
	rm -f grml-zsh-refcard.tex *~
	rm -f *.aux *.log *.out *.pdf pdf-stamp

test: grml-zsh-refcard.tex
	make -f ../grml-gen-zshrefcard/Makefile
	pdflatex grml-zsh-refcard.tex
	pdflatex grml-zsh-refcard.tex
