##################################PATHMINAS
PATHMINAS="/home/pousa/Softs"

##################################COMPILER
CC=gcc
FF=gfortran
######################FLAGS COMPILATION AND LINK
CFLAGS= -c -g -w  -O3

##################################ARCHITECTURE
ARCH=-DX86_64_ARCH

###############################LIBRARIES
LIBNUMA=-lnuma
LIBTHREAD=-lpthread
LIBNCURSES=-lncurses
LIBMATH=-lm

SRC=src/
INC=-Iinclude
LIB=lib/

all: clean libarchtopo.a install

libarchtopo.a: archTopology.o
	$(AR) cr libarchtopo.a $(SRC)archTopology.o

archTopology.o: $(SRC)archTopology.c
	$(CC) -w -c -o $(SRC)$@ $(SRC)$(@F:.o=.c) $(INC)

install:
	mv libarchtopo.a $(LIB)

move2charm: libarchtopo.a
	cp lib/libarchtopo.a ../../../charm/lib
	cp lib/libarchtopo.a ../../../charm/multicore-linux64/tmp/libs

clean:
	rm -f src/archTopology.o src/*~  lib/libarchtopo.a
