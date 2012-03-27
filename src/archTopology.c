/*======================================================================================
  archTopology is an library to get multi-core architecture informations

  (C) Copyright 2010 INRIA 
  Projet: MESCAL / ANR NUMASIS

  Author: Christiane Pousa Ribeiro

  The author may be reached at pousa@imag.fr
 *====================================================================================*/
#include <sys/mman.h>
#include <sys/syscall.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <stddef.h>
#include <string.h>
#include <dirent.h>
#include <ctype.h>
#include <limits.h>

#define __USE_GNU
#include<sched.h>

#include "archTopology.h"
#include "archTopo.h"

/*Initialize the hash table of cores and nodes*/
void na_init()
{
	  load_hash();	 
}


int na_set_core(pid_t id,int core)
{
  cpu_set_t mask;
  int i = 0;
  unsigned int len;
  int num_cpus = MAXCPUS;

  CPU_ZERO(&mask);
  CPU_SET(core,&mask);
  len = sizeof(mask);
  	if(sched_setaffinity(id,len,&mask) == -1){
		printf("Error getting affinity\n");
		return -1;
	}
	else
	{
		return 0;
	}
}	



int na_get_core(pid_t id)
{
  cpu_set_t mask;
  int i = 0;
  unsigned int len;
  int num_cpus = MAXCPUS;

  CPU_ZERO(&mask);
  len = sizeof(mask);
  	if(sched_getaffinity(id,len,&mask) == -1){
		printf("Error getting affinity\n");
		return -1;
	}
	else
	{
		for(i=0;i<num_cpus;i++){
			if(CPU_ISSET(i,&mask))
				return i;
		}
	}
}	

int is_numa()
{
	if (na_get_maxnodes()>1) 
          return 1;
        else
	  return 0; 
}


/*Is a NUMA machine? 1 == true, 0 ==false*/
int na_is_numa()
{
	  load_hash();
	  return ISNUMA; 
}

/*get number of nodes of the machine*/
int get_maxnodes()
{ 
  FILE *fp_nodes;
  int max_node=1;
  char command[]="ls -1d /sys/devices/system/node/node*|wc|awk '{print $1}'";

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&max_node);   
  fclose(fp_nodes);

  return max_node;
}

/*get number of nodes of the machine*/
int na_get_maxnodes()
{
  return MAXNODES;
}

/*get number of cpus/cores of the machine*/
int get_maxcpus()
{
  FILE *fp_nodes;
  int max_cpu=-1;
  char command[]="ls -d /sys/devices/system/cpu/cpu[0-9]* | wc -l";

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&max_cpu);
  fclose(fp_nodes);

  return max_cpu; 
}

/*get number of cpus/cores of the machine*/
int na_get_maxcpus()
{
  return MAXCPUS;
}

/*get number of cpus/cores per node*/
int get_cpusnode()
{
  int num_cpus=-1;
  FILE *fp_nodes;

  char command[]="ls -d /sys/devices/system/node/node0/cpu[0-9]* | wc -l";
  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&num_cpus);   
  fclose(fp_nodes);

  return num_cpus;
}

/*get number of cpus/cores per node*/
int na_get_cpusnode()
{
  return CPUSNODE;
}
/*get the total amount of memory of the machine
return: -1 error 
*/
unsigned long get_totalmem()
{
  int mem=-1;
 
  FILE *fp_nodes;

  char command[256];
  char temp[33];
  	 
  command[0]='\0'; 
  strcpy(command,"awk '/MemTotal/ {print $2}' /proc/meminfo");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&mem);   
  fclose(fp_nodes);

  return mem;
}

/*get the total amount of memory of the machine
return: -1 error 
*/
unsigned long na_get_totalmem()
{
  return TOTALMEM;
}

/*get the total free memory of the machine
return: -1 error 
*/
int na_get_freemem()
{
  int mem=-1;
 
  FILE *fp_nodes;

  char command[256];
  char temp[33];
  	 
  command[0]='\0'; 
  strcpy(command,"awk '/MemFree/ {print $2}' /proc/meminfo");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&mem);   
  fclose(fp_nodes);

  return mem;
}

/*get the total amount of memory per node
return: -1 error 
*/
unsigned long na_get_totalmem_node()
{
  unsigned long mem_node=0;
  int  nodeid=1;
 
  FILE *fp_nodes;

  char command[256];
  char temp[33];
  	 
  command[0]='\0'; 
  strcpy(command,"awk '/MemTotal/ {print $4}' /sys/devices/system/node/node0");
  strcat(command,"/meminfo");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&mem_node);   
  fclose(fp_nodes);

  return mem_node;
}



/*get the amount of last level cache memory per node
return: -1 error 
*/
unsigned long get_totalcache()
{
  unsigned long mem_node=0;
  int cl=0;
   char cachel[2],temp[33];
  FILE *fp_nodes;

  char command[512];
  command[0]=cachel[0]=temp[0]='\0';
  strcpy(command,"ls -d /sys/devices/system/cpu/cpu0/cache/index[0-9]* | wc -l");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%s",&cachel);   
  fclose(fp_nodes);

  cl=atoi(cachel);
  cl = cl -1;
  sprintf(temp, "%i", cl);

  command[0]='\0';
  strcpy(command,"cat /sys/devices/system/cpu/cpu0/cache/index");
  strcat(command,temp);
  strcat(command,"/size | tr -d 'K'");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&mem_node);   
  fclose(fp_nodes);

  return mem_node;
}

unsigned long na_get_totalcache()
{
  return LLC;
}

/*get the amount of first level cache memory per node
return: -1 error 
*/
unsigned long get_tcache()
{
  unsigned long mem_node=0;
  FILE *fp_nodes;
  char command[256];

  command[0]='\0';
  strcpy(command,"cat /sys/devices/system/cpu/cpu0/cache/index0");
  strcat(command,"/size | tr -d 'K'");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&mem_node);   
  fclose(fp_nodes);

  return mem_node;
}

unsigned long na_get_tcache()
{
  return L1CACHE;
}

/*get the amount of free memory per node
return: -1 error 
*/
int na_get_memnode(int nodeid)
{
  int mem_node=-1;
 
  FILE *fp_nodes;

  char command[256];
  char temp[33];
  	 
  command[0]='\0'; 
  sprintf(temp, "%i", nodeid);
  strcpy(command,"awk '/MemFree/ {print $4}' /sys/devices/system/node/node");
  strcat(command,temp);
  strcat(command,"/meminfo");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&mem_node);   
  fclose(fp_nodes);

  return mem_node;
}

/*get number of sockets per node
return: -1 error 
*/
int* na_get_socketsId_node(int node)
{
  int total_sock=na_get_sockets_node(),find,j;
  int *sockets_id,i,k,*cpus,max_cores,socket;

  sockets_id=malloc(total_sock*sizeof(int));
  for(i=0;i<total_sock;i++)sockets_id[i]=-1;
  max_cores = na_get_cpusnode();
  cpus = malloc(max_cores*sizeof(int));
  cpus = na_get_cpusidnode(node);
 
  k=0; 
  find=0;
  for(i=0;i<max_cores;i++)
  {
  	socket = na_get_socket_cpu(cpus[i]);
	find=j=0;
        while(!find && j<total_sock) if(socket == sockets_id[j]) find=1; else j++;
	if(!find){
	 sockets_id[k] = socket;
	 k++;}
  }

  return sockets_id;
}


/*get number of sockets per node
return: -1 error 
*/
int get_sockets()
{
  int total_sock=-1;

   FILE *fp_nodes;
  char command1[1024];
  int socket;

  command1[0]='\0';
  strcpy(command1,"PACKAGE_COUNT=1;\n");
  strcat(command1," CPU_POSSIBLE_COUNT=`ls -d /sys/devices/system/node/node0/cpu[0-9]* | wc -l` \n");
  strcat(command1," for ((i=0;i<${CPU_POSSIBLE_COUNT};++i)); \n do \n");
  strcat(command1,"p=`cat /sys/devices/system/node/node0/cpu${i}/topology/physical_package_id` \n");
  strcat(command1," PACKAGE[${p}]+=\"${i} \" \n");
  strcat(command1," if [ ${PACKAGE_COUNT} -lt $((${p}+1)) ]; then \n");
  strcat(command1," let PACKAGE_COUNT=$((${p}+1)) \n fi \n done\n");
  strcat(command1," echo ${PACKAGE_COUNT}");

  fp_nodes = popen(command1,"r");
  fscanf(fp_nodes,"%d",&total_sock);
  fclose(fp_nodes);

  return total_sock;
}

int na_get_sockets()
{
  return MAXSOCKETS;
}

/*get number of sockets
return: -1 error 
*/
int get_sockets_node()
{
  int total_sock=-1;

   FILE *fp_nodes;
  char command1[1024],temp[64];
  int socket,tcpus;
   
  tcpus = na_get_cpusnode();
  char *resp = malloc (((tcpus*4)+1)*sizeof(char));

  resp[0]=command1[0]='\0';
  strcpy(command1,"NODE_CPUIDS=\"\"\n");
  strcat(command1," for i in `ls -d /sys/devices/system/node/node0/cpu[0-9]*`; \n do \n");
  strcat(command1," NODE_CPUIDS=$NODE_CPUIDS\"`basename $i | sed s/cpu//` \"\n");
  strcat(command1," done\n");
  strcat(command1,"PACKAGE_COUNT=1;\n j=0;\n");
  strcat(command1,"for i in ${NODE_CPUIDS} \n do \n");
  strcat(command1,"let j=j+1 \n");
  strcat(command1,"p=`cat /sys/devices/system/cpu/cpu${i}/topology/physical_package_id` \n");
  strcat(command1," PACKAGE[${p}]+=\"${j} \" \n");
  strcat(command1," if [ ${PACKAGE_COUNT} -lt $((${p}+1)) ]; then \n");
  strcat(command1," let PACKAGE_COUNT=$((${p}+1)) \n fi \n done\n");
  strcat(command1," echo ${PACKAGE_COUNT}");

//  printf("%s\n",command1);
 
  fp_nodes = popen(command1,"r");
  fscanf(fp_nodes,"%d",&total_sock);
  fclose(fp_nodes);

  return total_sock;
}


int na_get_sockets_node()
{
  return SOCKETSNODE;
}

void load_hash()
{
  int i;
  HashCpuNode = malloc(na_get_maxcpus()*sizeof(int));
  for( i=0;i<na_get_maxcpus();i++){ 
    HashCpuNode[i] = get_nodeidcpu(i);}
}

/*get node id of a cpu/core
return: 0 if no node
*/
int na_get_nodeidcpu(int cpu)
{
  return HashCpuNode[cpu];
}

/*get node id of a cpu/core
return: 0 if UMA 
*/
int get_nodeidcpu(int cpu)
{
   	int i;
        int             node=-1;
        char            dirnamep[256];
        char            cpuid[7],temp[33];
        struct dirent   *dirent;
        DIR             *dir;
        int maxnodes;
        maxnodes  =  na_get_maxnodes();
      
      if( maxnodes > 1){  
	  temp[0]=cpuid[0]=dirnamep[0]='\0';
          strcpy(cpuid,"cpu");
          sprintf(temp, "%i", cpu);
          strcat(cpuid,temp);
          strcat(cpuid,"\0");


        for(i=0;i<maxnodes && node == -1;i++){
        strcpy(dirnamep,"/sys/devices/system/node/node");
        temp[0]='\0';
        sprintf(temp, "%i", i);
        strcat(dirnamep,temp);
        dir = opendir(dirnamep);
        if (dir == NULL) {
                return 0;
        }
        while ((dirent = readdir(dir)) != 0) {
                if (strcmp(cpuid, dirent->d_name)==0) {
                        node = i;
                        break;
                }
        }
        closedir(dir);
     }
    }
    else
      node = 0;

  return node;
}



/*get cpu/core socket number*/
int na_get_socket_cpu(int cpu)
{
  int socket=-1;
 
  FILE *fp_nodes;

  char command[256];
  char temp[33];
  	 
  command[0]='\0'; 
  sprintf(temp, "%i", cpu);
  strcpy(command,"cat /sys/devices/system/cpu/cpu");
  strcat(command,temp);
  strcat(command,"/topology/physical_package_id");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&socket);   
  fclose(fp_nodes);

  return socket;
}


/*
 *Get first level of shared cache by cores
 * */ 
int na_get_shared_cacheLevel()
{
  int nr_caches,i,shared,res;
  char command[512],temp[33];
  FILE *fp_cache;

  command[0] = '\0';
  shared = -1;
  nr_caches = na_get_numcaches();

  for(i=2;i<=nr_caches && shared == -1;i++){
	  command[0]='\0';
	  strcpy(command,"cat /sys/devices/system/cpu/cpu0/cache/index");
	  sprintf(temp,"%i",i);
  	  strcat(command,temp);
          strcat(command,"/shared_cpu_list | sed s/,/\'\\n\'/g | wc -l");
	  fp_cache = popen(command,"r");
 	  fscanf(fp_cache,"%d",&res);

	  if(res > 1)
		  shared = i;
  }

  return shared;  
}


int na_get_cache_cores()
{
   int nr_caches,i,res;
  char command[512],temp[33];
  FILE *fp_cache;

  command[0] = '\0';
  res = 1;
  nr_caches = na_get_numcaches();

  for(i=2;i<=nr_caches && res == 1;i++){
	  command[0]='\0';
	  strcpy(command,"cat /sys/devices/system/cpu/cpu0/cache/index");
	  sprintf(temp,"%i",i);
  	  strcat(command,temp);
          strcat(command,"/shared_cpu_list | sed s/,/\'\\n\'/g | wc -l");
	  fp_cache = popen(command,"r");
 	  fscanf(fp_cache,"%d",&res);
	  
  }

  return res;  
 
}	

/*get cpus/cores id of a node
return: -1 error 
*/
int* na_get_cpusidnode(int nodeid)
{
   int *cpusid,*tcpusid,aux,tcpus,i,err,shared,cache_cores,*taux,find,k,j;
   char temp[33],*resp,*cpu;

  FILE *fp_nodes;
  char command[] = "ls -d /sys/devices/system/node/node0/cpu[0-9]* | wc -l";
  shared = na_get_shared_cacheLevel();
  cache_cores = na_get_cache_cores();
  
  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&tcpus);
  fclose(fp_nodes);

  resp = malloc (((tcpus*4)+1)*sizeof(char));
  cpusid = malloc(tcpus*sizeof(int));
  tcpusid = malloc(tcpus*sizeof(int));
  taux = malloc(cache_cores*sizeof(int));

  char command1[456];

if(shared == -1 || shared == na_get_numcaches()){ //no cache shared or LLC is shared
  command1[0]='\0';
  strcpy(command1,"NODE_CPUIDS=\"\"\n");
  strcat(command1," for i in `ls -d /sys/devices/system/node/node");
  sprintf(temp, "%i", nodeid);
  strcat(command1,temp);
  strcat(command1,"/cpu[0-9]*`; \n do \n");
  strcat(command1," NODE_CPUIDS=$NODE_CPUIDS\"`basename $i | sed s/cpu//` \"\n");
  strcat(command1," done\n");
  strcat(command1," echo ${NODE_CPUIDS}\n");

  fp_nodes = popen(command1,"r");
  fgets(resp,((tcpus*4)+1)*sizeof(char),fp_nodes);
  fclose(fp_nodes);

  cpu = strtok (resp," \n");
  cpusid[0] = atoi(cpu);

  for(i=1;i<tcpus;i++)
  {
        cpu = strtok (NULL," \n");
        cpusid[i] = atoi(cpu);
  }

  for(i=1;i<tcpus;i++){
       aux = cpusid[i];
	  for(j=i-1;j>=0 && aux < cpusid[j];j--)
		   cpusid[j+1]=cpusid[j];
       cpusid[j+1]=aux;	   
  }

}
else
{
   int total_socket;
   total_socket = na_get_sockets_node();
   int *sockets_id;
   sockets_id = malloc(total_socket*sizeof(int));
   int max_cores_socket = na_get_cpussockets();
   int *cores_s;
   cores_s = malloc(max_cores_socket*sizeof(int));
   
   sockets_id = na_get_socketsId_node(nodeid);
   k = 0;
   for(i=0;i<total_socket;i++)
   {
     cores_s = na_get_cpusidsocket(sockets_id[i]);
     for(j=0;j<max_cores_socket;j++)
	{ cpusid[k]=cores_s[i]; k++;}	     
   }
}
 
return cpusid;

}

/*
 *Get cores id that share cache with core
 * */
int* na_get_cacheShare_cores(int core)
{
  int i,err,shared,cache_cores,*taux,find,k,j;
  char temp[33],*resp,*cpu,command1[512];

  FILE *fp_nodes;
  shared = na_get_shared_cacheLevel();
  cache_cores = na_get_cache_cores();

  resp = malloc (((cache_cores*4)+1)*sizeof(char));
  taux = malloc((cache_cores-1)*sizeof(int));
 
    k= 0;	  
    command1[0]='\0';
    strcpy(command1,"cat /sys/devices/system/cpu/cpu");
    sprintf(temp,"%i",core);
    strcat(command1,temp);
    strcat(command1,"/cache/index");
    sprintf(temp,"%i",shared);
    strcat(command1,temp);
    strcat(command1,"/shared_cpu_list");
    
    fp_nodes = popen(command1,"r");
    fgets(resp,((cache_cores*4)+1)*sizeof(char),fp_nodes);
    fclose(fp_nodes);

    cpu = strtok (resp,",\n");
    if(atoi(cpu) != core){
       taux[k] = atoi(cpu); k++;
     }

    for(i=k;i<cache_cores-1;i++){
       cpu = strtok (NULL,",\n");
       if(atoi(cpu) != core)
       	 taux[i] = atoi(cpu); 
       }

   return taux;
}

/*
Get Latency between two nodes
parameters:node1-first node, node2-second node
return: numa factor
*/
float na_latency(int node1, int node2)
{
  FILE *fp;
  int maxnodes,i=0,possible;
  char *str;
  float latency=1.0;
 
  maxnodes = na_get_maxnodes();

  fp = fopen("/tmp/output/latency_lmbench.minas","r");

  /*read latency*/
 if ( fp != NULL)
  {
    do{
      fscanf (fp,"%f",&latency);
      i++; 
    }while(i < (((node1-1)*maxnodes)+ node2));
   }
   else
   {
    printf("\n Latency - You may install ArchTopology.");
    exit(1);
   }
 
   fclose(fp);
 
  return latency;
}

enum arch_mode { NUMA, MULTICORE };

static int 
na_fill_latency_matrix (double **matrix, enum arch_mode mode)
{
  FILE *nodes_fp, *cores_fp;
  int maxnodes,maxcpus,i,j,possible;
  char *str;
  float latency=1.0;
 
  maxnodes = na_get_maxnodes();
  maxcpus = na_get_maxcpus();

  nodes_fp = fopen("/tmp/output/latency_lmbench.minas","r");
  cores_fp = fopen("/tmp/output/latency_lmbench_multicore.minas","r");

  if (!nodes_fp || !cores_fp)
    {
      printf ("\n Latency - You may install ArchTopology.\n");
      exit (1);
    }

  if (mode == NUMA)
    {
      for (i = 0; i < maxnodes; i++)
	for (j = 0; j < maxnodes; j++)
	  fscanf (nodes_fp, "%lf", &matrix[i][j]);
    }
  else if (mode == MULTICORE)
    {
      for (i = 0; i < maxcpus; i++)
	for (j = 0; j < maxcpus; j++)
	  fscanf (cores_fp, "%lf", &matrix[i][j]);
    }
 
  fclose (nodes_fp);
  fclose (cores_fp);

  return 0;
}

int na_fill_NUMA_latency_matrix (double **matrix)
{
  return na_fill_latency_matrix (matrix, NUMA);
}

int na_fill_multicore_latency_matrix (double **matrix)
{
  return na_fill_latency_matrix (matrix, MULTICORE);
}

/*
Get Numa factor between two nodes
parameters:node1-first node, node2-second node
return: numa factor
*/
float na_numafactor(int node1, int node2)
{
  FILE *fp;
  int maxnodes,i=0,possible;
  char *str;
  float numafactor=1.0;
 
  maxnodes = na_get_maxnodes();

  fp = fopen("/tmp/output/numafactor_lmbench.minas","r");

  /*read numa factor*/
 if ( fp != NULL)
  {
    do{
      fscanf (fp,"%f",&numafactor);
      i++; 
    }while(i < (((node1-1)*maxnodes)+ node2));
   }
   else
   {
    printf("\n Numa Factor - You may install ArchTopology.");
    exit(1);
   }
 
   fclose(fp);
 
  return numafactor;
}

/*
Get bandwidth between two nodes
parameters:node1-first node, node2-second node
return: bandwidth
*/
float na_bandwidth(int node1, int node2)
{
  FILE *fp;
  int maxnodes,i=0;
  char *str;
  float bandwidth=0.0; 

  maxnodes = na_get_maxnodes();

  fp = fopen("/tmp/output/bandwidth.minas","r");

  if ( fp != NULL)
  {
    do{
      fscanf (fp,"%f",&(bandwidth));
      i++; 
    }while(i < (((node1-1)*maxnodes)+ node2));
   }
   else
   {
    printf("\n Bandwidth -You may install ArchTopology.");
    exit(1);
   }
 
   fclose(fp);
 
  return bandwidth;
}

/*list all nodes id of the machine*/
void na_list_allnodes()
{
	int i;
        int             node=-1;
        char            dirnamep[256];
        char            temp[33];
        struct dirent   *dirent;
        DIR             *dir;
        int maxnodes;
        maxnodes  =  na_get_maxnodes();

        temp[0]=dirnamep[0]='\0';
        
        for(i=0;i<maxnodes;i++){
        strcpy(dirnamep,"/sys/devices/system/node/node");
        temp[0]='\0';
        sprintf(temp, "%i", i);
        strcat(dirnamep,temp);
        
        dir = opendir(dirnamep);
        if (dir != NULL) 
                printf("dir %s\n",dirnamep);
        
        closedir(dir);
     }
}

/*list all cpus id of the machine*/
void na_list_allcpus()
{
   	int i;
        int             node=-1;
        char            dirnamep[256], dirnamec[256];
        char            cpuid[7],temp[33];
        struct dirent   *dirent;
        DIR             *dir;
        int maxnodes;
        maxnodes  =  na_get_maxnodes();

        temp[0]=dirnamep[0]='\0';

        for(i=0;i<maxnodes;i++){
 	strcpy(dirnamep,"/sys/devices/system/node/node");
        strcpy(dirnamec,"/sys/devices/system/node/node");
        temp[0]='\0';
        sprintf(temp, "%i", i);
        strcat(dirnamep,temp);
        strcat(dirnamec,temp);
        dir = opendir(dirnamep);

        if (dir == NULL) {
                return -1;
        }
        while ((dirent = readdir(dir)) != 0) {
                if (!strncmp("cpu", dirent->d_name, 3)) {
                    strcat(dirnamec,dirent->d_name);  
		    printf("dir %s\n",dirnamec);
                }
        }
        closedir(dir);
     }
}

/*list all caches levels and their size*/
void na_list_allcaches()
{
   	int i;
        int             node=-1;
        char            dirnamep[256], dirnamec[256];
        struct dirent   *dirent;
        DIR             *dir;
        int maxcache,maxnodes;
        maxcache  =  na_get_numcaches();
	maxnodes = na_get_maxnodes();

        dirnamep[0]='\0';

        for(i=0;i<maxnodes && node == -1;i++){
 	strcpy(dirnamep,"/sys/devices/system/node/node0/cpu0");
        dir = opendir(dirnamep);

        if (dir == NULL) {
                return -1;
        }
        while ((dirent = readdir(dir)) != 0) {
                if (!strncmp("cpu", dirent->d_name, 3)) {
                    strcat(dirnamec,dirent->d_name);  
		    printf("dir %s\n",dirnamec);
                }
        }
        closedir(dir);
     }
}

//get cpu frequence
float get_freq()
{
  float freq=0.0;
 
  FILE *fp_nodes;

  char command[256];
  	 
  command[0]='\0'; 
  strcpy(command,"cat /proc/cpuinfo | grep 'cpu MHz' | head -n 1 | awk '{print $4}'");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%f",&freq);   
  fclose(fp_nodes);

  return (freq); 
}

float na_get_freq()
{
  return FREQ;
}

/*list all cache levels of the machine*/
int na_get_numcaches()
{
  int ncaches=-1;
 
  FILE *fp_nodes;

  char command[256];
  	 
  command[0]='\0'; 
  strcpy(command,"ls /sys/devices/system/node/node0/cpu0/cache/ | wc -l");

  fp_nodes = popen(command,"r");
  fscanf(fp_nodes,"%d",&ncaches);   
  fclose(fp_nodes);

  return (ncaches-1); 
}

/*max number of cores per socket*/
int get_cpussockets()
{
  int max_cores_s=0,max_cores,i;
  FILE *fp_sockets;
  char command[512],temp[64];
  int tmp;

  max_cores = na_get_maxcpus();
 
  for(i=0;i<max_cores;i++)
        {
                command[0]='\0';
                strcpy(command,"cat /sys/devices/system/cpu/cpu");
                sprintf(temp,"%i",i);
                strcat(command,temp);
                strcat(command,"/topology/physical_package_id\n");
                fp_sockets = popen(command,"r");
                fscanf(fp_sockets,"%d",&tmp);
                fclose(fp_sockets);

                if(tmp == 0){
                  max_cores_s++; }
        }

   return max_cores_s;
}

/*max number of cores per socket*/
int na_get_cpussockets()
{
  return MAXCORESSOCKET;
} 

/*get cores iDs of a socket*/
int* na_get_cpusidsocket(int socket)
{
  int *cores_ids,*tcores_ids,max_cores_s,max_cores,i,*s_cores,k,j;
  FILE *fp_sockets;
  char command[512],temp[64];
  int tmp,shared;

  max_cores_s = na_get_cpussockets();
  cores_ids = malloc(max_cores_s*(sizeof(int)));
  tcores_ids = malloc(max_cores_s*(sizeof(int)));
  max_cores = na_get_maxcpus();
  shared = na_get_cache_cores();
  s_cores = malloc((shared-1)*sizeof(int));
  
   k=0;
  for(i=0;i<max_cores;i++)
	{
		command[0]='\0';
		strcpy(command,"cat /sys/devices/system/cpu/cpu");
		sprintf(temp,"%i",i);
		strcat(command,temp);
		strcat(command,"/topology/physical_package_id\n");
		fp_sockets = popen(command,"r");
		fscanf(fp_sockets,"%d",&tmp);
		fclose(fp_sockets);

		if(tmp == socket){
		  tcores_ids[k]=i; k++; }
	}

    //TODO: if remove  duplicated cores
   k=0;
   for(i=0;i<max_cores_s;i++)
   {
//        printf("\n%d CORE buscando sibling: %d",i,tcores_ids[i]); 
   	s_cores = na_get_cacheShare_cores(tcores_ids[i]);
        
	cores_ids[k] = 	tcores_ids[i];
	k++;
	for(j=0;j<max_cores_s && j<(shared-1);j++){
	   cores_ids[k] = s_cores[j];	
	   k++;
	}   
   }  	   

   return cores_ids;
}

int na_get_maxneighbors()
{
  FILE *fp_numa_f;
  int n_neighbors;
  
  fp_numa_f = fopen("/tmp/output/numaneighbor.minas", "r");
 
  if(fp_numa_f != NULL){
    fscanf(fp_numa_f,"%d",&n_neighbors);
    fclose(fp_numa_f);
  }
  else
	printf("\n Error: Fail in reading /tmp/output/numaneighbor.minas");	

  return n_neighbors;
}

int* na_get_nneighbors(int node)
{
  int *node_ids=NULL,*tmp=NULL;

  FILE *fp_numa_f;
  int maxnodes,i,j,temp,count,n_neighbors;
  maxnodes  = MAXNODES;

  fp_numa_f = fopen("/tmp/output/numaneighbor.minas", "r");
 
  if(fp_numa_f != NULL){
    fscanf(fp_numa_f,"%d",&n_neighbors);
    node_ids = malloc(n_neighbors*sizeof(int));
    for(i=0;i<maxnodes+1;i++)
      	for(j=0;j<n_neighbors;j++){
		fscanf(fp_numa_f,"%d",&temp);
		 if(i == node) node_ids[j]=temp;
    	}

    fclose(fp_numa_f);
  }
  else 
    {
      fp_numa_f = fopen("/tmp/output/numafactor_lmbench.minas", "r");
 
      if(fp_numa_f != NULL){
	n_neighbors = na_get_maxneighbors();
	node_ids = malloc((n_neighbors)*sizeof(int));
	tmp = malloc((n_neighbors+1)*sizeof(int));
	for(i=0;i<maxnodes+1;i++)
	    for(j=0;j<=n_neighbors;j++){
		if(i == node) fscanf(fp_numa_f,"%d",&temp);
		tmp[j]=temp;}
	    }
	fclose(fp_numa_f);
	int min,index;
	for(i=0;i<n_neighbors;i++){
	  min = tmp[0]; index = -1;
	 for(i=1;i<=n_neighbors;i++)
	   if(min>tmp[i] && tmp[i]!=1)
	     {min = tmp[i]; index=i;}
	  tmp[i] = 1;
	  if(index == -1 )node_ids[i]=0; else node_ids[i]=index;    
	 }     		
    }

  return node_ids;
}
