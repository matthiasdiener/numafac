CC=gcc
FLAGS=-fopenmp -O2 -g
LFLAGS=-fopenmp
LIB=-I../include 
LLIB=-L../lib -larchtopo
all: topo


topo: topo.c
	$(CC) $(LFLAGS) topo.c -o topo $(LIB) $(LLIB)

clean:
	rm -f topo *.o *~
