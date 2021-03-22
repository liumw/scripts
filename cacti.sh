#!/bin/bash
[ $(id -u) != "0" ] && echo "Error: You must be root to run this script" && exit 1
#必须为ROOT用户
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# 关闭yum锁
 rm -f /var/run/yum.pid
echo "#######################关闭SELinux--开启防火墙的相关端口#################"
sed -i "s/SELINUX=enforcing/SELINUX=disabled/"  /etc/selinux/config
setenforce 0
systemctl stop firewalld
systemctl disable firewalld
echo "####################请选择安装cacti版本#######################"
echo "(1) Install Cacti-1.1.38"
echo "(2) Install cacti-1.2.14"
echo "(3) EXIT"
read -p "请选择安装cacti版本:" NUM
case $NUM in 
1)
    URL=http://www.cacti.net/downloads/cacti-1.1.38.tar.gz
    VER=cacti-1.1.38
    SPINE=cacti-spine-1.1.38
;;
2)
    URL=https://www.cacti.net/downloads/cacti-1.2.14.tar.gz
    VER=cacti-1.2.14
    SPINE=cacti-spine-1.2.14
;;
3)
    echo -e "You choice channel! " && exit 0
;;
*)
    echo -e " Input Error! Place input{1|2|3} " && exit 1
;;
esac
clear
echo -e "您选择安装的是 $VER.Install"
echo -e "按任意键开始安装 $VER... "
read -n 1
read -p "请输入数据库 root 密码:" MY_PWD
read -p "请输入cacti数据库 密码:" CACTI_PWD
echo "######################安装阿里云yum源#################"
yum -y install wget
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo_bak
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
yum makecache
 
echo "####################安装ntp时间同步#######################"
yum -y install ntp 
systemctl enable ntpd
systemctl start ntpd 
timedatectl set-timezone Asia/Shanghai 
timedatectl set-ntp yes 
ntpq -p
 
echo "#########################下载PHP7.2包 并安装 Apache###########################"
yum install  http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
yum install yum-utils -y
yum-config-manager --enable remi-php72
yum -y install httpd httpd-devel
systemctl enable httpd  
systemctl start httpd
systemctl status httpd
echo "#########################创建cacti虚拟机目录###########################"
cat > /etc/httpd/conf.d/cacti.conf << EOF
# Cacti: An RRD based graphing tool
#
# For security reasons, the Cacti web interface is accessible only to
# localhost in the default configuration. If you want to allow other clients
# to access your Cacti installation, change the httpd ACLs below.
# For example:
# On httpd 2.4, change "Require host localhost" to "Require all granted".
# On httpd 2.2, change "Allow from localhost" to "Allow from all".
 #改成80端口
<VirtualHost *:80>
    LogLevel warn
#改成本机的IP地址
    DocumentRoot "/var/www/html/cacti"
    Alias /cacti    /var/www/html/cacti
#下面三行注释掉，因为没有ssh证书
    #SSLEngine On
    #SSLCertificateFile /etc/ssl/certs/YourOwnCertFile.crt
    #SSLCertificateKeyFile /etc/ssl/private/YourOwnCertKey.key
 
    <Directory /var/www/html/cacti/>
        <IfModule mod_authz_core.c>
                # httpd 2.4
                Require all granted
        </IfModule>
        <IfModule !mod_authz_core.c>
                # httpd 2.2
                Order deny,allow
                Deny from all
                Allow from all
        </IfModule>
    </Directory>
 
    <Directory /var/www/html/cacti/install>
        # mod_security overrides.
        # Uncomment these if you use mod_security.
        # allow POST of application/x-www-form-urlencoded during install
        #SecRuleRemoveById 960010
        # permit the specification of the RRDTool paths during install
        #SecRuleRemoveById 900011
    </Directory>
    # These sections marked "Require all denied" (or "Deny from all")
    # should not be modified.
    # These are in place in order to harden Cacti.
    <Directory /var/www/html/cacti/log>
        <IfModule mod_authz_core.c>
                Require all denied
        </IfModule>
        <IfModule !mod_authz_core.c>
                Order deny,allow
                Deny from all
        </IfModule>
    </Directory>
    <Directory /var/www/html/cacti/rra>
        <IfModule mod_authz_core.c>
                Require all denied
        </IfModule>
        <IfModule !mod_authz_core.c>
                Order deny,allow
                Deny from all
        </IfModule>
    </Directory>
</VirtualHost>
EOF
 
systemctl restart httpd
systemctl status httpd
 
echo "##############################安装SNMPD############################"
yum -y  install net-snmp net-snmp-utils net-snmp-libs net-snmp-devel
systemctl enable snmpd
systemctl start snmpd
systemctl status snmpd
echo "##############################写入本机SNMPD配置############################"
#read -p "Please input host SNMP_Community:" SNMPCOMM
SNMPFILE=/etc/snmp/snmpd.conf
if [ -f "$SNMPFILE" ]
        then
        cp $SNMPFILE /etc/snmp/snmpd.conf.bak
fi
cat > $SNMPFILE << EOF
com2sec notConfigUser  default      $SNMPCOMM
group   notConfigGroup v1           notConfigUser
group   notConfigGroup v2c           notConfigUser
view    systemview    included   .1
view    systemview    included   .1.3.6.1.2.1.1
view    systemview    included   .1.3.6.1.2.1.25.1.1
access  notConfigGroup ""      any       noauth    exact  all  none none
view all    included  .1                               80
syslocation Unknown (edit /etc/snmp/snmpd.conf)
syscontact Root <root@localhost> (configure /etc/snmp/snmp.local.conf)
dontLogTCPWrappersConnects yes
proc mountd
proc ntalkd 4
proc senmail 10 1
exec echotest /bin/echo hello world
disk / 10000
EOF
echo -e "Config SNMP Done!"
systemctl restart snmpd
systemctl status snmpd
snmpwalk -v 2c -c public localhost
#read -n 1
echo "#########################添加 MariaDB 10.2YUM 仓库###########################"
cd /etc/yum.repos.d/
touch MariaSB.10x.repo
echo "# MariaDB 10.4 CentOS repository list - created 2019-09-12 01:55 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = https://mirrors.ustc.edu.cn/mariadb/yum/10.4/centos7-amd64/
gpgkey=https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1" >MariaSB.10x.repo
echo "#########################install  mariadb-server###########################"
yum clean all
yum makecache
cd /
yum -y install mariadb mariadb-server mariadb-devel MariaDB-client
systemctl enable mariadb
systemctl start mariadb
systemctl status mariadb
mysql_secure_installation << EOF
 
y
y
$MY_PWD
$MY_PWD
y
y
y
y
EOF
#read -n 1
echo "############################Install Cacti###########################"
cd /
mkdir download
cd /download/
wget --no-check-certificate $URL
tar -xvf $VER.tar.gz -C /var/www/html/
cd /var/www/html/
mv $VER/ cacti
chown -R apache:apache  /var/www/html/cacti/*
chmod 777 -R /var/www/html/cacti/log/
chmod 777 -R /var/www/html/cacti/rra/
echo "#############################覆盖 /etc/my.cnf.d/server.cnf 文件############################"
cat >/etc/my.cnf.d/server.cnf <<EOF
[client]
 default-character-set = utf8mb4
[mysql]
 default-character-set = utf8mb4
[server]
[mysqld]
         character_set_server=utf8mb4
        character-set-client-handshake = true
        character_set_client = utf8mb4
        collation-server = utf8mb4_unicode_ci
        init_connect=’SET NAMES utf8mb4'
        max_heap_table_size = 128M
        max_allowed_packet = 16777216
        join_buffer_size = 128M
        innodb_file_format = Barracuda
        tmp_table_size = 64M
        join_buffer_size = 128M
        innodb_file_per_table = ON
        innodb_buffer_pool_size = 1024M
        innodb_doublewrite = off
        innodb_lock_wait_timeout = 50
        innodb_flush_log_at_trx_commit = 2
        innodb_large_prefix = 1
        log-error                      = /var/log/mysql/mysql-error.log
        log-queries-not-using-indexes  = 1
        slow-query-log                 = 1
        slow-query-log-file            = /var/log/mysql/mysql-slow.log
 
        innodb_doublewrite = ON
        innodb_flush_method = O_DIRECT
        innodb_flush_log_at_timeout = 3
        innodb_read_io_threads = 32
        innodb_write_io_threads = 16
        innodb_buffer_pool_instances = 9
        innodb_io_capacity = 5000
        innodb_io_capacity_max = 10000
EOF
systemctl restart mariadb
#写入时区
mysql_tzinfo_to_sql /usr/share/zoneinfo/Asia/Shanghai Shanghai | mysql -u root -p$MY_PWD mysql
echo "##############################写入cacti数据库############################"
mysql -u root "-p$MY_PWD" -e "create database cacti character set utf8;"
mysql -u root "-p$MY_PWD" cacti</var/www/html/cacti/cacti.sql
mysql -u root "-p$MY_PWD" -e "CREATE USER 'cactiuser'@'localhost' identified by \""$CACTI_PWD"\";"
mysql -u root "-p$MY_PWD" -e "grant all privileges on cacti.* to cactiuser@'localhost' identified by \""$CACTI_PWD"\";"
##如果需要开放root远程访问，请去掉下行注释
##mysql -u root "-p$MY_PWD" -e "UPDATE user SET Host='%' WHERE User='root' AND Host='localhost' LIMIT 1;"
mysql -u root "-p$MY_PWD" -e "grant select on mysql.time_zone_name to 'cactiuser'@'localhost';"
mysql -u root "-p$MY_PWD" -e "flush privileges;"
mysql -u root "-p$MY_PWD" -e "exit"
echo -e "Config Database Done!\n\n\n\n"
#read -n 1
echo -e "exit"
echo "#########################安装依赖包###########################"
yum -y install  gcc mysql-devel autautomake libtool dos2unix help2man openssl-devel perl perl-devel rpm-develoconf  libxml2-devel libxml2 pcre pcre-devel pango pango-devel
yum -y install rrdtool
yum -y install perl-rrdtool*
yum -y install perl-DB*
rrdtool -v
yum -y install php-gmp php-mysql php-pear php-common php-gd php-devel php php-mbstring php-cli php-intl php-snmp php-ldap
echo "#########################php时区配置###########################"
sed -i 's#;date.timezone =#date.timezone = Asia/Shanghai#g' /etc/php.ini  
sed -i 's/memory_limit = 128M/memory_limit = 2048M/g' /etc/php.ini 
sed -i 's/max_execution_time = 30/max_execution_time = 60/g' /etc/php.ini 
 
echo "##############################修改cacti配置文件############################"
cp /var/www/html/cacti/include/config.php /var/www/html/cacti/include/config.php.bak
sed -i 's/'"username \= 'cactiuser';"/"username \= 'root';"'/g' /var/www/html/cacti/include/config.php
sed -i 's/'"password \= 'cactiuser';"/"password \= '$CACTI_PWD';"'/g' /var/www/html/cacti/include/config.php
 
echo "##############################加入crontab，每1分钟采集一次############################"
#删除原poller.php
sed -i  '/poller/d' /var/spool/cron/root
echo "*/1 * * * * /usr/bin/php /var/www/html/cacti/poller.php >/dev/null 2>&1">>/var/spool/cron/root
 
echo "##############################安装spine############################"
cd /download/
wget --no-check-certificate https://www.cacti.net/downloads/spine/$SPINE.tar.gz
tar -xvf $SPINE.tar.gz
mv $SPINE /usr/local/spine
cd /usr/local/spine
ln -s /usr/lib64/libmysqlclient.so.18.0.0 /usr/lib64/libmysqlclient.so
sh bootstrap 
./configure
make
make install
chown root:root /usr/local/spine/bin/spine
chmod u+s /usr/local/spine/bin/spine
cp /usr/local/spine/etc/spine.conf.dist /etc/spine.conf
#############spine配置文件
cat > /etc/spine.conf << EOF
DB_Host 127.0.0.1
DB_Database cacti
DB_User cactiuser
DB_Pass $CACTI_PWD
DB_Port 3306
EOF
 
systemctl restart httpd
echo -e "请访问 http://IP 开启cacti之旅 \n\n 按任意键继续"
