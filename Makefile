ZSHRCS=../grml-etc-core/etc/zsh/zshrc ../grml-etc-core/etc/skel/.zshrc

all: grml-zsh-refcard.tex

grml-zsh-refcard.tex: grml-zsh-refcard.tex.in genrefcard.pl $(ZSHRCS)
	cat $(ZSHRCS) | ./genrefcard.pl > grml-zsh-refcard.tex

clean:
	rm -f grml-zsh-refcard.tex *~
	rm -f *.aux *.log *.out *.pdf pdf-stamp

test: grml-zsh-refcard.tex
	make -f ../grml-zsh-refcard/Makefile
