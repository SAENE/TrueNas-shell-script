#!/bin/bash
date
# 设置环境变量
vm_num="102"
nas_ip="198.19.1.99"
ups_status=$(upsc ups@192.168.1.99 | grep "ups.status:")
#for num_list in 1 2 3
#do
if [[ "ups_status" == "ups.status: OL CHRG" ]]
then
	echo "本次脚本第${num_list}个循环"
	# 检测nas是否运行
	if !  ping -c 1 ${nas_ip} &> /dev/null ;
	then
		# nas关机了
		nas_status=0
	else
		# nas运行中
		nas_status=1
	fi

	# 检测虚拟机状态
	if [[ $(/usr/sbin/qm status ${vm_num} | egrep -o "stopped") ]]
	then
		# 虚拟机已经关机
		vm_status=0
	elif [[ $(/usr/sbin/qm status ${vm_num} | egrep -o "running") ]]
	then
		vm_status=1
	fi

	# 判断并进行操作
	if [[ ${vm_status} -eq 1 && ${nas_status} -eq 0 ]]
	then
		/usr/sbin/qm stop ${vm_num} --skiplock true
		echo "NAS已经关机，关闭虚拟机"
	elif [[ ${vm_status} -eq 0 && ${nas_status} -eq 1 ]]
	then
		/usr/sbin/qm start ${vm_num}
		echo "NAS运行中，开启虚拟机"
	elif [[ ${vm_status} -eq 1 && ${nas_status} -eq 1 ]]
	then
		echo "一切正常"
	elif [[ ${vm_status} -eq 0 && ${nas_status} -eq 0 ]]
	then
		echo "全部关闭"
	fi

#	if [[ ${num_list} -lt 3  ]]
#	then
#		sleep 15s
#		echo -e '\n'
#	fi
#done
fi
echo -e '\n\n'
