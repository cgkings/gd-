#!/bin/bash
RED='\E[1;31m'
END='\E[0m'
list=()
i=1
release=""
sys=""

nfo_db_path="/home/Emby"
db_path="/mnt/video/EmbyDatabase/"
nfo_db_file="Emby削刮库.tar.gz"
opt_file="Emby-server数据库.tar.gz"
var_config_file="Emby-VarLibEmby数据库.tar.gz"



#
#检查系统相关
#
check_release(){
	if [[ -f /etc/redhat-release ]]; then
	       release='centos'
       elif cat /etc/issue | grep -q -E -i "debian"; then
	       release='debian'
       elif cat /etc/issue | grep -q -E -i "ubuntu"; then
	       release='ubuntu'
       elif cat /etc/issue | grep -q -E -i "redhat|red hat|centos";then
	       release='centos'
       elif cat /proc/version | grep -q -E -i "debian"; then
	       release='debian'
       elif cat /proc/version | grep -q -E -i "ubuntu"; then
	       release='ubuntu'
       elif cat /proc/version | grep -q -E -i "redhat|red hat|centos"; then
	       release='centos'
       fi
	sys=$(uname -m)       
}
check_release

check_command(){
	command -v $1 > /dev/null 2>&1

	if [[  $? != 0 ]];then
		echo -e "${RED}$1${END} 不存在.正在为您安装，请稍后..."
		if [[ "${release}" = "centos" ]];then
			yum install $1 -y
		elif [[ "${release}" = "debian" || "${release}" = "ubuntu" ]];then
			apt-get install $1 -y
		else
			echo "对不起！您的系统暂不支持该脚本，请联系作者做定制优化，谢谢！"
			exit 1
		fi
	fi

}

check_command wget
check_command curl

ip_addr=$(curl -s ifconfig.me)


#
#安装rclone
#
if [[ ! -f /usr/bin/rclone ]];then

	echo -e "正在下载rclone,请稍等..."
	wget https://raw.githubusercontent.com/wuhuai2020/linux/master/rclone.tar.gz && tar zxvf rclone.tar.gz -C /usr/bin/
fi
if [[ -f /usr/bin/rclone ]];then
	sleep 1s
	echo -e "Rclone安装成功."
else
	echo -e "安装失败.请重新运行脚本安装."
	exit 1
fi

if [[ ! -f /root/.config/rclone/rclone.conf ]];then
	echo
	echo -e "正在下载rclone配置文件，请稍等..."
	sleep 1s
	wget https://raw.githubusercontent.com/wuhuai2020/linux/master/rclone.conf -P /root/.config/rclone/
fi
if [[ -f /root/.config/rclone/rclone.conf ]];then
	sleep 1s
	echo -e "配置文件下载成功."
else
	echo -e "下载配置文件失败,请重新运行脚本下载."
	exit 1
fi


#
#安装Emby服务
#
#emby_version="4.5.0.50"
emby_version=`curl -s https://github.com/MediaBrowser/Emby.Releases/releases/ | grep -Eo "tag/[0-9.]+\">([0-9.]+.*)" | grep -v "beta"|grep -Eo "[0-9.]+"|uniq`
centos_packet_file="emby-server-rpm_${emby_version}_x86_64.rpm"
debian_packet_file="emby-server-deb_${emby_version}_amd64.deb"
url="https://github.com/MediaBrowser/Emby.Releases/releases/download"
debian_url="${url}/${emby_version}/${debian_packet_file}"
centos_url="${url}/${emby_version}/${centos_packet_file}"

	
setup(){

	if [ -f /usr/lib/systemd/system/emby-server.service ]; then
		sleep 1s
		echo -e "Emby已经存在.无须安装."
		return 1
	fi

	echo -e "您的系统是${release}。正在为您准备安装包,请稍等..."
	if [[ "${release}" = "debian" ]];then
		if [[ "${sys}" = "x86_64" ]];then
			wget -c "${debian_url}" && dpkg -i "${debian_packet_file}"
		fi
	elif [[ "${release}" = "ubuntu" ]];then
		if [[ "${sys}" = "x86_64" ]];then
			wget -c "${debian_url}" && dpkg -i "${debian_packet_file}"
		fi
	elif [[ "${release}" = "centos" ]];then
		if [[ "${sys}" = "x86_64" ]];then
			yum install -y "${centos_url}"
		fi
	fi


}	


setup






#
#创建rclone服务
#

for item in $(sed -n "/\[.*\]/p" ~/.config/rclone/rclone.conf | grep -Eo "[0-9A-Za-z-]+")
do
	list[i]=${item}
	i=$((i+1))
done
while [[ 0 ]]
do
	while [[ 0 ]]
	do
		echo
		echo -e "本地已配置网盘列表:"
		echo
		for((j=1;j<=${#list[@]};j++))
		do
			echo -e "${RED}${j}：【${list[j]}】${END}"
		done


		echo
		read -n3 -p "请选择需要挂载的网盘（输入数字即可）：" rclone_config_name
		if [ ${rclone_config_name} -le ${#list[@]} ] && [ -n ${rclone_config_name} ];then
			echo -e "您选择了：${RED}${list[rclone_config_name]}${END}"
			break	
		fi
		echo
		echo "输入不正确，请重新输入。"
		echo
	done
	read -p "请输入需要挂载目录的路径（如不是绝对路径则挂载到/mnt下）:" path
	if [[ "${path:0:1}" != "/" ]];then
		path="/mnt/${path}"
	fi
	while [[ 0 ]]
	do
		echo -e "您选择了 ${RED}${list[rclone_config_name]}${END} 网盘，挂载路径为 ${RED}${path}${END}."
		read -n1 -p "确认无误[Y/n]:" result
		echo
		case ${result} in
			Y | y)
				echo
				break 2;;
			n | N)
				continue 2;;
			*)
				echo
				continue;;
		esac
	done
	
done


fusermount -qzu "${path}"
if [[ ! -d ${path} ]];then
	echo "${path} 不存在，正在创建..."
	mkdir -p ${path}
	sleep 1s
	echo "创建完成！"
fi




echo "正在检查服务是否存在..."
if [[ -f /lib/systemd/system/rclone-${list[rclone_config_name]}.service ]];then
        echo -e "找到服务 \"${RED}rclone-${list[rclone_config_name]}.service${END}\"正在删除，请稍等..."
	systemctl stop rclone-${list[rclone_config_name]}.service &> /dev/null
	systemctl disable rclone-${list[rclone_config_name]}.service &> /dev/null
        rm /lib/systemd/system/rclone-${list[rclone_config_name]}.service &> /dev/null
	sleep 2s
	echo -e "删除成功。"
fi
echo -e "正在创建服务 \"${RED}rclone-${list[rclone_config_name]}.service${END}\"请稍等..."
echo "[Unit]
Description = rclone-sjhl

[Service]
User = root
ExecStart = /usr/bin/rclone mount ${list[rclone_config_name]}: ${path} --transfers 10  --buffer-size 1G --vfs-read-chunk-size 256M --vfs-read-chunk-size-limit 2G  --allow-non-empty --allow-other --dir-cache-time 12h --umask 000 
Restart = on-abort

[Install]
WantedBy = multi-user.target" > /lib/systemd/system/rclone-${list[rclone_config_name]}.service
sleep 2s
echo "服务创建成功。"
if [ ! -f /etc/fuse.conf ]; then
	echo -e "未找到fuse包.正在安装..."
	sleep 1s
	if [[ "${release}" = "centos" ]];then
		yum install fuse -y
	elif [[ "${release}" = "debian" || "${release}" = "ubuntu" ]];then
		apt-get install fuse -y
	fi
	echo
	echo -e "fuse安装完成."
	echo
fi

sleep 2s
echo "启动服务..."
systemctl start rclone-${list[rclone_config_name]}.service &> /dev/null
sleep 1s
echo "添加开机启动..."
systemctl enable rclone-${list[rclone_config_name]}.service &> /dev/null
if [[ $? ]];then
	echo
	echo "服务配置完成!"
	echo
	echo
	sleep 2s
else
	echo "警告:未知错误."
fi


#
#复制Emby配置文件
#

if [ -f /usr/lib/systemd/system/emby-server.service ];then
	echo "停用Emby服务..."
	systemctl stop emby-server.service
	sleep 2s
	echo -e "已停用Emby服务"
else
	sleep 2s
	echo -e "未找到emby.请重新执行安装脚本安装."
	exit 1
fi

if [ -d /var/lib/emby ] && [ -d /opt/emby-server ];then
	echo -e "已找到emby配置文件，正在备份..."
	mv /var/lib/emby /var/lib/emby.bak
	mv /opt/emby-server /opt/emby-server.bak
	sleep 2s
	echo -e "已将/var/lib/emby和/opt/emby-server分别备份到当前目录."
	echo
elif  [ -d /var/lib/emby.bak ] && [ -d /opt/emby-server.bak ];then
	echo -e "已备份，无需备份."
	sleep 2s
fi
echo -e "正在安装削刮库到/home/Emby需要很长时间,请耐心等待..."
if [ ! -d "${nfo_db_path}" ];then
	mkdir ${nfo_db_path}
fi
if [  -d ${db_path} ];then
	if [ -f "${db_path}${nfo_db_file}" ];then
		tar -xzf ${db_path}${nfo_db_file} -C ${nfo_db_path}
	else
		echo -e "未能找到削刮包 ${db_path}${nfo_db_file} 请确认无误后重新运行脚本."
		exit 1
	fi
	echo -e "Emby削刮包安装完成."
	echo

	sleep 2s
	echo -e "正在配置emby程序.请稍等..."
	if [ -f ${db_path}${opt_file} ];then
		tar -xzf ${db_path}${opt_file} -C /opt
	else
		echo -e "未能找到削刮包 ${db_path}${opt_file} 请确认无误后重新运行脚本."
		exit 1

	fi

	if [ -f ${db_path}${var_config_file} ];then
		tar -xzf ${db_path}${var_config_file} -C /var/lib
	else
		echo -e "未能找到削刮包 ${db_path}${var_config_file} 请确认无误后重新运行脚本."
		exit 1

	fi
	echo -e "Emby程序配置完成."
	echo

else
	echo "未找到${db_path},请检查是否正确挂载。确认无误后重新执行脚本."
	exit 1

fi

echo -e "启动emby服务..."
systemctl start emby-server.service

sleep 1s
echo -e "配置完成."
echo
echo -e "访问地址为:${RED}http://${ip_addr}:8096。账号：admin 密码为空${END}"