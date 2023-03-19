#!/bin/bash
#打印时间
date  +"%Y-%m-%d %H:%M.%S"

#环境变量
##频率调节策略
cpu_power_mode="conservative"

##温度设置
cpu_normal_temp_limit=70 #正常温度
cpu_super_temp_limit=80 #高温温度
cpu_super_temp_plus_limit=90 #紧急温度

##频率设置
cpu_normal_temp_limit_max_freq=`expr 3200 \* 1000` #正常温度频率
cpu_normal_temp_limit_nomarl_freq=`expr 1200 \* 1000` #正常温度频率
cpu_super_temp_limit_max_freq=`expr 2400 \* 1000` #高温温度频率
cpu_super_temp_limit_plus_max_freq=`expr 1400 \* 1000` #紧急温度频率
cpu_temp_limit_min_freq=`expr 1300 \* 1000` #最低频率
cpu_min_idle=40 #cpu最小占空比
app_use_max_cpu_limit=100

##客观变量获取命令
fan_mode_get=`ipmitool raw 0x30 0x45 0x00`
cpu_max_freq_get="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq" #获取cpu0最高频率设置
cpu_min_freq_get="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq" #获取cpu0最低频率设置
cpu_now_freq_get="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" #获取cpu0当前频率设置
cpu_temp_sys_get="echo $[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]" #从系统获取cpu温度，如果两个以上cpu，默认是平均温度
cpu1_temp_ipmi_get=`ipmitool sdr | grep CPU1 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` #通过ipmi获取cpu温度
cpu2_temp_ipmi_get=`ipmitool sdr | grep CPU2 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` #同上
cpu_idle=`top -bcn 1 -w 200 | grep '%Cpu(s)' | sed 's/.*ni,//g' | sed 's/\..*id,.*//g' | awk -F'[" "%]+' '{print $2}' | sed 's/root//g' | sed -n '1p'` #cpu占空比获取
app_use_max_cpu=`top -bcn 1 -w 200 | sed -n '8,20p' | sed 's/.*plexmediaserver.*//g' | sed 's/.*Emby.*//g' | sed 's/.*qemu.*//g' | awk -F'[" "%]+' '{print $10}' | sed 's/\..//g' | sed '/^\s*$/d' | sed -n '1p'`

#检测命令是否安装
if [ ! type cpufreq-set > /dev/null 2>&1 ] 
then 
    echo "请安装cpufrequtils" 
    exit
fi

#根据温度调节风扇策略


#根据温度调节cpu频率和风扇策略
##正常温度频率调节
if [[  `${cpu_temp_sys_get}` -lt ${cpu_normal_temp_limit} || ${cpu1_temp_ipmi_get} -lt ${cpu_normal_temp_limit} && ${cpu2_temp_ipmi_get} -lt ${cpu_normal_temp_limit} ]]
then
    if [[ ${cpu_idle} -gt ${cpu_min_idle} && `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} || ${app_use_max_cpu} -le ${app_use_max_cpu_limit} && `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} ]]
    then
        echo "cpu温度正常，正在恢复设置"
        echo "cpu占用低，正在降低cpu性能"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_normal_temp_limit_nomarl_freq}
        done
        ipmitool sensor thresh "CPU1 Temp" upper 100 100 100
        ipmitool sensor thresh "CPU2 Temp" upper 100 100 100
        if [[ ${fan_mode_get} -ne " 02" ]]
        then
            echo "CPU温度小于${cpu_normal_temp_limit}，风扇模式改为Optimal Speed"
            ipmitool raw 0x30 0x45 0x01 0x02
        fi
    else
        if [[ ${cpu_idle} -le ${cpu_min_idle} && `${cpu_max_freq_get}` -lt ${cpu_normal_temp_limit_max_freq} || ${app_use_max_cpu} -gt ${app_use_max_cpu_limit} && `${cpu_max_freq_get}` -lt ${cpu_normal_temp_limit_max_freq} ]]
        then
            echo '有应用高占用，正在提高cpu性能'
            for((i=0;i<=39;i++));
            do
                cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_normal_temp_limit_max_freq}
            done
        fi
        echo "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Optimal Speed"
        echo "cpu温度正常"
    fi
##紧急温度频率调节
elif [[ `${cpu_temp_sys_get}` -ge ${cpu_super_temp_plus_limit} || ${cpu1_temp_ipmi_get} -ge ${cpu_super_temp_plus_limit} || ${cpu2_temp_ipmi_get} -ge ${cpu_super_temp_plus_limit} ]]
then
    if [[ `${cpu_max_freq_get}` -gt ${cpu_super_temp_limit_plus_max_freq} ]]
    then
        echo "cpu温度超高,设置频率为${cpu_super_temp_limit_plus_max_freq}"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_super_temp_limit_plus_max_freq}
        done
        ipmitool sensor thresh "CPU1 Temp" upper 120 120 120
        ipmitool sensor thresh "CPU2 Temp" upper 120 120 120
        if [[ ${fan_mode_get} -ne " 01" ]]
        then
            echo "CPU温度大于${cpu_super_temp_plus_limit}，风扇模式改为Full Speed"
            ipmitool raw 0x30 0x45 0x01 0x01
        else
            echo "无需修改，CPU温度大于${cpu_super_temp_plus_limit}，风扇模式为Full Speed"
        fi
    else
        echo "cpu温度超高"
    fi
##高温温度频率调节
elif [[ `${cpu_temp_sys_get}` -ge ${cpu_super_temp_limit} || ${cpu1_temp_ipmi_get} -ge ${cpu_super_temp_limit} || ${cpu2_temp_ipmi_get} -ge ${cpu_super_temp_limit} ]]
then
    if [[ `${cpu_max_freq_get}` -gt ${cpu_super_temp_limit_max_freq} ]]
    then
         echo "cpu温度超高,设置频率为${cpu_super_temp_limit_max_freq}"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_super_temp_limit_max_freq}
        done
        ipmitool sensor thresh "CPU1 Temp" upper 110 110 110
        ipmitool sensor thresh "CPU2 Temp" upper 110 110 110
        if [[ ${fan_mode_get} -ne " 01" ]]
        then
            echo "CPU温度大于${cpu_super_temp_limit}，风扇模式改为Full Speed"
            ipmitool raw 0x30 0x45 0x01 0x01
        else
            echo "无需修改，CPU温度大于${cpu_super_temp_limit}，风扇模式为Full Speed"
        fi
    else
        echo "cpu温度过高"
    fi
else
    echo "无需修改，风扇模式为Optimal Speed"
    echo "cpu温度正常"
fi

#打印系统信息
echo "最大cpu占用应用${app_use_max_cpu}"
echo "cpu空占比 ${cpu_idle}%"
echo `${cpu_max_freq_get}`
cat /proc/cpuinfo | grep MHz | tail -n1
ipmitool sdr | grep CPU | grep Temp
echo $[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]°
echo -e "\n"
