#!/bin/bash
##环境变量
cpu_temp_sys=71
cpu_temp_ipmi=78

date  +"%Y-%m-%d %H:%M.%S"
##风扇策略调节
if [[ `echo $[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]` -ge ${cpu_temp_sys} || `ipmitool sdr | grep CPU1 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` -ge ${cpu_temp_ipmi}  || `ipmitool sdr | grep CPU2 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` -ge ${cpu_temp_ipmi} ]]; then
    if [[ `ipmitool raw 0x30 0x45 0x00` != " 01" ]]; then
        echo "CPU温度大于于${cpu_temp_sys}，风扇模式改为Full Speed"
        ipmitool raw 0x30 0x45 0x01 0x01
    else
        echo "无需修改，CPU温度大于${cpu_temp_sys}，风扇模式为Full Speed"
    fi
elif [[ `echo $[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]` -lt ${cpu_temp_sys} || `ipmitool sdr | grep CPU1 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` -lt ${cpu_temp_ipmi}  || `ipmitool sdr | grep CPU2 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` -lt ${cpu_temp_ipmi} ]]; then
    if [[ `ipmitool raw 0x30 0x45 0x00` != " 02" ]]; then
        echo "CPU温度小于于${cpu_temp_sys}，风扇模式改为Optimal Speed"
        ipmitool raw 0x30 0x45 0x01 0x02
    else
        echo "无需修改，CPU温度小于${cpu_temp_sys}，风扇模式为Optimal Speed"
    fi
fi
echo -e "\n"
