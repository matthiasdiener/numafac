/*-----------------------------------------------------------------------*/
/* Program: Topo                                                         */
/* Programmers: Christiane Pousa                                         */
/*                                                                       */
/* This program saves the machine topology                               */
/*-----------------------------------------------------------------------*/

# include <stdio.h>
# include <stdlib.h>
# include <math.h>
# include <float.h>
# include <limits.h>
# include <sys/time.h>

#include "archTopology.h"
#include "archTopo.h"

main(int argc, char **argv)
{
  int helperThread, isNuma,numThreads,threadDist,vector,i;
  int *cores, *htcores, *wscores;

  isNuma = atoi(argv[1]);
  helperThread = atoi(argv[2]);
  threadDist = atoi(argv[3]); 
  vector = atoi(argv[4]);

  numThreads = na_get_maxcpus();
  if(helperThread)
    numThreads = numThreads/2;

  switch(vector){
  case 1: //cores for threads distribution
    if(isNuma)
      cores = na_computeIds_Nodes(numThreads,threadDist,helperThread);
    else
      cores = na_computeIds_Cores(numThreads,threadDist,helperThread); 
    for(i=0;i<numThreads;i++){
	if(i==numThreads-1)   printf("%d \n",cores[i]);
	else  printf("%d \t",cores[i]);}
    break;
  case 2://cores for HT
    if(threadDist)
      htcores = na_max_share_ht(numThreads);
    else
      htcores = na_min_share_ht(numThreads);
     for(i=0;i<numThreads;i++){
      if(i==numThreads-1)  printf("%d \n",htcores[i]);
      else printf("%d \t",htcores[i]);}
    break;
  case 3://cores for WS
    if(threadDist)
      wscores = na_workStealing_max(numThreads,helperThread);
    else
      wscores = na_workStealing_min(numThreads,helperThread); 
    for(i=0;i<numThreads;i++){
         if(i==numThreads-1)  printf("%d \n",wscores[i]);
	    else printf("%d \t",wscores[i]);}
    break;
  }  
}
