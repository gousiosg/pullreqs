# In your main Makefile, you can include a line like
# report:
#	$(MAKE) -f Makefile.report REPORT=TUD-SERG-2006-009

REPORT=TUD-SERG-2014-005

# the perl and pdfopt lines in the following target are needed to remove
# traces of pdflatex which would otherwise prompt arXiv to upload the 
# tex files instead of the pdf files

report:
	pdflatex $(REPORT).tex
	pdflatex $(REPORT).tex
	perl -p -e 's|^\/PTEX.*$$||g' < $(REPORT).pdf > /tmp/$(REPORT).pdf
	#pdfopt /tmp/$(REPORT).pdf $(REPORT).pdf >& /dev/null
	-rm -f /tmp/$(REPORT).pdf 


clean:
	-rm $(REPORT).aux $(REPORT).log $(REPORT).out $(REPORT).pdf
	-rm *~

VERSION=0.4
NAME=se-report-$(VERSION)
STYLE_FILES=Makefile.report se-report.sty TUD-SERG-2006-009.tex submitted_for_review.pdf serg-logo.pdf serg-logo.ps tudelft_logo_bw.pdf tudelft_logo_bw.ps ChangeLog

zip-style:
	mkdir -p $(NAME)
	cp $(STYLE_FILES) $(NAME)
	zip -r $(NAME).zip $(NAME)

zip-clean:
	rm -rf $(NAME) $(NAME).zip
