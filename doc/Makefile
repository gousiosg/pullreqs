all: techreport

icse/pullreqs.pdf:
	cd icse && make

techreport: icse/pullreqs.pdf 
	cd techreport && make

clean:
	-cd icse && make clean
	-cd techreport && make clean

