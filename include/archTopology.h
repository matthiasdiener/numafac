/*======================================================================================
  archTopology is an library to get multi-core architecture informations

  (C) Copyright 2010 INRIA 
  Projet: MESCAL / ANR NUMASIS

  Author: Christiane Pousa Ribeiro

  The author may be reached at pousa@imag.fr
 *====================================================================================*/

#ifndef __ARCHTOPOLOGY_H
#define __ARCHTOPOLOGY_H

#ifdef __cplusplus
extern "C" {
#endif

int *HashCpuNode;

void na_init();

int is_numa();
int get_maxnodes();
int get_maxcpus();
int get_cpusnode();
unsigned long get_totalcache();
unsigned long get_tcache();
unsigned long  get_totalmem_node();
int get_sockets();
int get_sockets_node();
float get_freq();
int get_cpussockets();


int na_get_core(int id);

void load_hash();

/*is it a numa machine*/
int na_is_numa();

/*get frequence of a core*/
float na_get_freq();

/*get number of nodes of the machine*/
int na_get_maxnodes();

/*get number of cpus/cores of the machine*/
int na_get_maxcpus();

/*get number of cpus/cores per node*/
int na_get_cpusnode();

/*get cpus/cores id of a node*/
int* na_get_cpusidnode(int nodeid);

/*get node id of a cpu/core*/
int na_get_nodeidcpu(int cpu);

/*get the amount of memory per node*/
unsigned long na_get_totalmem_node();

/*get the amount of free memory per node*/
int na_get_memnode(int nodeid);

/*get the amount of memory of the machine*/
int na_get_freemem();

/*get the amount of free memory of the machine*/
unsigned long na_get_totalmem();

/*get the amount of cache memory per node*/
unsigned long na_get_totalcache();

/*get the number of sockets*/
int na_get_sockets();

/*get the number of sockets*/
int na_get_sockets_node();

/*get sockets id of a node*/
int* na_get_socketsId_node(int node);

/*get cpu/core socket number*/
int na_get_socket_cpu(int cpuid);

/*max number of cores per socket*/
int na_get_cpussockets(); 

/*get cores iDs of a socket*/
int* na_get_cpusidsocket(int socket);

float na_bandwidth(int node1, int node2);
float na_numafactor(int node1, int node2);
float na_latency(int node1, int node2);

int na_fill_NUMA_latency_matrix (double **matrix);
int na_fill_multicore_latency_matrix (double **matrix);

void na_list_allnodes();
void na_list_allcpus();
void na_list_allcaches();

int na_get_maxneighbors();

/*Get number of memory cache levels*/
int na_get_numcaches();

/*Get first level of cache shared by cores*/
int na_get_shared_cacheLevel();

/*Get number of cores that share a cache level*/
int na_get_cache_cores();

/*Get cores that share a cache level with core*/
int* na_get_cacheShare_cores(int core);

/*NUMA - get the amount of first level cache memory per node*/
unsigned long na_get_tcache();

/* Get node neighbors */
int* na_get_nneighbors(int core);



#ifdef __cplusplus
}
#endif

#endif

