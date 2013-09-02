FILE=github
all: pdf

pdf:
	pdflatex $(FILE).tex 
	bibtex $(FILE)
	pdflatex $(FILE).tex
	pdflatex $(FILE).tex

clean:
	-rm -f *.aux
	-rm -f *.bbl *.blg *.log *.out *.dvi *~ *.spl
	-rm -f $(FILE).pdf 

wc: 
	detex $(FILE).tex|wc
