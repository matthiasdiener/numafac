all: compute-latencies

compute-latencies: compute-latencies.c
	gcc -g -O0 compute-latencies.c -o compute-latencies -lhwloc lmbench.a ../lib/libarchtopo.a -I/home/pilla/numalb/src/hwloc/include -L/home/pilla/numalb/src/hwloc/lib

clean:
	rm -rf *.o *~ compute-latencies
