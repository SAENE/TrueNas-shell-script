#!/bin/bash
#打印时间
date  +"%Y-%m-%d %H:%M.%S"

#环境变量
##设置可调参数
force_quiet=enable
ipmi_enable=enable

##夜晚模式开启以及关闭时间
night_quiet=enable
night_start_time=23:00
night_stop_time=06:00

##频率调节策略
cpu_power_mode="conservative" #conservative performance powersave ondemand
cpu_high_freq_power_mode="performance"

##温度设置
cpu_normal_temp_limit=80 #正常温度
cpu_super_temp_limit=90 #高温温度
cpu_super_temp_plus_limit=95 #紧急温度

##频率设置
cpu_normal_temp_limit_max_freq=`expr 3000 \* 1000` #正常温度最大频率
cpu_super_temp_limit_max_freq=`expr 2600 \* 1000` #高温温度频率
cpu_super_plus_temp_limit_max_freq=`expr 2000 \* 1000` #紧急温度频率
cpu_temp_limit_min_freq=`expr 1200 \* 1000` #最低频率

##CPU占用设置
cpu_min_idle=40 #cpu最小占空比
app_use_max_cpu_limit=150

#日志级别 debug-1, info-2, warn-3, error-4, always-5 
LOG_LEVEL=1
LOG_FILE="./cpu-freq.log"

# ————————————————————————————————————————————函数开始————————————————————————————————————————————

# ——————————————————————————————日志输出等级函数开始——————————————————————————————
#调试日志 
function log_debug(){ 
    content="[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 1  ] && echo -e ${content} >> ${LOG_FILE} && echo -e "\033[32m" ${content}  "\033[0m" 
} 
#信息日志 
function log_info(){ 
    content="[INFO] $(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 2  ] && echo -e ${content} >> ${LOG_FILE} && echo -e "\033[32m" ${content} "\033[0m" 
} 
#警告日志 
function log_warn(){ 
    content="[WARN] $(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 3  ] && echo -e ${content} >> ${LOG_FILE} && echo -e "\033[33m" ${content} "\033[0m" 
} 
#错误日志 
function log_err(){ 
    content="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 4  ] && echo -e ${content} >> ${LOG_FILE} && echo -e "\033[31m" ${content} "\033[0m" 
} 
#一直都会打印的日志 
function log_always(){ 
    content="[ALWAYS] $(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 5  ] && echo -e ${content} >> ${LOG_FILE} && echo -e  "\033[32m" ${content} "\033[0m" 
} 
# ——————————————————————————————日志输出等级函数结束——————————————————————————————

# 检测变量是否填写
function check_var_whether_null(){
    # 基础通用客观变量
    # 获取cpu数量
    cpu_count_list=$(cat /proc/cpuinfo | grep "physical id" | sort | uniq | sed 's/physical id.*\([0-9]\{1,2\}\)/\1/g')

    # 获取cpu核心数量
    cpu_core_count_list=$(cat /proc/cpuinfo | grep "processor" | sed 's/processor.*[^0-9]\([0-9]\{1,3\}\)/\1/g' | sort -n)

    if [ ! -n "${cpu_count_list}" ]
    then
        log_warn "获取不到CPU数量，真的是LINUX吗，默认参数为1"
        cpu_count_list=(1)
    fi

    if [ ! -n "${cpu_core_count_list}" ]
    then
        log_warn "获取不到CPU核心数量，真的是LINUX吗，退出"
        exit 1
    fi

    # 检测IPMI模式
    log_debug "检测IPMI模式是否设置"
    if [ ! -n "${ipmi_enable}" ]
    then
        ipmi_enable=false
        log_warn "ipmi_enablew未设置，默认为False"
    fi

    # 检测夜晚模式
    log_debug "检测夜晚模式是否设置及其是否设置正确"
    if [ ! -n "${night_quiet}" ]
    then
        night_quiet=false
        log_warn "night_quiet未设置，默认为False"
    fi
    # 检测夜晚时间
    if [ ! -n "${night_start_time}" ] || [ ! -n "${night_stop_time}" ]
    then
        night_quiet=false
        log_warn "夜晚模式时间未设置（night_start_time night_stop_time），关闭夜晚模式"
    fi

    # 检测CPU调频模式
    log_debug "检测CPU调频模式是否设置及其是否设置正确"
    cpu_power_mode_list=("conservative" "performance" "powersave" "ondemand" "userspace" "schedutil")
    for cpu_power_mode_name in ${cpu_power_mode_list}
    do
        if [ -n "${cpu_power_mode}" ] && [[ "${cpu_power_mode}" == "${cpu_power_mode_name}" ]]
        then
            cpu_power_mode_set_status=1
        else
            cpu_power_mode_set_status=0
        fi
        if [ -n "${cpu_high_freq_power_mode}" ] && [[ "${cpu_high_freq_power_mode}" == "${cpu_power_mode_name}" ]]
        then
            cpu_high_freq_power_mode_set_status=1
        else
            cpu_high_freq_power_mode_set_status=0
        fi
    done
    if [[ "${cpu_power_mode_set_status}" -ne 1 ]]
    then
        cpu_power_mode="conservative"
        log_warn "未设置CPU调频模式，默认为conservative"
    fi

    if [[ "${cpu_high_freq_power_mode_set_status}" -ne 1 ]]
    then
        cpu_high_freq_power_mode="performance"
        log_warn "未设置CPU高频率调频模式，默认为performance"
    fi

    log_debug "检测CPU频率限制是否设置"
    if [ ! -n "${cpu_normal_temp_limit_max_freq}" ]
    then
        cpu_normal_temp_limit_max_freq=${cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq}
        log_warn "未设置正常温度下最大频率，从系统设置获取"
    fi

    if [ ! -n "${cpu_temp_limit_min_freq}" ]
    then
        cpu_temp_limit_min_freq=${cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq}
        log_warn "未设置正常温度下最小频率，从系统设置获取"
    fi

    if [ ! -n "${cpu_super_temp_limit_max_freq}" ]
    then
        cpu_super_temp_limit_max_freq=`expr ${cpu_normal_temp_limit_max_freq} \* 70 \/ 100`
        log_warn "未设置高温度下最大频率，默认为最高频率的70%"
    fi

    if [ ! -n "${cpu_super_plus_temp_limit_max_freq}" ]
    then
        cpu_super_plus_temp_limit_max_freq=`expr ${cpu_super_plus_temp_limit_max_freq} \* 50 \/ 100`
        log_warn "未设置最高温度下最大频率，默认为最高频率的50%"
    fi

    if [ ! -n "${cpu_min_idle}" ]
    then
        cpu_min_idle=40
        log_warn "未设置CPU空占比，默认为40"
    fi

    if [ ! -n "${app_use_max_cpu_limit}" ]
    then
        app_use_max_cpu_limit=150
        log_warn "未设置软件高占比，默认为150"
    fi

    if [ ! -n "${LOG_LEVEL}" ]
    then
        LOG_LEVEL=2
        log_warn "未设置日志等级，默认为INFO（2）"
    fi

    if [ ! -n "${LOG_FILE}" ]
    then
        LOG_FILE=/dev/null
        log_warn "未设置日志路径，默认路径为/dev/null"
    fi
}


# 检测是否符合运行条件
function check_run_shell_condition(){
    check_file_status="success"
    check_cmd_status="success"
    ## 检测主要命令是否安装
    check_cmd_list=(top cpufreq-set sed grep cat sort date uniq head awk)

    for cmd_name in ${check_cmd_list}
    do
        if ! type "${cmd_name}" > /dev/null 2>&1;
        then
            log_err "请安装${cmd_name}"
            check_cmd_status="fail"
        fi
    done

    ## 检测主要文件是否有
    check_file_list=("/proc/cpuinfo" "/sys/devices/system/cpu/cpu0/cpufreq/")

    for file_name in ${check_file_list}
    do
        if [ ! -e "${file_name}" ]
        then
            log_err "不存在${file_name}文件夹，无法允许本程序"
            check_file_status="fail"
        fi
    done

    if ! type "ipmitool" > /dev/null 2>&1;
    then
        log_warn "请安装ipmitool"
        ipmi_enable=false
    fi

    if [[ "${check_file_status}" == "fail" || "${check_cmd_status}" == "fail" ]]
    then
        log_err "文件或者命令不存在，请查看日志获取更多信息"
        exit 1
    fi
}

# ——————————————————————————————IPMI设置开始——————————————————————————————
# 从IPMI中获取CPU信息
function cpu_info_get_from_ipmi(){
    if [[ "${ipmi_enable}" == "enable" ]]
    then
        log_info "使用IPMI获取CPU温度"
        cpu_temp_ipmi_get=0
        # 使用IPMI获取CPU温度，并对比值大小
        for cpu_name_num in ${cpu_count_list}
        do
            cpu_info[cpu_ipmi_get_temp${cpu_name_num}]=$(ipmitool sdr | grep CPU${cpu_name_num} | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g')
            if [[ "${cpu_temp_ipmi_get}" -lt "${cpu_info[cpu_ipmi_get_temp${cpu_name_num}]}" ]]
            then
                cpu_temp_ipmi_get=${cpu_info[cpu_ipmi_get_temp${cpu_name_num}]}
            fi
            log_debug ${cpu_info[cpu_ipmi_get_temp${cpu_name_num}]}
            # 获取风扇调频信息
        done
        fan_mode_get=$(ipmitool raw 0x30 0x45 0x00)
    else
        log_debug "关闭IPMI模式，相关参数设置为0"
        cpu_temp_ipmi_get=0
        fan_mode_get=0
    fi
}

# 设置风扇模式
function ipmi_fans_mode_set(){
    if [[ "${ipmi_enable}" == "enable" ]]
    then
        # 使用IPMI设置风扇模式
        # 00 为standard 01 为FUll 02为Optimal
        ipmitool raw 0x30 0x45 0x01 0x${1}

        # 使用IPMI获取风扇模式
        fan_mode_get=$(ipmitool raw 0x30 0x45 0x00)

        if [[ ${fan_mode_get} -eq " 02" ]]
        then
            log_info "风扇模式设置为Optimal Speed"
        fi
        if [[ ${fan_mode_get} -eq " 01" ]]
        then
            log_info "风扇模式设置为Full Speed"
        fi
        if [[ ${fan_mode_get} -eq " 00" ]]
        then
            log_info "风扇模式设置为Standard Speed"
        fi
    fi
}

# 获取风扇模式
function ipmi_fans_mode_get(){
    if [[ "${ipmi_enable}" == "enable" ]]
    then
        # 使用IPMI获取风扇模式
        fan_mode_get=$(ipmitool raw 0x30 0x45 0x00)

        # 判断风扇模式
        if [[ ${fan_mode_get} -eq " 02" ]]
        then
            log_info "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Optimal Speed"
        fi
        if [[ ${fan_mode_get} -eq " 01" ]]
        then
            log_info "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Full Speed"
        fi
        if [[ ${fan_mode_get} -eq " 00" ]]
        then
            log_info "无需修改，CPU温度小于${cpu_normal_temp_limit}，风扇模式为Standard Speed"
        fi
    fi
}

# 使用IPMI设置cpu温度上限
function ipmi_sensor_cpu_upper(){
    if [[ "${ipmi_enable}" == "enable" ]]
    then
        # 参数1为CPU警告温度
        ipmi_cpu_temp_set_warn=${1}

        # 参数2为CPU关键温度
        ipmi_cpu_temp_set_error=${2}

        # 参数2为CPUz致命温度
        ipmi_cpu_temp_set_fatal=${3}

        # 使用IPMI设置cpu温度上限
        for cpu_num in ${cpu_count_list}
        do
            cpu_num=$((${cpu_num} + 1))
            log_debug $(ipmitool sensor thresh "CPU${cpu_num} Temp" upper ${ipmi_cpu_temp_set_warn} ${ipmi_cpu_temp_set_error} ${ipmi_cpu_temp_set_fatal})
        done
    fi
}
# ——————————————————————————————IPMI设置结束——————————————————————————————

# 从系统中获取CPU信息
function cpu_info_get_from_sys(){
    cpu_max_freq_get=0
    cpu_min_freq_get=0
    cpu_now_freq_get=0
    # 获取频率信息
    for cpu_core_name_num in ${cpu_core_count_list}
    do
        # 获取cpu最高频率设置
        cpu_info[cpu_sys_max_freq${cpu_core_name_num}]=$(cat /sys/devices/system/cpu/cpu${cpu_core_name_num}/cpufreq/scaling_max_freq)

        # 获取cpu最低频率设置
        cpu_info[cpu_sys_min_freq${cpu_core_name_num}]=$(cat /sys/devices/system/cpu/cpu${cpu_core_name_num}/cpufreq/scaling_min_freq)

        # 获取cpu当前频率设置
        cpu_info[cpu_sys_cur_freq${cpu_core_name_num}]=$(cat /sys/devices/system/cpu/cpu${cpu_core_name_num}/cpufreq/scaling_cur_freq)

        if [[ "${cpu_max_freq_get}" -lt "${cpu_info[cpu_sys_max_freq${cpu_core_name_num}]}" ]]
        then
            cpu_max_freq_get=${cpu_info[cpu_sys_max_freq${cpu_core_name_num}]}
        fi

        if [[ "${cpu_min_freq_get}" -lt "${cpu_info[cpu_sys_min_freq${cpu_core_name_num}]}" ]]
        then
            cpu_min_freq_get=${cpu_info[cpu_sys_min_freq${cpu_core_name_num}]}
        fi

        if [[ "${cpu_now_freq_get}" -lt "${cpu_info[cpu_sys_cur_freq${cpu_core_name_num}]}" ]]
        then
            cpu_now_freq_get=${cpu_info[cpu_sys_cur_freq${cpu_core_name_num}]}
        fi
        log_debug "第${cpu_core_name_num}现在频率是${cpu_info[cpu_sys_cur_freq${cpu_core_name_num}]}"
    done

    log_debug "最大频率${cpu_max_freq_get} 最小频率${cpu_min_freq_get}"

    # 从系统中获取CPU温度，并取得最大值
    cpu_temp_sys_get=$[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]

    if [[ ${cpu_temp_sys_get} -lt $[$(cat /sys/class/thermal/thermal_zone1/temp)/1000] ]]
    then
        cpu_temp_sys_get=$[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]
    fi

    # 获取CPU占空比获取
    cpu_idle=$(top -bcn 1 -w 200 | grep '%Cpu(s)' | sed 's/.*ni,//g' | sed 's/\..*id,.*//g' | awk -F'[" "%]+' '{print $2}' | sed 's/root//g' | sed -n '1p')
    
    # 获取软件高占用
    app_use_max_cpu=$(top -bcn 1 -w 200 | sed '/\/usr\/bin\/qemu/d' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}')

    #监测最大cpu占用应用数值是否为0
    if [[ ${app_use_max_cpu} -eq 0 ]]
    then
        app_use_max_cpu=$(top -bcn 1 -w 200 | sed '/\/usr\/bin\/qemu/d' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}')
    fi

    log_debug "CPU占空比为${cpu_idle}，软件最大占用${app_use_max_cpu}"
}

# 输出系统信息
function Debug_log(){
    log_debug "最大cpu占用应用${app_use_max_cpu}"
    log_debug "cpu空占比 ${cpu_idle}%"
    log_debug "cpu最大频率${cpu_max_freq_get}"
    log_debug "cpu当前频率`cat /proc/cpuinfo | grep MHz | tail -n1` "
    log_debug "运行时cpu1温度${cpu1_temp_ipmi_get}"
    log_debug "运行时cpu2温度${cpu2_temp_ipmi_get}"
    log_debug "系统温度：$[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]°"
    log_debug "当前运行前8的程序"
    log_debug `top -bcn 1 -w 200  | sed -n '7,15p'`
    log_debug "\n"
}

# 设置CPU频率
function cpu_freq_set(){
    # 参数1为模式
    cpu_power_freq_mode=${1}
    # 参数2为频率最高
    cpu_high_freq=${2}
    # 参数3为频率最低
    cpu_low_freq=${3}
    # 设置CPU频率
    for core_num in ${core_count}
    do
        log_debug $(cpufreq-set -c ${core_num} -g ${cpu_power_freq_mode} -d ${cpu_low_freq} -u ${cpu_high_freq})
    done
    
}

# 修正时间
function time_correction(){
    # 获取当前时间
    now_date_time=$(date +%s)
    # 参数1为开启时间
    night_enable_time=${1}
    # 参数2为关闭时间
    night_stop_time=${2}
    # 判断正确与否
    if [[ ${now_date_time} -ge $(date -d "${night_enable_time}" +%s) && ${now_date_time} -ge $(date -d "${night_stop_time}" +%s) ]]
    then
        night_enable_time=$(date -d "yesterday ${night_enable_time}" +%s)
        night_stop_time=$(date -d "tomorrow ${night_stop_time}" +%s)
    elif [[ ${now_date_time} -le  $(date -d "${night_enable_time}" +%s) && ${now_date_time} -ge $(date -d "${night_stop_time}" +%s) ]]
    then
        night_enable_time=$(date -d "${night_enable_time}" +%s)
        night_stop_time=$(date -d "tomorrow ${night_stop_time}" +%s)
    elif [[ ${now_date_time} -le  $(date -d "${night_enable_time}" +%s) && ${now_date_time} -le $(date -d "${night_stop_time}" +%s) ]]
    then
        night_enable_time=$(date -d "yesterday ${night_enable_time}" +%s)
        night_stop_time=$(date -d "${night_stop_time}" +%s)
    elif [[ ${now_date_time} -ge $(date -d "${night_enable_time}" +%s) && ${now_date_time} -le $(date -d "${night_stop_time}" +%s) && $(date -d "${night_stop_time}" +%s) -lt $(date -d "${night_enable_time}" +%s) ]]
    then
        night_enable_time=$(date -d "${night_enable_time}" +%s)
        night_stop_time=$(date -d "tomorrow ${night_stop_time}" +%s)
    elif [[ ${now_date_time} -ge $(date -d "${night_enable_time}" +%s) && ${now_date_time} -le $(date -d "${night_stop_time}" +%s) && $(date -d "${night_stop_time}" +%s) -ge $(date -d "${night_enable_time}" +%s) ]]
    then
        night_enable_time=$(date -d "${night_enable_time}" +%s)
        night_stop_time=$(date -d "${night_stop_time}" +%s)
    fi
    log_debug "夜晚模式开启时间校正为${night_enable_time}\n夜晚模式关闭时间校正为${night_stop_time}"
}

# 对比IPMI和系统获取温度值
function CPU_INFO_COMPARED(){
    if [[ "${cpu_temp_sys_get}" -lt "${cpu_temp_ipmi_get}" ]]
    then
        cpu_temp_high_get=${cpu_temp_ipmi_get}
    else
        cpu_temp_high_get=${cpu_temp_sys_get}
    fi
}

# ————————————————————————————————————————————函数结束————————————————————————————————————————————

log_info "检测变量是否填写，变量初始化中"
check_var_whether_null
log_debug "变量初始化完成"
log_info "检测是否符合运行条件"
check_run_shell_condition
log_debug "检测完成"
log_info "开始获取CPU信息"
cpu_info_get_from_sys
cpu_info_get_from_ipmi
log_debug "获取完成"
log_info "开始对比CPU值"
CPU_INFO_COMPARED
log_debug "对比完毕"

# ————————————————————————————————————————————开始运行————————————————————————————————————————————
log_info "开始运行"
# ——————————————————————————————安静及夜晚模式——————————————————————————————
# 夜晚模式以及强制模式
if [[ "${force_quiet}" == "enable" ]]
then
    log_info "检测到强制安静模式已开启"
    # 将频率设置最低
    if [[ "${cpu_max_freq_get}" -gt "${cpu_temp_limit_min_freq}" ]]
    then
        log_info "当前CPU频率高，正在设置为最低"
        cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
    fi
    # 设置风扇最低转速
    if [[ "${fan_mode_get}" -ne "02" ]]
    then
        log_info "设置风扇最低转速"
        ipmi_fans_mode_set 02
    fi
    Debug_log
    exit 0
elif [[ "${night_quiet}" == "enable" ]]
then
    logo_debug "正在修正时间"
    time_correction ${night_start_time} ${night_stop_time}
    if [[ "${now_date_time}" -ge "${night_enable_time}" && "${now_date_time}" -le "${night_stop_time}" ]]
    then
        log_info "检测到已深夜"
        if [[ "${cpu_max_freq_get}" -gt "${cpu_temp_limit_min_freq}" ]]
        then
            log_info "当前CPU频率高，正在设置为最低"
            cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
        fi
        # 设置风扇最低转速
        if [[ "${fan_mode_get}" -ne "02" ]]
        then
            log_info "设置风扇最低转速，警告温度降低"
            ipmi_sensor_cpu_upper 105 105 110
            ipmi_fans_mode_set 02
        fi
        Debug_log
        exit 0
    fi
    log_info "不在深夜时间，执行正常模式"
else
    log_info "正常模式"
fi
# ——————————————————————————————安静及夜晚模式结束——————————————————————————————


# ——————————————————————————————正常模式——————————————————————————————
#根据温度调节cpu频率和风扇策略
##正常温度频率调节
# 如果温度低于正常温度限制，则开始下一步
if [[ "${cpu_temp_high_get}" -lt "${cpu_normal_temp_limit}" ]]
then
    # 如果空占比低或者应用占CPU高，频率低，则提高频率
    if [[ "${app_use_max_cpu}" -ge "${app_use_max_cpu_limit}" && "${cpu_max_freq_get}" -le "${cpu_super_temp_limit_max_freq}" || "${cpu_idle}" -le "${cpu_min_idle}" && "${cpu_max_freq_get}" -le "${cpu_super_temp_limit_max_freq}" ]]
        then
            log_info "提高频率，"
            cpu_freq_set ${cpu_high_freq_power_mode} ${cpu_normal_temp_limit_max_freq} ${cpu_temp_limit_min_freq}
            ipmi_fans_mode_set 00 # 风扇模式设置为Standard
            ipmi_sensor_cpu_upper 110 110 115
    # 如果进入高温或者紧急模式，并且空占比高或者应用占CPU低，则提高频率
    elif [[ "${app_use_max_cpu}" -lt "${app_use_max_cpu_limit}" && "${cpu_max_freq_get}" -gt "${cpu_temp_limit_min_freq}" || "${cpu_idle}" -gt "${cpu_min_idle}" && `${cpu_max_freq_get}` -gt ${cpu_normal_temp_limit_nomarl_freq} ]]
    then
        log_info "cpu温度正常，正在恢复设置"
        log_info "cpu占用低，正在降低cpu性能"
        cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
        if [[ "${fan_mode_get}" -ne "02" ]]
        then
            log_info "降低风扇转速"
            ipmi_sensor_cpu_upper 105 105 110
            ipmi_fans_mode_set 02
        fi
    else
        ipmi_fans_get
    fi
##紧急温度频率调节
elif [[ "${cpu_temp_high_get}" -ge "${cpu_super_temp_plus_limit}" ]]
then
    if [[ "${cpu_max_freq_get}" -gt "${cpu_super_plus_temp_limit_max_freq}" ]]
    then
        log_info "cpu温度超高,设置频率为${cpu_super_plus_temp_limit_max_freq}"
        cpu_freq_set ${cpu_power_mode} ${cpu_super_plus_temp_limit_max_freq} ${cpu_temp_limit_min_freq}
        ipmi_sensor_cpu_upper 120 120 125
        if [[ ${fan_mode_get} -ne " 01" ]]
        then
            log_info "提高风扇转速"
            ipmi_fans_mode_set 01
        else
            log_info "无需修改，CPU温度大于${cpu_super_temp_plus_limit}，风扇模式为Full Speed"
        fi
    elif [[ "${cpu_max_freq_get}" -eq "${cpu_super_plus_temp_limit_max_freq}" ]]
    then
        log_info "温度太高，频率设置为最低"
        cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
        ipmi_sensor_cpu_upper 120 120 125
        ipmi_fans_mode_set 01
    fi
##高温温度频率调节
elif [[ "${cpu_temp_high_get}" -ge "${cpu_super_temp_limit}" ]]
then
    if [[ "${cpu_max_freq_get}" -gt "${cpu_super_temp_limit_max_freq}" ]]
    then
        log_info "cpu温度超高,设置频率为${cpu_super_temp_limit_max_freq}"
        cpu_freq_set ${cpu_power_mode} ${cpu_super_temp_limit_max_freq} ${cpu_temp_limit_min_freq}
        ipmi_sensor_cpu_upper 110 110 115
        if [[ "${fan_mode_get}" -ne "00" ]]
        then
            log_info "CPU温度大于${cpu_super_temp_limit}，风扇模式改为Standard Speed"
            ipmi_fans_mode_set 00
        else
            log_info "无需修改，CPU温度大于${cpu_super_temp_limit}，风扇模式为Standard Speed"
        fi
    fi
fi

#打印信息
Debug_log