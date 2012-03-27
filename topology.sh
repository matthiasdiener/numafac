#!/bin/bash

##################################PATHMINAS
cd ..
PATHMINAS="$(pwd)"
cd -

##################################COMPILER
CC=gcc
FF=gfortran

##################################ARCHITECTURE
ARCH=-DX86_64_ARCH

###############################LIBRARIES
LIBNUMA=-lnuma
LIBTHREAD=-lpthread
LIBNCURSES=-lncurses
LIBMATH=-lm

echo ${PATHMINAS}

echo -e "#ifndef __ARCHTOPO_H\n#define __ARCHTOPO_H\n#ifdef __cplusplus
\nextern \"C\" {\n#endif" > ${PATHMINAS}/archTopology/include/archTopo.h

###################################################################
if [ -d "${PATHMINAS}/archTopology/output" ]; then
   rm -rf ${PATHMINAS}/archTopology/output
   rm -rf /tmp/output/
fi

mkdir ${PATHMINAS}/archTopology/output

###################################################################
#sysfs
SYSFS_CPU="/sys/devices/system/cpu"
SYSFS_NODE="/sys/devices/system/node"
####################################################################

######################   NUMA    ###################################
if [ -d "${SYSFS_NODE}/node1" ]; then

####################################################################
#number of nodes and cpus
NODE_POSSIBLE_COUNT=`ls -1d ${SYSFS_NODE}/node[0-9]* | wc -l`
CPU_POSSIBLE_COUNT=`ls -d ${SYSFS_CPU}/cpu[0-9]* | wc -l`
NODE_CPUS=`ls -d ${SYSFS_NODE}/node0/cpu[0-9]* | wc -l`
LLC=`ls -d ${SYSFS_CPU}/cpu0/cache/index[0-9]* | wc -l`
let LLC=$LLC-1;
L1=`cat ${SYSFS_CPU}/cpu0/cache/index0/size | tr -d 'K'` 
MEM=`awk '/MemTotal/ {print $4}' ${SYSFS_NODE}/node0/meminfo`
FREQ=`cat /proc/cpuinfo | grep 'cpu MHz' | head -n 1 | awk '{print $4}'`;

for((i=0;i<${CPU_POSSIBLE_COUNT};i++)); do cpu=`cat /sys/devices/system/cpu/cpu${i}/topology/physical_package_id`;  if [ $cpu -eq 0 ];  then let MAXCORESSOCKET=$MAXCORESSOCKET+1;  fi; done; 

NODE_CPUIDS=""; for i in `ls -d /sys/devices/system/node/node0/cpu[0-9]*`; do NODE_CPUIDS=$NODE_CPUIDS" `basename $i | sed s/cpu//`"; done; PACKAGE_COUNT=1; j=0; for i in ${NODE_CPUIDS}; do let j=$j+1; p=`cat /sys/devices/system/cpu/cpu${i}/topology/physical_package_id`; PACKAGE[${p}]+="${j}"; if [ ${PACKAGE_COUNT} -lt $((${p}+1)) ]; then  let PACKAGE_COUNT=$((${p}+1)) ; fi; done;

echo -e "\n #define ISNUMA 1" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define SHAREDCACHE 0" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXNODES $NODE_POSSIBLE_COUNT" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXCPUS $CPU_POSSIBLE_COUNT" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define CPUSNODE $NODE_CPUS" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define LLC $LLC" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define L1CACHE $L1" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define TOTALMEM $MEM" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXSOCKETS 0" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define SOCKETSNODE $PACKAGE_COUNT" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define FREQ $FREQ" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXCORESSOCKET $MAXCORESSOCKET" >> ${PATHMINAS}/archTopology/include/archTopo.h

echo -e "#ifdef __cplusplus\n}\n#endif\n#endif" >> ${PATHMINAS}/archTopology/include/archTopo.h
####################################################################
#running topology on local way
cd ${PATHMINAS}/archTopology
make clean
make

####################################################################
#running Stream on local way
cd ${PATHMINAS}/archTopology/stream
make clean
make

export OMP_NUM_THREADS=${CPU_POSSIBLE_COUNT}
./stream_c.exe >> ${PATHMINAS}/archTopology/output/streamlocal.minas
export OMP_NUM_THREADS=1
numactl --membind=0 --physcpubind=0 ./stream_c.exe >> ${PATHMINAS}/archTopology/output/streamlocal.minas

####################################################################
#running Stream for every node on the machine
for ((j=0;j < ${NODE_POSSIBLE_COUNT} ;j++))
do
core=`ls -d /sys/devices/system/node/node$j/cpu[0-9]* | head -1`
core=`basename $core | sed s/cpu//`
for ((i=0;i<${NODE_POSSIBLE_COUNT};i++))
do
numactl --membind=$i --physcpubind=$core ./stream_c.exe >> ${PATHMINAS}/archTopology/output/stream.minas
done
done

####################################################################
#get bandwidth and access time local and remote
echo -e "\n#Local Parallel bandwidth" >> ${PATHMINAS}/archTopology/output/numacost.minas
cat ${PATHMINAS}/archTopology/output/streamlocal.minas | egrep '(Triad)' | head -1 | awk '{print $2}' >> ${PATHMINAS}/archTopology/output/numacost.minas
echo -e "\n#Local Sequential bandwidth" >> ${PATHMINAS}/archTopology/output/numacost.minas
cat ${PATHMINAS}/archTopology/output/streamlocal.minas | egrep '(Triad)' | head -2 | awk '{print $2}' >> ${PATHMINAS}/archTopology/output/numacost.minas

cat ${PATHMINAS}/archTopology/output/stream.minas | egrep '(Triad)' > stream.data
rm ${PATHMINAS}/archTopology/output/stream.minas
cut -f2  stream.data > tband.data
cut -f3  stream.data > tfn.data
rm stream.data
cut -c6-11 tfn.data > fn.data
cut -c3-11 tband.data > band.data
rm tfn.data tband.data

####################################################################
#computing average bandwidth and nodes bandwidth
echo -e "\n#Remote bandwidth" >> ${PATHMINAS}/archTopology/output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' band.data >> ${PATHMINAS}/archTopology/output/numacost.minas

columns=""
for ((i=0;i<${NODE_POSSIBLE_COUNT};i++))
do
columns=$columns"- "
done
cat band.data | paste ${columns} > ${PATHMINAS}/archTopology/output/bandwidth.minas
rm band.data

####################################################################
#Computing NUMA factor
counter=0
while read n
do
	let i=$counter/${NODE_POSSIBLE_COUNT}
	let j=$counter%${NODE_POSSIBLE_COUNT}
	let counter++

	var="tabela_${i}_${j}"
	declare $var=$n
done < fn.data
rm fn.data

ite=${NODE_POSSIBLE_COUNT}

for ((i=0;i<$ite;i++))
do
  for ((j=0;j<$ite;j++))
  do
    num="tabela_${i}_${j}"
    div="tabela_${i}_${i}"

    var="fator_${i}_${j}"
    declare $var=`echo scale=4\;${!num} / ${!div} | bc`
    echo ${!var} >> tnumafactor.minas
  done
done

echo -e "\n#NUMA factor" >> ${PATHMINAS}/archTopology/output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' tnumafactor.minas >> ${PATHMINAS}/archTopology/output/numacost.minas

cat tnumafactor.minas | paste ${columns} > ${PATHMINAS}/archTopology/output/numafactor_stream.minas
rm tnumafactor.minas

###########################################################################
cd ${PATHMINAS}
#NUMA topology
echo -e "#Machine Total Memory \t" > ${PATHMINAS}/archTopology/output/numatopology.minas
awk '/MemTotal/ {print $2}' /proc/meminfo  >> ${PATHMINAS}/archTopology/output/numatopology.minas
echo -e "\n#Machine Number of Nodes \t" >> ${PATHMINAS}/archTopology/output/numatopology.minas
ls -1d /sys/devices/system/node/node*|wc|awk '{print $1}' >> ${PATHMINAS}/archTopology/output/numatopology.minas
echo -e "\n#Machine Number of cpus/cores \t" >> ${PATHMINAS}/archTopology/output/numatopology.minas
echo ${CPU_POSSIBLE_COUNT}  >> ${PATHMINAS}/archTopology/output/numatopology.minas
echo -e "\n#Machine Number of cpus/cores per node \t" >> ${PATHMINAS}/archTopology/output/numatopology.minas
echo ${NODE_CPUS}  >> ${PATHMINAS}/archTopology/output/numatopology.minas
echo -e "\n";
CACHE_LEVEL=`ls -d ${SYSFS_CPU}/cpu0/cache/index[0-9]* | wc -l`;

for ((i=0;i<${NODE_POSSIBLE_COUNT};i++))
do
echo -e "NODE #${i}\n" >> ${PATHMINAS}/archTopology/output/numatopology.minas;
NODE_MEM=`awk '/MemTotal/ {print $4}' ${SYSFS_NODE}/node${i}/meminfo`
echo -e "Memory size ${NODE_MEM}\n" >> ${PATHMINAS}/archTopology/output/numatopology.minas
  for p in `ls -d ${SYSFS_NODE}/node${i}/cpu[0-9]*`; do
    j="`basename $p | sed s/cpu//`";
    echo -e "Cpu/Core #${j}\n"  >> ${PATHMINAS}/archTopology/output/numatopology.minas;
      for ((cl=0;cl<${CACHE_LEVEL};cl++))
        do
         CPU_CACHE=`cat ${SYSFS_CPU}/cpu${j}/cache/index${cl}/size | tr -d 'K'`;
         echo -e "Cache level #${cl} size ${CPU_CACHE} k\n" >> ${PATHMINAS}/archTopology/output/numatopology.minas;
        done;
  done;
done;

let llc=`expr ${CACHE_LEVEL}-1`
LLC_SIZE=`cat ${SYSFS_CPU}/cpu0/cache/index${llc}/size | tr -d 'K'`
if [ ${llc} -eq 2 ] 
then
  L2_SIZE=${LLC_SIZE}
  let L2_SIZE=${L2_SIZE}*${NODE_POSSIBLE_COUNT}
else
  L2_SIZE=`cat ${SYSFS_CPU}/cpu0/cache/index2/size | tr -d 'K'`
  let LLC_SIZE=${LLC_SIZE}/1024
  let LLC_SIZE=${LLC_SIZE}*${NODE_POSSIBLE_COUNT}*2
fi


###################################################################################
#Latency for read - REMOTE and LOCAL
cd ${PATHMINAS}/archTopology/lmbench3
#mkdir ./SCCS
#touch ./SCCS/s.ChangeSet
make build

folder=`ls bin/`
cd bin/$folder

echo $folder

cp lmbench.a $PATHMINAS/archTopology/latencies/

./lat_mem_rd -P 1 -N 1 $LLC_SIZE $L2_SIZE &> tmp.out
echo -e "\n#Local Latency " >> ${PATHMINAS}/archTopology/output/numacost.minas
cat tmp.out | tail -2 |  awk '{print $2}' >> ${PATHMINAS}/archTopology/output/numacost.minas
rm tmp.out

####################################################################
#running lat_mem for every node on the machine
for ((j=0;j < ${NODE_POSSIBLE_COUNT} ;j++))
do
core=`ls -d /sys/devices/system/node/node$j/cpu[0-9]* | head -1`
core=`basename $core | sed s/cpu//`
for ((i=0;i<${NODE_POSSIBLE_COUNT};i++))
do
(numactl --membind=$i --physcpubind=$core ./lat_mem_rd -P 1 -N 1 $LLC_SIZE $L2_SIZE) &> tmp.out
cat tmp.out | tail -2 | awk '{print $2}' >> tlatencies.minas 
done
done

sed '/^$/d' < tlatencies.minas > latencies.minas
rm tlatencies.minas tmp.out

####################################################################
#Computing NUMA factor
counter=0
while read n
do
	let i=$counter/${NODE_POSSIBLE_COUNT}
	let j=$counter%${NODE_POSSIBLE_COUNT}
	let counter++

	var="tabela_${i}_${j}"
	declare $var=$n
done < latencies.minas
rm latencies.minas

ite=${NODE_POSSIBLE_COUNT}

for ((i=0;i<$ite;i++))
do
  for ((j=0;j<$ite;j++))
  do
    num="tabela_${i}_${j}"
    div="tabela_${i}_${i}"

    var="fator_${i}_${j}"
    lat="latency_${i}_${j}"
    declare $var=`echo scale=4\;${!num} / ${!div} | bc`
    declare $lat=`echo scale=4\;${!num} | bc`

    echo ${!var} >> tnumafactor.minas
    echo ${!lat} >> tlatency.minas
  done
done

echo -e "\n#NUMA factor lmbench" >> ${PATHMINAS}/archTopology/output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' tnumafactor.minas >> ${PATHMINAS}/archTopology/output/numacost.minas

cat tnumafactor.minas | paste ${columns} > ${PATHMINAS}/archTopology/output/numafactor_lmbench.minas
rm tnumafactor.minas

cat tlatency.minas | paste ${columns} > ${PATHMINAS}/archTopology/output/latency_lmbench.minas
rm tlatency.minas

if ! test -d /tmp/output
then
    mkdir /tmp/output
fi

cp ${PATHMINAS}/archTopology/output/* /tmp/output

#########################################################################################
# Get Multicore (caches, nodes) read latencies
cd $PATHMINAS/archTopology/latencies
make clean && make
hwloc-bind socket:0.pu:0 -- ./compute-latencies

#########################################################################################
# IS UMA MACHINE
else


####################################################################
#number of nodes and cpus
CPU_POSSIBLE_COUNT=`ls -d ${SYSFS_CPU}/cpu[0-9]* | wc -l`


NODE_POSSIBLE_COUNT=`ls -1d ${SYSFS_NODE}/node[0-9]* | wc -l`
CPU_POSSIBLE_COUNT=`ls -d ${SYSFS_CPU}/cpu[0-9]* | wc -l`
NODE_CPUS=`ls -d ${SYSFS_NODE}/node0/cpu[0-9]* | wc -l`
LLC=`ls -d ${SYSFS_CPU}/cpu0/cache/index[0-9]* | wc -l`
let LLC=$LLC-1;
L1=`cat ${SYSFS_CPU}/cpu0/cache/index0/size | tr -d 'K'` 
MEM=`awk '/MemTotal/ {print $4}' ${SYSFS_NODE}/node0/meminfo`
FREQ=`cat /proc/cpuinfo | grep 'cpu MHz' | head -n 1 | awk '{print $4}'`;

for((i=0;i<${CPU_POSSIBLE_COUNT};i++)); do cpu=`cat /sys/devices/system/cpu/cpu${i}/topology/physical_package_id`;  if [ $cpu -eq 0 ];  then let MAXCORESSOCKET=$MAXCORESSOCKET+1;  fi; done; 

PACKAGE_COUNT=1;CPU_POSSIBLE_COUNT=`ls -d /sys/devices/system/node/node0/cpu[0-9]* | wc -l`;for ((i=0;i<${CPU_POSSIBLE_COUNT};++i));do p=`cat /sys/devices/system/node/node0/cpu${i}/topology/physical_package_id`; PACKAGE[${p}]+=${i}; if [ ${PACKAGE_COUNT} -lt $((${p}+1)) ]; then let PACKAGE_COUNT=$((${p}+1)); fi done;

echo -e "\n #define ISNUMA 0" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define SHAREDCACHE 0" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXNODES 0" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXCPUS $CPU_POSSIBLE_COUNT" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define CPUSNODE 0" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define LLC $LLC" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define L1CACHE $L1" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define TOTALMEM $MEM" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXSOCKETS $PACKAGE_COUNT" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define SOCKETSNODE 0 " >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define FREQ $FREQ" >> ${PATHMINAS}/archTopology/include/archTopo.h
echo -e "\n #define MAXCORESSOCKET $MAXCORESSOCKET" >> ${PATHMINAS}/archTopology/include/archTopo.h

echo -e "#ifdef __cplusplus\n}\n#endif\n#endif" >> ${PATHMINAS}/archTopology/include/archTopo.h
####################################################################
#running Stream on local way
cd ${PATHMINAS}/archTopology/stream
make clean
make

export OMP_NUM_THREADS=${CPU_POSSIBLE_COUNT}
numactl ./stream_c.exe >> stream.minas
export OMP_NUM_THREADS=1
numactl --membind=0 --physcpubind=0 ./stream_c.exe >> stream.minas

####################################################################
#get bandwidth and access time local and remote
echo -e "\n#Parallel bandwidth" >> ${PATHMINAS}/archTopology/output/umacost.minas
cat stream.minas | egrep '(Triad)' | head -1 | awk '{print $2}' >> ${PATHMINAS}/archTopology/output/umacost.minas
echo -e "\n#Sequential bandwidth" >> ${PATHMINAS}/archTopology/output/umacost.minas
cat stream.minas | egrep '(Triad)' | head -2 | awk '{print $2}' >> ${PATHMINAS}/archTopology/output/umacost.minas
rm stream.minas

###########################################################################
cd ../
#UMA topology
echo -e "#Machine Total Memory \t" > ${PATHMINAS}/archTopology/output/umatopology.minas
awk '/MemTotal/ {print $2}' /proc/meminfo  >> ${PATHMINAS}/archTopology/output/umatopology.minas
echo -e "\n#Machine Number of cpus/cores \t" >> ${PATHMINAS}/archTopology/output/umatopology.minas
echo ${CPU_POSSIBLE_COUNT}  >> ${PATHMINAS}/archTopology/output/umatopology.minas
echo -e "\n";
CACHE_LEVEL=`ls -d ${SYSFS_CPU}/cpu0/cache/index[0-9]* | wc -l`;


  for p in `ls -d ${SYSFS_CPU}/cpu[0-9]*`; do
    j="`basename $p | sed s/cpu//`";
    echo -e "Core #${j}\n"  >> ${PATHMINAS}/archTopology/output/umatopology.minas;
      for ((cl=0;cl<${CACHE_LEVEL};cl++))
        do
         CPU_CACHE=`cat ${SYSFS_CPU}/cpu${j}/cache/index${cl}/size | tr -d 'K'`;
         echo -e "Cache level #${cl} size ${CPU_CACHE} k\n" >> ${PATHMINAS}/archTopology/output/umatopology.minas;
        done;
  done;


let llc=`expr ${CACHE_LEVEL}-1`
LLC_SIZE=`cat ${SYSFS_CPU}/cpu0/cache/index${llc}/size | tr -d 'K'`
if [ ${llc} -eq 2 ] 
then
  L2_SIZE=${LLC_SIZE}
  let L2_SIZE=${L2_SIZE}*${NODE_POSSIBLE_COUNT}
else
  L2_SIZE=`cat ${SYSFS_CPU}/cpu0/cache/index2/size | tr -d 'K'`
  let LLC_SIZE=${LLC_SIZE}/1024
  let LLC_SIZE=${LLC_SIZE}*${NODE_POSSIBLE_COUNT}*2
fi


###################################################################################
#Latency for read
cd ${PATHMINAS}/archTopology/lmbench3
if ! test -d ./SCCS
then 
    mkdir ./SCCS
fi
touch ./SCCS/s.ChangeSet
make build

folder=`ls bin/`
cd bin/$folder

echo $folder

./lat_mem_rd -P 1 -N 1 $LLC_SIZE $L2_SIZE &> tmp.out
echo -e "\n#Local Latency " >> ${PATHMINAS}/archTopology/output/umacost.minas
cat tmp.out | tail -2 |  awk '{print $2}' >> ${PATHMINAS}/archTopology/output/umacost.minas
cat tmp.out | tail -2 |  awk '{print $2}' >> ${PATHMINAS}/archTopology/output/latency_lmbench.minas
rm tmp.out

if ! test -d /tmp/output
then
    mkdir /tmp/output
fi

cp ${PATHMINAS}/archTopology/output/* /tmp/output

#########################################################################################
# Get Multicore (caches, nodes) read latencies
cd $PATHMINAS/archTopology/latencies
make clean && make
./compute-latencies


fi

