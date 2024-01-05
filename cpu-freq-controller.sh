#!/bin/bash
#打印时间
date  +"%Y-%m-%d %H:%M.%S"

#环境变量
##设置可调参数
night_quiet=enable
force_quiet=false

##夜晚模式开启以及关闭时间
night_enable_time=23:00
night_stop_time=06:00

##频率调节策略
cpu_power_mode="performance" #conservative performance powersave  ondemand

##温度设置
cpu_normal_temp_limit=80 #正常温度
cpu_super_temp_limit=90 #高温温度
cpu_super_temp_plus_limit=95 #紧急温度

##频率设置
cpu_normal_temp_limit_max_freq=`expr 3000 \* 1000` #正常温度最大频率
cpu_normal_temp_limit_nomarl_freq=`expr 1200 \* 1000` #正常温度频率
cpu_super_temp_limit_max_freq=`expr 2600 \* 1000` #高温温度频率
cpu_super_temp_limit_plus_max_freq=`expr 2000 \* 1000` #紧急温度频率
cpu_temp_limit_min_freq=`expr 1200 \* 1000` #最低频率
cpu_temp_limit_min_freq2=`expr 2400 \* 1000` #最低频率
cpu_min_idle=40 #cpu最小占空比
app_use_max_cpu_limit=150

##客观变量获取命令
now_date_time=`date +%s`
fan_mode_get=`ipmitool raw 0x30 0x45 0x00`
cpu_max_freq_get="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq" #获取cpu0最高频率设置
cpu_min_freq_get="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq" #获取cpu0最低频率设置
cpu_now_freq_get="cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" #获取cpu0当前频率设置
cpu_temp_sys_get="echo $[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]" #从系统获取cpu温度，如果两个以上cpu，默认是平均温度
cpu1_temp_ipmi_get=`ipmitool sdr | grep CPU1 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` #通过ipmi获取cpu温度
cpu2_temp_ipmi_get=`ipmitool sdr | grep CPU2 | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g'` #同上
cpu_idle=`top -bcn 1 -w 200 | grep '%Cpu(s)' | sed 's/.*ni,//g' | sed 's/\..*id,.*//g' | awk -F'[" "%]+' '{print $2}' | sed 's/root//g' | sed -n '1p'` #cpu占空比获取
#app_use_max_cpu=`top -bcn 1 -w 200 | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}'`
#app_use_max_cpu=`top -bcn 1 -w 200 | sed '/plexmediaserver/d' | sed '/qbittorrent/d' | sed '/Emby/d' | sed '/\/usr\/bin\/qemu/d' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}'`
app_use_max_cpu=`top -bcn 1 -w 200 | sed '/\/usr\/bin\/qemu/d' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}'`
#app_use_max_cpu=`top -bcn 1 -w 200 | sed -n '8,20p' | sed 's/.*plexmediaserver.*\n//g' | sed 's/.*qbittorrent.*\n//g' | sed 's/.*Emby.*\n//g' | sed 's/.*qemu.*\n//g' | sed 's/.*S\n//g' | sed 's/.*R\n//g' | sed 's/.*I\n//g' | sed 's/.*top -bcn.*\n//g' | awk -F'[" "%]+' '{print $2}' | sed 's/\..//g' | sed '/^\s*$/d' | sed -n '1p'`
fan_mode_full="ipmitool raw 0x30 0x45 0x01 0x01"
fan_mode_standard="ipmitool raw 0x30 0x45 0x01 0x00"
fan_mode_optimal="ipmitool raw 0x30 0x45 0x01 0x02"

##函数设置
# 输出系统信息
Debug_log(){
    echo "最大cpu占用应用${app_use_max_cpu}"
    echo "cpu空占比 ${cpu_idle}%"
    echo "cpu最大频率`${cpu_max_freq_get}`"
    echo "cpu当前频率`cat /proc/cpuinfo | grep MHz | tail -n1` "
    echo "运行时cpu1温度${cpu1_temp_ipmi_get}"
    echo "运行时cpu2温度${cpu2_temp_ipmi_get}"
    echo "系统温度：$[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]°"
    echo "当前运行前8的程序"
    top -bcn 1 -w 200  | sed -n '7,15p'
    echo -e "\n"
}

ipmi_sensor_cpu_upper(){
    ipmitool sensor thresh "CPU1 Temp" upper ${1} ${1} ${1}
    ipmitool sensor thresh "CPU2 Temp" upper ${1} ${1} ${1}
}

ipmi_fans_mode(){
    ipmitool raw 0x30 0x45 0x01 0x0${1}
    fan_mode_get=`ipmitool raw 0x30 0x45 0x00`
    if [[ ${fan_mode_get} -eq " 02" ]]
    then
        echo "风扇模式设置为Optimal Speed"
    fi
    if [[ ${fan_mode_get} -eq " 01" ]]
    then
        echo "风扇模式设置为Full Speed"
    fi
    if [[ ${fan_mode_get} -eq " 00" ]]
    then
        echo "风扇模式设置为Standard Speed"
    fi
}

ipmi_fans_get(){
    if [[ ${fan_mode_get} -eq " 02" ]]
    then
        echo "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Optimal Speed"
    fi
    if [[ ${fan_mode_get} -eq " 01" ]]
    then
        echo "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Full Speed"
    fi
    if [[ ${fan_mode_get} -eq " 00" ]]
    then
        echo "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Standard Speed"
    fi
}

#检测命令是否安装
if [ ! type cpufreq-set > /dev/null 2>&1 ]
then
    echo "请安装cpufrequtils"
    exit 1
fi
#监测最大cpu占用应用数值是否为0
if [[ ${app_use_max_cpu} -eq 0 ]]
then
    app_use_max_cpu=`top -bcn 1 -w 200 | sed 's/.*plexmediaserver.*\n//g' | sed 's/.*qbittorrent.*\n//g' | sed 's/.*Emby.*\n//g' | sed 's/.*qemu.*\n//g' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}'`
fi
#夜晚模式以及强制模式
if [[ ${force_quiet} = "enable" ]]
then
    echo "检测到强制安静模式已开启"
    if [[ `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} ]]
    then
        echo "强制安静模式，CPU频率设置为最低"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_normal_temp_limit_nomarl_freq}
        done
    fi
    if [[ ${fan_mode_get} -ne " 02" ]]
    then
        ipmi_sensor_cpu_upper 105
        ipmi_fans_mode 2 # 风扇模式设置为Optimal
    fi
    Debug_log
    exit 0
elif [[ ${night_quiet} = "enable" ]]
then
    echo "检测到深夜安静模式已开启"
    echo "当前时间 ${now_date_time}"
    if [[ ${now_date_time} -ge  `date -d "${night_enable_time}" +%s` && ${now_date_time} -ge `date -d "${night_stop_time}" +%s` ]]
    then
        night_enable_time=`date -d "yesterday ${night_enable_time}" +%s`
        night_stop_time=`date -d "tomorrow ${night_stop_time}" +%s`
    elif [[ ${now_date_time} -le  `date -d "${night_enable_time}" +%s` && ${now_date_time} -ge `date -d "${night_stop_time}" +%s` ]]
    then
        night_enable_time=`date -d "${night_enable_time}" +%s`
        night_stop_time=`date -d "tomorrow ${night_stop_time}" +%s`
    elif [[ ${now_date_time} -le  `date -d "${night_enable_time}" +%s` && ${now_date_time} -le `date -d "${night_stop_time}" +%s` ]]
    then
        night_enable_time=`date -d "yesterday ${night_enable_time}" +%s`
        night_stop_time=`date -d "${night_stop_time}" +%s`
    elif [[ ${now_date_time} -ge `date -d "${night_enable_time}" +%s` && ${now_date_time} -le `date -d "${night_stop_time}" +%s` && `date -d "${night_stop_time}" +%s` -lt `date -d "${night_enable_time}" +%s` ]]
    then
        night_enable_time=`date -d "${night_enable_time}" +%s`
        night_stop_time=`date -d "tomorrow ${night_stop_time}" +%s`
    elif [[ ${now_date_time} -ge `date -d "${night_enable_time}" +%s` && ${now_date_time} -le `date -d "${night_stop_time}" +%s` && `date -d "${night_stop_time}" +%s` -ge `date -d "${night_enable_time}" +%s` ]]
    then
        night_enable_time=`date -d "${night_enable_time}" +%s`
        night_stop_time=`date -d "${night_stop_time}" +%s`
    fi
    echo "开启时间 ${night_enable_time}"
    echo "关闭时间 ${night_stop_time}"
    if [[ ${now_date_time} -ge ${night_enable_time} && ${now_date_time} -le ${night_stop_time} ]]
    then
        echo "深夜安静模式，CPU频率设置为最低"
        if [[ `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} ]]
        then
            for((i=0;i<=39;i++));
            do
                cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_normal_temp_limit_nomarl_freq}
            done
        fi
        if [[ ${fan_mode_get} -ne " 02" ]]
        then
            ipmi_sensor_cpu_upper 105
            ipmi_fans_mode 2 # 风扇模式设置为Optimal
        fi
        Debug_log
        exit 0
    fi
    echo "不在深夜时间，执行正常模式"
else
    echo "正常模式"
fi
#根据温度调节cpu频率和风扇策略
##正常温度频率调节
if [[  ${cpu2_temp_ipmi_get} -lt ${cpu_normal_temp_limit} && ${cpu1_temp_ipmi_get} -lt ${cpu_normal_temp_limit} && `${cpu_temp_sys_get}` -lt ${cpu_normal_temp_limit} ]]
then
    if [[ ${app_use_max_cpu} -ge ${app_use_max_cpu_limit} && `${cpu_max_freq_get}` -le ${cpu_super_temp_limit_max_freq} || ${cpu_idle} -le ${cpu_min_idle} && `${cpu_max_freq_get}` -le ${cpu_super_temp_limit_max_freq} ]]
        then
            echo "判断1"
            for((i=0;i<=39;i++));
            do
                cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq2} -u ${cpu_normal_temp_limit_max_freq}
            done
            ipmi_fans_mode 0 # 风扇模式设置为Standard
            ipmi_sensor_cpu_upper 110
    elif [[ ${app_use_max_cpu} -lt ${app_use_max_cpu_limit} && `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} ]]
    then
        if [[ ${cpu_idle} -gt ${cpu_min_idle} && `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} ]]
        then
            echo "判断2"
            echo "cpu温度正常，正在恢复设置"
            echo "cpu占用低，正在降低cpu性能"
            for((i=0;i<=39;i++));
            do
                cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_normal_temp_limit_nomarl_freq}
            done
            if [[ ${fan_mode_get} -ne " 02" ]]
            then
                ipmi_sensor_cpu_upper 105
                echo "CPU温度小于${cpu_normal_temp_limit}"
                ipmi_fans_mode 2 # 风扇模式设置为Optimal
            fi
        else
            echo "判断3"
            echo "cpu处于高性能模式"
            ipmi_fans_get
            echo "cpu温度正常"
        fi
    else
        echo "判断4"
        ipmi_fans_get
        echo "cpu温度正常"
    fi
##紧急温度频率调节
elif [[ ${cpu1_temp_ipmi_get} -ge ${cpu_super_temp_plus_limit} || ${cpu2_temp_ipmi_get} -ge ${cpu_super_temp_plus_limit} || `${cpu_temp_sys_get}` -ge ${cpu_super_temp_plus_limit} ]]
then
    if [[ `${cpu_max_freq_get}` -gt ${cpu_super_temp_limit_plus_max_freq} ]]
    then
        echo "判断5"
        echo "cpu温度超高,设置频率为${cpu_super_temp_limit_plus_max_freq}"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_super_temp_limit_plus_max_freq}
        done
        ipmi_sensor_cpu_upper 120
        if [[ ${fan_mode_get} -ne " 01" ]]
        then
            echo "CPU温度大于${cpu_super_temp_plus_limit}，风扇模式改为Full Speed"
            ipmitool raw 0x30 0x45 0x01 0x01
        else
            echo "无需修改，CPU温度大于${cpu_super_temp_plus_limit}，风扇模式为Full Speed"
        fi
    elif [[ `${cpu_max_freq_get}` -eq ${cpu_super_temp_limit_plus_max_freq} ]]
    then
        echo "判断8"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq} -u ${cpu_temp_limit_min_freq}
        done
    else
        echo "判断10"
        echo "cpu温度超高"
    fi
##高温温度频率调节
elif [[ ${cpu1_temp_ipmi_get} -ge ${cpu_super_temp_limit} || ${cpu2_temp_ipmi_get} -ge ${cpu_super_temp_limit} || `${cpu_temp_sys_get}` -ge ${cpu_super_temp_limit} ]]
then
    if [[ `${cpu_max_freq_get}` -gt ${cpu_super_temp_limit_max_freq} ]]
    then
        echo "判断6"
        echo "cpu温度超高,设置频率为${cpu_super_temp_limit_max_freq}"
        for((i=0;i<=39;i++));
        do
            cpufreq-set -c $i -g ${cpu_power_mode} -d ${cpu_temp_limit_min_freq2} -u ${cpu_super_temp_limit_max_freq}
        done
        ipmi_sensor_cpu_upper 110
        if [[ ${fan_mode_get} -ne " 01" ]]
        then
            echo "CPU温度大于${cpu_super_temp_limit}，风扇模式改为Standard Speed"
            ipmitool raw 0x30 0x45 0x01 0x00
        else
            echo "无需修改，CPU温度大于${cpu_super_temp_limit}，风扇模式为Standard Speed"
        fi
    else
        echo "判断9"
        echo "cpu温度过高"
    fi
else
    echo "判断7"
    ipmi_fans_get
    echo "cpu温度正常"
fi

#打印系统信息
Debug_log