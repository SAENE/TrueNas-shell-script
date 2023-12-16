#!/bin/bash
date
for num_list in 1 2 3
do
ens_up_num=0
echo "本次脚本第${num_list}个循环"
# ens12_status=`ip link | grep enp12s0 | grep -o DOWN`
# ens11_status=`ip link | grep enp11s0 | grep -o DOWN`
# ens8_status=`ip link | grep enp8s0 | grep -o DOWN`
# ens7_status=`ip link | grep enp7s0 | grep -o DOWN`
ens_list=$(ip a | egrep -o 'enp[0-9]{1,2}s[0-9]')

for loop in ${ens_list}
do
	echo "${loop}"
	ens_status=$(ip link | grep ${loop} | grep -o DOWN)
	if [ -z ${ens_status} ]
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
	for loop in ${ens_list}
	do
	    echo "正在拉起${loop}"
	    ip link set ${loop} up
	done
else
	echo "有张网卡已连接，无需拉起"
fi

if [[ ${num_list} -lt 3  ]]
then
	sleep 15s
	echo -e '\n'
fi
done
echo -e '\n\n'
