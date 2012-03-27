#include <stdlib.h>
#include <hwloc.h>

#include "../lmbench3/src/bench.h"

#include "../include/archTopo.h"

static double cache_latencies[3];
static long cache_sizes[3];
static hwloc_topology_t topo;

#define	ONE	p=(char **)*p;
#define	FIVE	ONE ONE ONE ONE ONE
#define	TEN	FIVE FIVE
#define	FIFTY	TEN TEN TEN TEN TEN
#define	HUNDRED	FIFTY FIFTY

benchmp_f fpInit = stride_initialize;

double **nodes_matrix;
double **cores_matrix;
int *cpus_to_nodes;

static void
benchmark_loads(iter_t iterations, void *cookie)
{
  struct mem_state* state = (struct mem_state*)cookie;
  register char **p = (char**)state->p[0];
  register size_t i;
  register size_t count = state->len / (state->line * 100) + 1;
  
  while (iterations-- > 0) {
    for (i = 0; i < count; ++i) {
      HUNDRED;
    }
  }
  
  use_pointer((void *)p);
  state->p[0] = (char*)p;
}

static double 
compute_latency (size_t len)
{
  double latency = 0.0;
  size_t count;
  struct mem_state state;
  
  state.width = 1;
  state.len = len;
  state.maxlen = len;
  state.line = 512;
  state.pagesize = getpagesize();
  count = 100 * (state.len / (state.line * 100) + 1);
  
  /*
   * Now walk them and time it.
   */
  benchmp (fpInit, benchmark_loads, mem_cleanup, 100000, 1, 0, 1, &state);
  
  /* We want to get to nanoseconds / load. */
  latency = (1000. * (double)gettime()) / (double)(count * get_n());

  return latency;
}

static double 
coreFactor (int i, int j)
{
  hwloc_obj_t core1, core2, ancestor;
  double res = 0.0;
  
  if (i != j)
    {
      core1 = hwloc_get_obj_by_type (topo, HWLOC_OBJ_CORE, i);
      core2 = hwloc_get_obj_by_type (topo, HWLOC_OBJ_CORE, j);
      ancestor = hwloc_get_common_ancestor_obj (topo, core1, core2);
    
      if (ancestor->type == HWLOC_OBJ_CACHE)
	res = cache_latencies[ancestor->attr->cache.depth - 1];
      else
	res = nodes_matrix[cpus_to_nodes[i]][cpus_to_nodes[i]];
    }
  else
    res = cache_latencies[0];

  return res;
}

int
main (int argc, char **argv)
{
  int level = 0;
  hwloc_obj_t obj;
  FILE *nodes_fp, *cores_fp;
  int nb_nodes, nb_cores;
  int i, j;

  na_init ();

  hwloc_topology_init (&topo);
  hwloc_topology_load (topo);

  nb_nodes = hwloc_get_nbobjs_by_depth (topo, hwloc_get_type_depth (topo, HWLOC_OBJ_NODE));
  nb_cores = hwloc_get_nbobjs_by_depth (topo, hwloc_get_type_depth (topo, HWLOC_OBJ_PU));

  if (nb_nodes == 0)
	   nb_nodes = 1;

  nodes_matrix = malloc(nb_nodes*sizeof(double*));
  cores_matrix =  malloc(nb_cores*sizeof(double*));
  cpus_to_nodes = malloc(nb_cores*sizeof(int));

  for(i = 0; i < nb_nodes; i++)
    nodes_matrix[i] = malloc(nb_nodes*sizeof(double));
  for(i = 0; i < nb_cores; i++)
    cores_matrix[i] = malloc(nb_cores*sizeof(double));

  for (i = 0; i < nb_cores; i++)
    if (ISNUMA)
      cpus_to_nodes[i] = na_get_nodeidcpu (i);
    else
      bzero (cpus_to_nodes, nb_cores * sizeof (int));

  for (obj = hwloc_get_obj_by_type (topo, HWLOC_OBJ_PU, 0);
       obj;
       obj = obj->parent)
    {
      if (obj->type == HWLOC_OBJ_CACHE) 
	{
	  cache_sizes[level] = obj->attr->cache.size;
	  level++;
	}
    }

  cache_latencies[0] = compute_latency (cache_sizes[0] / 2);
  cache_latencies[1] = compute_latency ((cache_sizes[1] - cache_sizes[0]) / 2);
  cache_latencies[2] = compute_latency ((cache_sizes[2] - cache_sizes[1]) / 2);
  
  nodes_fp = fopen("/tmp/output/latency_lmbench.minas","r");
  cores_fp = fopen("/tmp/output/latency_lmbench_multicore.minas","w+");

  for (i = 0; i < nb_nodes; i++)
    for (j = 0; j < nb_nodes; j++)
      fscanf (nodes_fp, "%lf", &nodes_matrix[i][j]);

  for (i = 0; i < nb_cores; i++) 
    {
      int current_node = cpus_to_nodes[i];
      for (j = 0; j < nb_cores; j++)
	cores_matrix[i][j] = (cpus_to_nodes[j] == current_node) ? coreFactor (i, j) : nodes_matrix[current_node][cpus_to_nodes[j]];
    }

  for (i = 0; i < nb_cores; i++)
    {
      for (j = 0; j < nb_cores; j++)
	fprintf (cores_fp, "%lf ", cores_matrix[i][j]);
      fprintf (cores_fp, "\n");
    }

  return 0;
} 
