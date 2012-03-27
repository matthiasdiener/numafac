#!/bin/bash

CPU_POSSIBLE_COUNT=$(ls -d ${SYSFS_CPU}/cpu[0-9]* | wc -l)
NODE_POSSIBLE_COUNT=$(ls -1d ${SYSFS_NODE}/node[0-9]* | wc -l)

cd stream
make clean
make

export OMP_NUM_THREADS=${CPU_POSSIBLE_COUNT}
./stream_c.exe >> ../output/streamlocal.minas
export OMP_NUM_THREADS=1
numactl --membind=0 --physcpubind=0 ./stream_c.exe >> ../output/streamlocal.minas

#running Stream for every node on the machine
for ((j=0;j < ${NODE_POSSIBLE_COUNT} ;j++)); do
	core=`ls -d /sys/devices/system/node/node$j/cpu[0-9]* | head -1`
	core=`basename $core | sed s/cpu//`
	for ((i=0;i<${NODE_POSSIBLE_COUNT};i++)); do
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

echo -e "\n#NUMA factor" >> ../output/numacost.minas
awk '{sum+=$0} END { print sum/NR}' tnumafactor.minas >> ../output/numacost.minas

cat tnumafactor.minas | paste ${columns} > ../output/numafactor_stream.minas
rm tnumafactor.minas