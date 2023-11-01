#!/bin/bash
#备份目录
BACKUP_ROOT=/var/lib/mysql
BACKUP_FILEDIR=/home/docker/mariadb/bakup
#当前日期
DATE=$(date "+%Y%m%d%H%M")
DEL_DAY=31

#查询所有数据库
DATABASES=$(docker exec -i mariadb mariadb  -uroot -p -e "show databases" | grep -Ev "Database|sys|information_schema|performance_schema|mysql")
#循环数据库进行备份
echo $DATABASES
for db in $DATABASES
    do
    echo
    if [[ "${db}" =~ "+" ]] || [[ "${db}" =~ "|" ]];then
        echo "jump over ${db}"
    else
        echo ----------$BACKUP_FILEDIR/${db}_$DATE.sql.gz BEGIN----------
        docker exec -i mariadb  mariadb-dump -uroot -p --default-character-set=utf8 -q --lock-all-tables --flush-logs -E -R --triggers -B ${db} | gzip > $BACKUP_FILEDIR/${db}_$DATE.sql.gz
        echo ${db}
        echo ----------$BACKUP_FILEDIR/${db}_$DATE.sql.gz COMPLETE----------
        echo
    fi
done

cd ${BACKUP_FILEDIR}
# 遍历备份目录下的日期目录
LIST=$(ls ${BACKUP_FILEDIR})
echo  ${LIST}
ls | egrep -o "?[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
# 获取7天前的时间，用于作比较，早于该时间的文件将删除
SECONDS=$(date -d  "$(date  +%F) -${DEL_DAY} days" +%s)
for index in ${LIST}
do
    # 对目录名进行格式化，取命名末尾的时间，格式如 20200902
    timeString=$(echo ${index} | egrep -o "?[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]")
    if [ -n "$timeString" ]
    then
        indexDate=${timeString//./-}
        indexSecond=$( date -d ${indexDate} +%s )
        # 与当天的时间做对比，把早于7天的备份文件删除
        if [ $(( $SECONDS- $indexSecond )) -gt 0 ]
        then
            rm -rf `echo $index | sed ':a;N;$!ba;s/\n/ /g'`
        fi
    fi
done

echo "done"
