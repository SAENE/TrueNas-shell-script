#!/bin/bash
date
for num_list in 1 2
do
ens_status=1
echo "本次脚本第${num_list}个循环"
ens12_status=`ip link | grep enp12s0 | grep -o DOWN`
ens11_status=`ip link | grep enp11s0 | grep -o DOWN`
ens8_status=`ip link | grep enp8s0 | grep -o DOWN`
ens7_status=`ip link | grep enp7s0 | grep -o DOWN`

ens_status=(${ens12_status} ${ens11_status} ${ens8_status} ${ens7_status})

for loop in 0 1 2 3
do
	echo "${ens_status[loop]}"
	if [ -z ${ens_status[loop]} ]
	then
		echo "这个网卡已启动"
		ens_up_num=1
	else
		echo "这个网卡已停止或者没有接线"
	fi
done

if [[ ${ens_up_num} -ne 1 ]]
then
	echo "所有网卡已掉线，正在拉起网卡"
	ip link set enp12s0 up
	ip link set enp11s0 up
	ip link set enp8s0 up
	ip link set enp7s0 up
else
	echo "有张网卡已连接，无需拉起"
fi

if [[ ${num_list} -eq 1  ]]
then
	sleep 30s
fi
done
echo -e '\n\n'
