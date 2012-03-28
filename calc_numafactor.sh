#!/bin/bash

PROGNAME=$(basename $0)

#sysfs
SYSFS_CPU="/sys/devices/system/cpu"
SYSFS_NODE="/sys/devices/system/node"

CPU_POSSIBLE_COUNT=$(ls -d ${SYSFS_CPU}/cpu[0-9]* | wc -l)
NODE_POSSIBLE_COUNT=$(ls -1d ${SYSFS_NODE}/node[0-9]* | wc -l)

rm -rf output
mkdir -p output

if [ 1 -eq 1 ]; then

echo ">>>$PROGNAME: Compiling Stream Benchmark"
cd stream
make

echo ">>>$PROGNAME: Running Stream Benchmark on all cores"
export OMP_NUM_THREADS=${CPU_POSSIBLE_COUNT}
./stream_c.exe >> ../output/streamlocal.minas

echo ">>>$PROGNAME: Running Stream Benchmark on first core"
export OMP_NUM_THREADS=1
numactl --membind=0 --physcpubind=0 ./stream_c.exe >> ../output/streamlocal.minas

echo ">>>$PROGNAME: Running Stream Benchmark on different nodes"
#running Stream for every node on the machine
for ((j=0;j < ${NODE_POSSIBLE_COUNT} ;j++)); do
	core=`ls -d /sys/devices/system/node/node$j/cpu[0-9]* | head -1`
	core=`basename $core | sed s/cpu//`
	for ((i=0;i<${NODE_POSSIBLE_COUNT};i++)); do
		echo ">>>$PROGNAME: Running Stream Benchmark between node $i and core $core"
		numactl --membind=$i --physcpubind=$core ./stream_c.exe >> ../output/stream.minas
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
echo -e "\n#Remote bandwidth" >> ../output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' band.data >> ../output/numacost.minas

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


echo -e ">>>$PROGNAME: NUMA factor calculated using Stream benchmark (bandwidth):"
echo -e "\n#NUMA factor" >> ../output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' tnumafactor.minas |tee -a ../output/numacost.minas

cat tnumafactor.minas | paste ${columns} > ../output/numafactor_stream.minas
rm tnumafactor.minas

cd ..

fi



#####################################################
CACHE_LEVEL=`ls -d ${SYSFS_CPU}/cpu0/cache/index[0-9]* | wc -l`;
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


#Latency for read - REMOTE and LOCAL

echo ">>>$PROGNAME: Compiling lmbench3"
cd lmbench3
make build

folder=`ls bin/`
cd bin/$folder

cp lmbench.a ../../../latencies/

echo ">>>$PROGNAME: Running lmbench3 on local node"
./lat_mem_rd -P 1 -N 1 $LLC_SIZE $L2_SIZE &> tmp.out
echo -e "\n#Local Latency " >> ../../../output/numacost.minas
cat tmp.out | tail -2 |  awk '{print $2}' >> ../../../output/numacost.minas
rm tmp.out

####################################################################
#running lat_mem for every node on the machine
echo ">>>$PROGNAME: Running lmbench3 for all nodes"
for ((j=0;j < ${NODE_POSSIBLE_COUNT} ;j++))
do
core=`ls -d /sys/devices/system/node/node$j/cpu[0-9]* | head -1`
core=`basename $core | sed s/cpu//`
for ((i=0;i<${NODE_POSSIBLE_COUNT};i++))
do
echo ">>>$PROGNAME: Running lmbench3 between node $i and core $core"
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

echo -e ">>>$PROGNAME: NUMA factor calculated using lmbench3 (latency):"
echo -e "\n#NUMA factor lmbench" >> ../../../output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' tnumafactor.minas |tee -a ../../../output/numacost.minas

cat tnumafactor.minas | paste ${columns} > ../../../output/numafactor_lmbench.minas
rm tnumafactor.minas

cat tlatency.minas | paste ${columns} > ../../../output/latency_lmbench.minas
rm tlatency.minas

