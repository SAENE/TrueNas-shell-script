#!/bin/bash
# 打印时间
date  +"%Y-%m-%d %H:%M.%S"

# 环境变量
# 设置可调参数
# 强制安静（最低频率运行）
force_quiet=false
# 是否启用IPMI
ipmi_enable=enable

# 夜晚模式开启以及关闭时间
# 是否启用夜晚模式
night_quiet=enable
# 开启时间
night_start_time=23:00
# 关闭时间
night_stop_time=06:00

# 频率调节策略
# conservative performance powersave ondemand
# 正常情况的调频模式
cpu_power_mode="conservative"
# 性能模式调频模式
cpu_high_freq_power_mode="performance"

# 温度设置
# 正常温度
cpu_normal_temp_limit=80
# 高温温度
cpu_super_temp_limit=90
# 紧急温度
cpu_super_temp_plus_limit=95

# 频率设置
# 正常温度最大频率
cpu_normal_temp_limit_max_freq=`expr 3000 \* 1000`
# 高温温度频率
cpu_super_temp_limit_max_freq=`expr 2600 \* 1000` 
# 紧急温度频率
cpu_super_plus_temp_limit_max_freq=`expr 2000 \* 1000`
# 最低频率
cpu_temp_limit_min_freq=`expr 1200 \* 1000`

# CPU占用设置
# cpu最小占空比（数值越小，表示CPU越忙 1-100）
cpu_min_idle=40
# 软件占用率（数值越大，软件占用越高）
app_use_max_cpu_limit=150

# 日志级别 debug-1, info-2, warn-3, error-4, always-5 
LOG_LEVEL=1
# 日志存储位置
LOG_FILE="/dev/null"



# ————————————————————————————————————————————函数开始————————————————————————————————————————————

# ——————————————————————————————日志输出等级函数开始——————————————————————————————
#调试日志 
function log_debug(){ 
    content="$(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 1  ] && echo -e "[ DEBUG ] " ${content} >> ${LOG_FILE} && echo -e "\033[46;37m[DEBUG]\033[0m" "\033[36m" ${content}  "\033[0m" 
} 
#信息日志 
function log_info(){ 
    content="$(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 2  ] && echo -e "[ INFO ] " ${content} >> ${LOG_FILE} && echo -e "\033[42;37m[INFO]\033[0m" "\033[32m" ${content} "\033[0m" 
} 
#警告日志 
function log_warn(){ 
    content="$(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 3  ] && echo -e "[ WARN ] " ${content} >> ${LOG_FILE} && echo -e "\033[43;37m[WARN]\033[0m" "\033[33m" ${content} "\033[0m" 
} 
#错误日志 
function log_err(){ 
    content="$(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 4  ] && echo -e "[ ERROR ] " ${content} >> ${LOG_FILE} && echo -e "\033[41;37m[ERROR]\033[0m" "\033[31m" ${content} "\033[0m" 
} 
#一直都会打印的日志 
function log_always(){ 
    content="$(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 5  ] && echo -e "[ ALWAYS ] " ${content} >> ${LOG_FILE} && echo -e "\033[45;37m[ALWAYS]\033[0m" "\033[35m" ${content} "\033[0m" 
} 
function log_ok(){ 
    content="$(date '+%Y-%m-%d %H:%M:%S') $@" 
    [ ${LOG_LEVEL} -le 5  ] && echo -e "[ OK ] " ${content} >> ${LOG_FILE} && echo -e "\033[32m[ OK ] \033[0m" ${content}
} 
# ——————————————————————————————日志输出等级函数结束——————————————————————————————


# ——————————————————————————————检测变量是否填写——————————————————————————————
function check_var_whether_null(){
    # 检测日志等级设置
    log_debug "检测日志等级设置"
    if [ ! -n "${LOG_LEVEL}" ];then
        LOG_LEVEL=2
        log_warn "未设置日志等级，默认为INFO（2）"
    fi
    log_ok "检测日志等级设置完成"
    # 检测日志输出路径设置
    log_debug "日志输出路径设置"
    if [ ! -n "${LOG_FILE}" ];then
        LOG_FILE=/dev/null
        log_warn "未设置日志路径，默认路径为/dev/null"
    fi
    log_ok "日志输出路径设置完成"

    # 获取CPU相关变量
    log_debug "正在获取CPU相关变量"
    # 获取cpu数量
    cpu_count_list=$(cat /proc/cpuinfo | grep "physical id" | sort | uniq | sed 's/physical id.*\([0-9]\{1,2\}\)/\1/g')
    log_debug "CPU数量为：${cpu_count_list}"
    # 获取cpu核心数量
    cpu_core_count_list=$(cat /proc/cpuinfo | grep "processor" | sed 's/processor.*[^0-9]\([0-9]\{1,3\}\)/\1/g' | sort -n)
    log_debug "CPU核心数量为：${cpu_core_count_list}"
    # 检测CPU数量参数是否为空
    log_debug "检测CPU数量参数是否为空"
    if [ ! -n "${cpu_count_list}" ];then
        log_warn "获取不到CPU数量（哎妈呀，这给我干哪来了，这还是LINUX吗）默认参数为1"
        cpu_count_list=(1)
    fi
    log_ok "检测CPU数量参数完成"
    # 检测CPU核心数量参数是否为空
    log_debug "检测CPU核心数量参数是否为空"
    if [ ! -n "${cpu_core_count_list}" ];then
        log_err "获取不到CPU核心数量（哎妈呀，这给我干哪来了，这还是LINUX吗）退出"
        exit 1
    fi
    log_ok "检测CPU核心数量参数完成"
    log_ok "CPU相关变量获取完成"

    # 检测IPMI模式是否开启
    log_debug "检测IPMI模式是否设置"
    if [ ! -n "${ipmi_enable}" ] && [[ "${ipmi_enable}" == "true" || "${ipmi_enable}" == "false" ]];then
        log_warn "ipmi_enablew未设置，默认为False"
        ipmi_enable=false
    fi
    log_ok "检测IPMI模式完成"

    # 检测夜晚模式
    log_debug "检测夜晚模式是否设置及其是否设置正确"
    if [ ! -n "${night_quiet}" ] && [[ "${night_quiet}" == "true" || "${night_quiet}" == "false" ]];then
        log_warn "night_quiet未设置，默认为False"
        night_quiet=false
    fi
    # 检测夜晚时间
    if [ ! -n "${night_start_time}" ] || [ ! -n "${night_stop_time}" ];then
        log_warn "夜晚模式时间未设置（night_start_time night_stop_time），关闭夜晚模式"
        night_quiet=false
    fi
    log_ok "检测夜晚模式完成"

    # 检测CPU调频模式
    log_debug "检测CPU调频模式是否设置及其是否设置正确"
    # CPU调频模式列表
    cpu_power_mode_list=("conservative" "performance" "powersave" "ondemand" "userspace" "schedutil")
    # 状态参数初始化
    cpu_power_mode_set_status=0
    cpu_high_freq_power_mode_set_status=0
    # 检测CPU调频模式循环
    for cpu_power_mode_name in ${cpu_power_mode_list[@]};do
        log_debug "现在的CPU调频模式名称是 ${cpu_power_mode_name}"
        # 检测是否为空和参数是否正确
        if [ -n "${cpu_power_mode}" ] && [[ "${cpu_power_mode}" == "${cpu_power_mode_name}" ]];then
            cpu_power_mode_set_status=1
        fi
        # 检测是否为空和参数是否正确
        if [ -n "${cpu_high_freq_power_mode}" ] && [[ "${cpu_high_freq_power_mode}" == "${cpu_power_mode_name}" ]];then
            cpu_high_freq_power_mode_set_status=1
        fi
    done
    # 判断检测状态
    if [[ "${cpu_power_mode_set_status}" -ne 1 ]];then
        log_warn "未设置CPU调频模式，默认为conservative"
        cpu_power_mode="conservative"
    fi
    # 判断检测状态
    if [[ "${cpu_high_freq_power_mode_set_status}" -ne 1 ]];then
        log_warn "未设置CPU高频率调频模式，默认为performance"
        cpu_high_freq_power_mode="performance"
    fi
    log_ok "检测CPU调频模式完成"

    # 检测CPU频率限制
    log_debug "检测CPU频率限制是否设置"
    # 检测正常温度下最大频率
    if [ ! -n "${cpu_normal_temp_limit_max_freq}" ];then
        log_warn "未设置正常温度下最大频率，从系统设置获取"
        cpu_normal_temp_limit_max_freq=${cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq}
    fi
    # 检测正常温度下最小频率
    if [ ! -n "${cpu_temp_limit_min_freq}" ];then
        log_warn "未设置正常温度下最小频率，从系统设置获取"
        cpu_temp_limit_min_freq=${cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq}
    fi
    # 检测高温度下最大频率
    if [ ! -n "${cpu_super_temp_limit_max_freq}" ];then
        log_warn "未设置高温度下最大频率，默认为最高频率的70%"
        cpu_super_temp_limit_max_freq=`expr ${cpu_normal_temp_limit_max_freq} \* 70 \/ 100`
    fi
    # 检测最高温度下最大频率
    if [ ! -n "${cpu_super_plus_temp_limit_max_freq}" ];then
        cpu_super_plus_temp_limit_max_freq=`expr ${cpu_super_plus_temp_limit_max_freq} \* 50 \/ 100`
        log_warn "未设置最高温度下最大频率，默认为最高频率的50%"
    fi
    log_ok "检测CPU频率限制设置完成"

    # 检测CPU空占比
    log_debug "检测CPU空占比设置"
    if [ ! -n "${cpu_min_idle}" ];then
        cpu_min_idle=40
        log_warn "未设置CPU空占比，默认为40"
    fi
    log_ok "检测CPU空占比设置完成"

    # 检测软件CPU占比
    log_debug "检测软件CPU占比设置"
    if [ ! -n "${app_use_max_cpu_limit}" ];then
        app_use_max_cpu_limit=150
        log_warn "未设置软件高占比，默认为150"
    fi
    log_ok "检测软件CPU占比设置完成"
}
# ——————————————————————————————检测变量函数结束——————————————————————————————


# ——————————————————————————————检测是否符合运行条件——————————————————————————————
# 检测是否符合运行条件
function check_run_shell_condition(){
    # 检测是否安装IPMItool
    log_debug "检测是否安装IPMItool"
    if ! type "ipmitool" > /dev/null 2>&1 && [[ "${ipmi_enable}" == "true" ]];then
        log_warn "请安装ipmitool"
        ipmi_enable=false
    fi
    log_ok "IPMITOOL安装检测完成"

    log_debug "正在检查是否缺少运行所需要命令"
    # 状态参数初始化
    check_file_status="success"
    check_cmd_status="success"
    # 检测主要命令是否安装
    check_cmd_list=(top cpufreq-set sed grep cat sort date uniq head awk sensors)
    # 检测主要命令循环
    for cmd_name in ${check_cmd_list[@]};do
        log_debug "正在检测${cmd_name}命令"
        if ! type "${cmd_name}" > /dev/null 2>&1;then
            log_err "请安装${cmd_name}"
            check_cmd_status="fail"
        fi
    done

    log_debug "正在检查是否缺少运行所需要文件"
    # 检测主要文件是否有
    check_file_list=("/proc/cpuinfo" "/sys/devices/system/cpu/cpu0/cpufreq/")
    # 检测主要文件循环
    for file_name in ${check_file_list[@]};do
        log_debug "正在检测${file_name}文件"
        if [ ! -e "${file_name}" ];then
            log_err "不存在${file_name}文件夹，无法允许本程序"
            check_file_status="fail"
        fi
    done

    # 判断文件或命令状态
    if [[ "${check_file_status}" == "fail" || "${check_cmd_status}" == "fail" ]];then
        log_err "文件或者命令不存在，请查看日志获取更多信息"
        exit 1
    fi
    log_ok "运行所需命令和文件检测完成"
}
# ——————————————————————————————检测运行条件函数结束——————————————————————————————


# ——————————————————————————————IPMI设置开始——————————————————————————————
# 从IPMI中获取CPU信息
function cpu_info_get_from_ipmi(){
    # 检测是否开启IPMI模式
    if [[ "${ipmi_enable}" == "enable" ]];then
        log_debug "正在使用IPMI获取CPU温度"
        # 参数初始化
        cpu_temp_ipmi_get=0
        # 使用IPMI获取CPU温度，并对比值大小
        for cpu_name_num in ${cpu_count_list[@]};do
            # 修正参数
            cpu_name_num=`expr + 1`
            # 获取CPUx温度
            cpu_info_ipmi_get_temp[${cpu_name_num}]=$(ipmitool sdr | grep CPU${cpu_name_num} | grep Temp | sed 's/[1-2]//' | sed 's/| ok//g' | sed 's/CPU Temp.*| //g' | sed 's/ degrees C//g')
            # 判读存储值是否低于当前值
            if [[ "${cpu_temp_ipmi_get}" -lt "${cpu_info[cpu_ipmi_get_temp${cpu_name_num}]}" ]];then
                cpu_temp_ipmi_get=${cpu_info_ipmi_get_temp[${cpu_name_num}]}
            fi
            log_debug "CPU${cpu_name_num}的温度是${cpu_info_ipmi_get_temp[${cpu_name_num}]}"
        done

        # 获取风扇调频信息
        log_debug "正在使用IPMI获取风扇模式"
        fan_mode_get=$(ipmitool raw 0x30 0x45 0x00 | egrep -o '[0-9]{2}')
        log_ok "IPMI获取到CPU温度和风扇模式"
    else
        log_info "关闭IPMI模式，相关参数设置为0"
        # 初始化变量
        cpu_temp_ipmi_get=0
        fan_mode_get=00
    fi
}

# 设置风扇模式
function ipmi_fans_mode_set(){
    # 检测是否开启IPMI模式
    if [[ "${ipmi_enable}" == "enable" ]];then
        # 使用IPMI设置风扇模式
        # 00 为standard 01 为FUll 02为Optimal
        ipmitool raw 0x30 0x45 0x01 0x${1}

        # 判断风扇模式
        case ${1} in
            "00")
                log_ok "风扇模式设置为Standard Speed"
                ;;
            "01")
                log_ok "风扇模式设置为Full Speed"
                ;;
            "02")
                log_ok "风扇模式设置为Optimal Speed"
                ;;
        esac
    fi
}

function ipmi_fans_mode_echo(){
    if [[ "${ipmi_enable}" == "enable" ]];then
        case ${fan_mode_get} in
            "00")
                log_info "风扇模式为Standard Speed"
                ;;
            "01")
                log_info "风扇模式为Full Speed"
                ;;
            "02")
                log_info "风扇模式为Optimal Speed"
                ;;
        esac

    fi
}

# 获取风扇模式
function ipmi_fans_mode_get(){
    # 检测是否开启IPMI模式
    if [[ "${ipmi_enable}" == "enable" ]];then
        # 使用IPMI获取风扇模式
        fan_mode_get=$(ipmitool raw 0x30 0x45 0x00 | egrep -o '[0-9]{2}')
        ipmi_fans_mode_echo
    fi
}

# 使用IPMI设置cpu温度上限
function ipmi_sensor_cpu_upper(){
    # 检测是否开启IPMI模式
    if [[ "${ipmi_enable}" == "enable" ]];then
        log_debug "IPMI设置CPU温度墙"
        # 参数1为CPU警告温度
        ipmi_cpu_temp_set_warn=${1}

        # 参数2为CPU关键温度
        ipmi_cpu_temp_set_error=${2}

        # 参数2为CPUz致命温度
        ipmi_cpu_temp_set_fatal=${3}

        # 使用IPMI设置cpu温度上限
        for cpu_num in ${cpu_count_list[@]};do
            # 修正参数
            cpu_num=$((${cpu_num} + 1))
            log_debug "现在设置CPU为CPU${cpu_num}"
            # ipmitool设置
            ipmitool sensor thresh "CPU${cpu_num} Temp" upper ${ipmi_cpu_temp_set_warn} ${ipmi_cpu_temp_set_error} ${ipmi_cpu_temp_set_fatal}
        done
        log_ok "IPMI设置CPU温度墙完成"
    fi
}
# ——————————————————————————————IPMI设置结束——————————————————————————————


# ——————————————————————————————CPU信息获取——————————————————————————————
function cpu_info_get_from_sys(){
    # 获取CPU频率
    # 初始化参数
    log_debug "正在从文件中获取CPU频率"
    cpu_max_freq_get=0
    cpu_min_freq_get=0
    cpu_now_freq_get=0
    # 获取频率信息
    for cpu_core_name_num in ${cpu_core_count_list[@]};do
        # 获取cpu最高频率设置
        cpu_info_max[${cpu_core_name_num}]=$(cat /sys/devices/system/cpu/cpu${cpu_core_name_num}/cpufreq/scaling_max_freq)

        # 获取cpu最低频率设置
        cpu_info_min[${cpu_core_name_num}]=$(cat /sys/devices/system/cpu/cpu${cpu_core_name_num}/cpufreq/scaling_min_freq)

        # 获取cpu当前频率设置
        cpu_info_cur[${cpu_core_name_num}]=$(cat /sys/devices/system/cpu/cpu${cpu_core_name_num}/cpufreq/scaling_cur_freq)

        # 判读最大频率是否小于当前值
        if [[ "${cpu_max_freq_get}" -lt "${cpu_info_max[${cpu_core_name_num}]}" ]];then
            cpu_max_freq_get=${cpu_info_max[${cpu_core_name_num}]}
        fi
        # 判读最小频率是否小于当前值
        if [[ "${cpu_min_freq_get}" -lt "${cpu_info_min[${cpu_core_name_num}]}" ]];then
            cpu_min_freq_get=${cpu_info_min[${cpu_core_name_num}]}
        fi
        # 判读现在频率是否小于当前值
        if [[ "${cpu_now_freq_get}" -lt "${cpu_info_cur[${cpu_core_name_num}]}" ]];then
            cpu_now_freq_get=${cpu_info_cur[${cpu_core_name_num}]}
        fi
        log_debug "第${cpu_core_name_num}现在最大频率是${cpu_info_max[${cpu_core_name_num}]}"
        log_debug "第${cpu_core_name_num}现在最小频率是${cpu_info_min[${cpu_core_name_num}]}"
        log_debug "第${cpu_core_name_num}现在频率是${cpu_info_cur[${cpu_core_name_num}]}"
        log_debug "\n"
    done
    log_ok "CPU频率获取完毕"
    log_debug "最大频率${cpu_max_freq_get} 最小频率${cpu_min_freq_get}"

    # 从系统中获取CPU温度，并取得最大值
    log_debug "正在从文件中获取CPU最高温度"
    cpu_temp_sys_get=0
    cpu_temp_sensors_get=0
    # 检测循环
    for cpu_name_num in ${cpu_count_list[@]};do
        # 获取cpu温度
        cpu_info_temp_sys[${cpu_name_num}]=$[$(cat /sys/class/thermal/thermal_zone${cpu_name_num}/temp)/1000]
        # 判读是否小于当前值
        if [[ "${cpu_temp_sys_get}" -lt "${cpu_info_temp_sys[${cpu_name_num}]}" ]];then
            cpu_temp_sys_get=${cpu_info_temp_sys[${cpu_name_num}]}
        fi
        log_debug "从文件获取，第CPU${cpu_name_num}的综合温度为${cpu_info_temp_sys[${cpu_name_num}]}"

        # 使用sensors获取CPU温度
        cpu_info_temp_sensors[${cpu_name_num}]=$(sensors | grep "Package id 0" | sed 's/.*id [0-9]. * +\([0-9]\{2\}\)\.[0-9].*/\1/g')
        # 判读是否小于当前值
        if [[ "${cpu_temp_sensors_get}" -lt "cpu_info_temp_sensors[${cpu_name_num}]" ]];then
            cpu_temp_sensors_get=${cpu_info_temp_sensors[${cpu_name_num}]}
        fi
        log_debug "通过sensors命令，第CPU${cpu_name_num}的综合温度为${cpu_info_temp_sensors[${cpu_name_num}]}"
    done
    # 判断sensors和sys文件获取值哪个大
    if [[ "${cpu_temp_sys_get}" -lt "${cpu_temp_sensors_get}" ]];then
        cpu_temp_sys_get=${cpu_temp_sensors_get}
    fi
    log_ok "CPU最高温度获取完毕"
    log_debug "CPU最高温度为${cpu_temp_sys_get}"

    # 获取CPU占空比获取
    log_debug "正在获取CPU空占比"
    cpu_idle=$(top -bcn 1 -w 200 | grep '%Cpu(s)' | sed 's/.*ni,//g' | sed 's/\..*id,.*//g' | awk -F'[" "%]+' '{print $2}' | sed 's/root//g' | sed -n '1p')
    # 获取软件高占用
    log_debug "正在获取软件高占比"
    app_use_max_cpu=$(top -bcn 1 -w 200 | sed '/\/usr\/bin\/qemu/d' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}')
    #监测最大cpu占用应用数值是否为0
    if [[ ${app_use_max_cpu} -eq 0 ]];then
        app_use_max_cpu=$(top -bcn 1 -w 200 | sed '/\/usr\/bin\/qemu/d' | head -n 20 | sed -n "8p"  | awk {'print $9'} | awk -F '.' '{print $1}')
    fi
    log_ok "CPU空占比，软件高占比获取完毕"
    log_debug "CPU占空比为${cpu_idle}，软件最大占用${app_use_max_cpu}"
}
# ——————————————————————————————CPU信息获取函数结束——————————————————————————————


# ——————————————————————————————Debug信息——————————————————————————————
function Debug_log(){
    log_always "最大CPU占用应用${app_use_max_cpu}"
    log_always "CPU空占比 ${cpu_idle}%"
    log_always "CPU最大频率${cpu_max_freq_get}"
    log_always "CPU当前频率`cat /proc/cpuinfo | grep MHz | tail -n1` "
    if [[ "${ipmi_enable}" == "enable" ]];then
        log_always "IPMI运行时CPU1温度${cpu1_temp_ipmi_get}"
        log_always "IPMI运行时CPU2温度${cpu2_temp_ipmi_get}"
    fi
    log_always "系统温度：$[$(cat /sys/class/thermal/thermal_zone0/temp)/1000]°"
    log_always "sensors获取到的CPU温度为：${cpu_temp_sensors_get}"
    log_always "\n\n\n\n\n"
}
# ——————————————————————————————Debug信息函数结束——————————————————————————————


# ——————————————————————————————设置CPU频率——————————————————————————————
function cpu_freq_set(){
    log_debug "正在设置CPU频率"
    # 参数1为模式
    cpu_power_freq_mode=${1}
    # 参数2为频率最高
    cpu_high_freq=${2}
    # 参数3为频率最低
    cpu_low_freq=${3}

    log_info "最大频率设置为${cpu_high_freq}、最小频率设置为${cpu_low_freq}"
    # 设置CPU频率
    for core_num in ${cpu_core_count_list[@]};do
        log_debug "正在设置第${core_num}核"
        # cpufreq设置 核心 调频模式 频率最低值 频率最高值 
        cpufreq-set -c ${core_num} -g ${cpu_power_freq_mode} -d ${cpu_low_freq} -u ${cpu_high_freq}
    done
    log_ok "CPU频率设置完成"
}
# ——————————————————————————————设置CPU频率函数结束——————————————————————————————


# ——————————————————————————————时间修正——————————————————————————————
function time_correction(){
    log_debug "正在修正时间"
    # 获取当前时间
    now_date_time=$(date +%s)
    # 参数1为开启时间
    night_enable_time=${1}
    # 参数2为关闭时间
    night_stop_time=${2}
    # 判断正确与否
    if [[ ${now_date_time} -ge $(date -d "${night_enable_time}" +%s) && ${now_date_time} -ge $(date -d "${night_stop_time}" +%s) ]];then
        night_enable_time=$(date -d "yesterday ${night_enable_time}" +%s)
        night_stop_time=$(date -d "tomorrow ${night_stop_time}" +%s)
    elif [[ ${now_date_time} -le  $(date -d "${night_enable_time}" +%s) && ${now_date_time} -ge $(date -d "${night_stop_time}" +%s) ]];then
        night_enable_time=$(date -d "${night_enable_time}" +%s)
        night_stop_time=$(date -d "tomorrow ${night_stop_time}" +%s)
    elif [[ ${now_date_time} -le  $(date -d "${night_enable_time}" +%s) && ${now_date_time} -le $(date -d "${night_stop_time}" +%s) ]];then
        night_enable_time=$(date -d "yesterday ${night_enable_time}" +%s)
        night_stop_time=$(date -d "${night_stop_time}" +%s)
    elif [[ ${now_date_time} -ge $(date -d "${night_enable_time}" +%s) && ${now_date_time} -le $(date -d "${night_stop_time}" +%s) && $(date -d "${night_stop_time}" +%s) -lt $(date -d "${night_enable_time}" +%s) ]];then
        night_enable_time=$(date -d "${night_enable_time}" +%s)
        night_stop_time=$(date -d "tomorrow ${night_stop_time}" +%s)
    elif [[ ${now_date_time} -ge $(date -d "${night_enable_time}" +%s) && ${now_date_time} -le $(date -d "${night_stop_time}" +%s) && $(date -d "${night_stop_time}" +%s) -ge $(date -d "${night_enable_time}" +%s) ]];then
        night_enable_time=$(date -d "${night_enable_time}" +%s)
        night_stop_time=$(date -d "${night_stop_time}" +%s)
    fi
    log_ok "时间修正完毕"
    log_debug "现在时间是${now_date_time}"
    log_debug "夜晚模式开启时间校正为${night_enable_time}"
    log_debug "夜晚模式关闭时间校正为${night_stop_time}"
}
# ——————————————————————————————时间修正函数结束——————————————————————————————


# ——————————————————————————————IPMI和CPU温度对比——————————————————————————————
function CPU_INFO_COMPARED(){
    # 判断哪个值大
    if [[ "${cpu_temp_sys_get}" -lt "${cpu_temp_ipmi_get}" ]];then
        cpu_temp_high_get=${cpu_temp_ipmi_get}
    else
        cpu_temp_high_get=${cpu_temp_sys_get}
    fi
    log_ok "CPU温度值比较完毕"
    log_debug "CPU最高温度是${cpu_temp_high_get}"
}
# ——————————————————————————————IPMI和CPU温度对比函数结束——————————————————————————————
# ————————————————————————————————————————————函数结束————————————————————————————————————————————


# ————————————————————————————————————————————函数运行————————————————————————————————————————————
# 检测变量
log_always "———————————————检测变量是否填写，变量初始化中———————————————"
check_var_whether_null
log_always "———————————————变量初始化完成———————————————"
log_always "\n"
# 检测是否满足运行条件
log_always "———————————————检测是否符合运行条件———————————————"
check_run_shell_condition
log_always "———————————————运行条件检测完成———————————————"
log_always "\n"
# 获取CPU信息
log_always "———————————————开始获取CPU信息———————————————"
cpu_info_get_from_sys
cpu_info_get_from_ipmi
log_always "———————————————CPU信息获取完成———————————————"
log_always "\n"
# 对比IPMI和SYS获取参数
log_always "———————————————开始对比IPMI和SYS获取参数值———————————————"
CPU_INFO_COMPARED
log_always "———————————————对比完毕———————————————"
log_always "\n"
# ————————————————————————————————————————————函数运行完成————————————————————————————————————————————


# ————————————————————————————————————————————开始运行————————————————————————————————————————————
log_always "———————————————开始运行———————————————"
# ——————————————————————————————安静及夜晚模式——————————————————————————————
# 夜晚模式以及强制模式
# 检测是否开启安静模式
if [[ "${force_quiet}" == "enable" ]];then
    log_info "检测到强制安静模式已开启"
    # 将频率设置最低
    if [[ "${cpu_max_freq_get}" -gt "${cpu_temp_limit_min_freq}" ]];then
        log_info "当前CPU频率高，设置为最低"
        cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
    fi
    # 设置风扇最低转速
    if [[ "${fan_mode_get}" -ne "02" ]];then
        ipmi_fans_mode_set 02
        ipmi_sensor_cpu_upper 105 105 110
    fi
    # 打印Debug信息
    Debug_log
    # 退出
    exit 0
# 检测是否开启深夜模式
elif [[ "${night_quiet}" == "enable" ]];then
    # 修正时间 开始 结束
    time_correction ${night_start_time} ${night_stop_time}
    # 判断是否在深夜
    if [[ "${now_date_time}" -ge "${night_enable_time}" && "${now_date_time}" -le "${night_stop_time}" ]];then
        log_info "检测到已深夜"
        # 判断cpu最高频率是否高于设定最小频率
        if [[ "${cpu_max_freq_get}" -gt "${cpu_temp_limit_min_freq}" ]];then
            log_info "当前CPU频率高，设置为最低"
            # 设置CPU频率 模式 最小 最大
            cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
        fi
        # 判断风扇模式是不是op
        if [[ "${fan_mode_get}" -ne "02" ]];then
            ipmi_fans_mode_set 02
            ipmi_sensor_cpu_upper 105 105 110
        fi
        # 打印Debug信息
        Debug_log
        # 退出
        exit 0
    fi
    log_info "不在深夜时间，执行正常模式"
else
    log_info "执行正常模式"
fi
# ——————————————————————————————安静及夜晚模式结束——————————————————————————————


# ——————————————————————————————正常模式——————————————————————————————
#根据温度调节cpu频率和风扇策略
##正常温度频率调节
# 如果温度低于设置 正常温度 限定温度，则开始下一步
if [[ "${cpu_temp_high_get}" -lt "${cpu_normal_temp_limit}" ]];then
    # 如果频率低于高温温度频率，进入性能提高
    if [[ "${cpu_max_freq_get}" -le "${cpu_super_temp_limit_max_freq}" ]];then
        log_debug "CPU最大频率小于等于${cpu_super_temp_limit_max_freq}"
        # 如果软件占用比高或者CPU空占比低
        if [[ "${app_use_max_cpu}" -ge "${app_use_max_cpu_limit}" || "${cpu_idle}" -le "${cpu_min_idle}" ]];then
            log_info "有高占比应用 或者 CPU空占比低，提高CPU频率"
            # 设置CPU频率
            cpu_freq_set ${cpu_high_freq_power_mode} ${cpu_normal_temp_limit_max_freq} ${cpu_temp_limit_min_freq}
            # 判断风扇调频是否为Standard Speed模式
            if [[ "${fan_mode_get}" -ne "00" ]];then
                # IPMI风扇模式设置为Standard
                ipmi_fans_mode_set 00
                # IPMI提高CPU警告线
                ipmi_sensor_cpu_upper 110 110 115
            fi
        else
            log_info "无高占比 CPU空闲，最低频率运行"
            # 输出风扇模式
            ipmi_fans_mode_echo
        fi
    # 如果CPU频率高于最低频率，则开始下一步
    elif [[ "${cpu_max_freq_get}" -gt "${cpu_temp_limit_min_freq}" ]];then
        log_debug "CPU最大频率大于${cpu_temp_limit_min_freq}"
        # 软件占比低或者CPU空占比高
        if [[ "${app_use_max_cpu}" -lt "${app_use_max_cpu_limit}" && "${cpu_idle}" -gt "${cpu_min_idle}" ]];then
            log_info "无高占比应用 或者 CPU空闲，CPU温度正常，降低CPU频率"
            # 设置CPU频率 
            cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
            # 判断风扇调频是否为Optimal Speed模式
            if [[ "${fan_mode_get}" -ne "02" ]];then
                # IPMI风扇模式设置为Optimal
                ipmi_fans_mode_set 02
                # IPMI提高CPU警告线
                ipmi_sensor_cpu_upper 105 105 110
            fi
        else
            log_info "有软件占用高 CPU空占比低，最高频率运行"
            # 输出风扇模式
            ipmi_fans_mode_echo
        fi
    else
        log_info "有软件占用高 CPU空占比低，最高频率运行"
        # 输出风扇模式
        ipmi_fans_mode_echo
    fi
# 紧急温度频率调节
# 如果温度高于设置 紧急温度 限定温度，则开始下一步
elif [[ "${cpu_temp_high_get}" -ge "${cpu_super_temp_plus_limit}" ]];then
    # 如果频率高于紧急温度限制
    if [[ "${cpu_max_freq_get}" -gt "${cpu_super_plus_temp_limit_max_freq}" ]];then
        log_info "CPU温度太高，设置紧急温度频率"
        # 设置CPU频率
        cpu_freq_set ${cpu_power_mode} ${cpu_super_plus_temp_limit_max_freq} ${cpu_temp_limit_min_freq}
        # 判断风扇调频是否为Full Speed模式
        if [[ ${fan_mode_get} -ne " 01" ]];then
            # 设置风扇调频模式
            ipmi_fans_mode_set 01
            # IPMI提高CPU警告线
            ipmi_sensor_cpu_upper 120 120 125
        fi
    # 如果频率等于紧急温度限制
    elif [[ "${cpu_max_freq_get}" -eq "${cpu_super_plus_temp_limit_max_freq}" ]];then
        log_info "CPU温度持续高温，设置为最低频率"
        # 设置CPU频率为最低
        cpu_freq_set ${cpu_power_mode} ${cpu_temp_limit_min_freq} ${cpu_temp_limit_min_freq}
        # 判断风扇调频是否为Full Speed模式
        if [[ ${fan_mode_get} -ne " 01" ]];then
            # 设置风扇调频模式
            ipmi_fans_mode_set 01
            # IPMI提高CPU警告线
            ipmi_sensor_cpu_upper 120 120 125
        fi
    fi
# 高温温度频率调节
# 如果温度高于设置 高温温度 限定温度，则开始下一步
elif [[ "${cpu_temp_high_get}" -ge "${cpu_super_temp_limit}" ]];then
    # 如果频率高于 高温温度频率 限制
    if [[ "${cpu_max_freq_get}" -gt "${cpu_super_temp_limit_max_freq}" ]];then
        log_info "CPU温度高，设置为高温温度频率"
        # 设置CPU频率
        cpu_freq_set ${cpu_power_mode} ${cpu_super_temp_limit_max_freq} ${cpu_temp_limit_min_freq}
        if [[ "${fan_mode_get}" -ne "00" ]];then
            # 设置风扇调频模式
            ipmi_fans_mode_set 00
            # IPMI提高CPU警告线
            ipmi_sensor_cpu_upper 110 110 115
        fi
    else
        log_info "CPU温度高"
        ipmi_fans_mode_echo
    fi
fi
log_always "———————————————运行结束———————————————"
# ——————————————————————————————正常模式结束——————————————————————————————
#打印信息
Debug_log