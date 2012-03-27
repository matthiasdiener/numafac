CC=gcc
FLAGS=-fopenmp -O2
LFLAGS=-fopenmp
all: stream_c.exe


stream_c.exe: stream.c mysecond.o
	$(CC) $(FLAGS) -c mysecond.c
	$(CC) $(LFLAGS) stream.c -o stream_c.exe

clean:
	rm -f stream_c.exe *.o *~
