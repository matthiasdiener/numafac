#!/bin/bash

PROGNAME=numaarch

#sysfs
SYSFS_CPU="/sys/devices/system/cpu"
SYSFS_NODE="/sys/devices/system/node"

CPU_POSSIBLE_COUNT=$(ls -d ${SYSFS_CPU}/cpu[0-9]* | wc -l)
NODE_POSSIBLE_COUNT=$(ls -1d ${SYSFS_NODE}/node[0-9]* | wc -l)

rm -rf output
mkdir -p output

echo ">>>$PROGNAME: Compiling Stream Benchmark"
cd stream
make clean
make

echo ">>>$PROGNAME: Running Stream Benchmark on all cores"
export OMP_NUM_THREADS=${CPU_POSSIBLE_COUNT}
./stream_c.exe |tee -a ../output/streamlocal.minas

echo ">>>$PROGNAME: Running Stream Benchmark on first core"
export OMP_NUM_THREADS=1
numactl --membind=0 --physcpubind=0 ./stream_c.exe | tee -a ../output/streamlocal.minas

echo ">>>$PROGNAME: Running Stream Benchmark on different nodes"
#running Stream for every node on the machine
for ((j=0;j < ${NODE_POSSIBLE_COUNT} ;j++)); do
	core=`ls -d /sys/devices/system/node/node$j/cpu[0-9]* | head -1`
	core=`basename $core | sed s/cpu//`
	for ((i=0;i<${NODE_POSSIBLE_COUNT};i++)); do
		echo ">>>$PROGNAME: Running Stream Benchmark core $core to node $i"
		numactl --membind=$i --physcpubind=$core ./stream_c.exe |tee -a ../output/stream.minas
	done
done



#get bandwidth and access time local and remote
echo -e "\n#Local Parallel bandwidth" >> ../output/numacost.minas
cat ../output/streamlocal.minas | egrep '(Triad)' | head -1 | awk '{print $2}' >> ../output/numacost.minas
echo -e "\n#Local Sequential bandwidth" >> ../output/numacost.minas
cat ../output/streamlocal.minas | egrep '(Triad)' | head -2 | awk '{print $2}' >> ../output/numacost.minas

cat ../output/stream.minas | egrep '(Triad)' > stream.data
rm ../output/stream.minas
cut -f2  stream.data > tband.data
cut -f3  stream.data > tfn.data
rm stream.data
cut -c6-11 tfn.data > fn.data
cut -c3-11 tband.data > band.data
rm tfn.data tband.data


#computing average bandwidth and nodes bandwidth
echo -e "\n#Remote bandwidth" |tee -a ../output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' band.data |tee -a ../output/numacost.minas

columns=""
for ((i=0;i<${NODE_POSSIBLE_COUNT};i++))
do
columns=$columns"- "
done
cat band.data | paste ${columns} > ../output/bandwidth.minas
rm band.data


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

echo ">>>$PROGNAME: NUMA factor from Stream Benchmark:"
echo -e "\n#NUMA factor" | tee -a ../output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' tnumafactor.minas | tee -a ../output/numacost.minas

cat tnumafactor.minas | paste ${columns} > ../output/numafactor_stream.minas
rm tnumafactor.minas

#######################################################################################
#######################################################################################
#######################################################################################





echo ">>>$PROGNAME: Compiling lmbench Benchmark"

#Latency for read - REMOTE and LOCAL
cd ../lmbench3
#mkdir ./SCCS
#touch ./SCCS/s.ChangeSet
make build

folder=`ls bin/`
cd bin/$folder

echo $folder

cp lmbench.a $PATHMINAS/archTopology/latencies/


echo ">>>$PROGNAME: Running lmbench benchmark on local node"
./lat_mem_rd -P 1 -N 1 $LLC_SIZE $L2_SIZE &> tmp.out
echo -e "\n#Local Latency " >> ../output/numacost.minas
cat tmp.out | tail -2 |  awk '{print $2}' >> ../output/numacost.minas
rm tmp.out


echo ">>>$PROGNAME: Running lmbench benchmark on different nodes"
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