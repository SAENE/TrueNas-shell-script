#!/bin/bash
echo "----------脚本执行开始----------"
date
# 保存路径
save_path=/config/workspace/TrueNas-shell-script/download
echo "保存路径为${save_path}"
mkdir ${save_path}
# rss订阅地址(一定要转义)
rss_url=https://rss.rss/i/\?a\=rss\&get\=c_8\&rid\=\&hours\=

# 下载订阅信息
echo "----------下载订阅----------"
wget ${rss_url} -O ${save_path}/rss.xml
echo "----------下载订阅完成----------"

echo "----------计算文章数量----------"
# 计算一共有多少条
description_cont=`cat ${save_path}/rss.xml | grep '<description>' | wc -l`
# 计算正确一共有几条
description_cont_True=`expr ${description_cont} - 1`
# 输出计算结果
echo "共有${description_cont_True}条文章"
echo "----------计算完成----------"

echo "----------开始下载----------"
# 从第二条开始下载，第一条为网页信息
i=2
# 下载循环开始
until [ ! $i -le ${description_cont} ]
do
    # description_title=`cat ${save_path}/rss.xml | grep '<description>' | sed -n ${i}p | sed 's/.*<\!\[CDATA\[<p>\(.*\)<\/p><br><p><img.*/\1/g'`
    # description_title=`cat ${save_path}/rss.xml | sed ':a;N;$!ba;s/\(.*<\/title>\)\n/\1/g' | sed ':a;N;$!ba;s/\(.*<\/link>\)\n/\1/g' | sed ':a;N;$!ba;s/\(.*<\/dc:creator>\)\n/\1/g' | grep '<description>' | sed -n ${i}p | sed 's/.*<\!\[CDATA\[<p>\(.*\)<\/p><br><p><img.*/\1/g'`
    # 获取标题名称
    description_title=`cat ${save_path}/rss.xml | grep '<title>'  | sed -n ${i}p | sed 's/<title>\(.*\)<\/title>/\1/g' | sed 's/^[[:space:]]*//g'`

    echo "正在下载第${i}个，${description_title}"

    # 创建标题名称的文件夹
    mkdir "${save_path}/${description_title}"
    # 获取图片地址
    # description_imgurl=`cat ${save_path}/rss.xml | grep '<description>' | sed -n ${i}p | egrep -o "https.+(jpg|png|bmp|tif|jpeg|svg|webp|exif|gif|raw)\"" | sed 's/" referrerpolicy="no-referrer"><\/p><p><img src="/ /g' | sed 's/"$//g'`
    description_imgurl=`cat ${save_path}/rss.xml | grep '<description>' | sed -n ${i}p | egrep -o "https.+\"" | sed 's/" referrerpolicy="no-referrer"><\/p><p><img src="/ /g' | sed 's/" referrerpolicy="no-referrer"//g'`
    # 下载图片
    wget -N ${description_imgurl} -P "${save_path}/${description_title}/" 2>> "${save_path}/wget-error.log"
    # 
    i=`expr $i + 1`
done
echo "----------下载完成----------"

echo "----------删除订阅文件----------"
rm ${save_path}/rss.xml
echo "----------删除文件完成----------"

echo "----------脚本执行结束----------"
echo -e '\n\n'