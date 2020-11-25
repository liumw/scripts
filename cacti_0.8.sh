#!/bin/bash
#date 2016/8/8
#mail xuel@51idc.com
#############
echo "##########################################"
echo "Auto Install Cacti                      ##"
echo "Press Ctrl + C to cancel                ##"
echo "Any key to continue                     ##"
echo "##########################################"
read -n 1
############################################
#init config
/etc/init.d/iptables status >/dev/null 2>&1
if [ $? -eq 0 ]
then
iptables -I INPUT -p tcp --dport 80 -j ACCEPT &&
iptables -I INPUT -p udp --dport 161 -j ACCEPT &&
iptables-save >/dev/null 2>&1
else
    echo -e "\033[32m iptables is stopd\033[0m"
fi
sed -i "s/SELINUX=enforcing/SELINUX=disabled/"  /etc/selinux/config
setenforce 0
yum -y install ntpdate wget vim 
ntpdate -s time1.aliyun.com
echo "*/5 * * * * ntpdate -s time1.aliyun.com">>/var/spool/cron/root
###########################################
yum -y install httpd mysql-server php php-mysql php-snmp mysql-devel httpd-devel net-snmp net-snmp-devel net-snmp-utils rrdtool
 
SNMPFILE=/etc/snmp/snmpd.conf
if [ -f "$SNMPFILE" ]
        then
        cp $SNMPFILE /etc/snmp/snmpd.conf.bak
fi
cat > $SNMPFILE << EOF
com2sec notConfigUser  default       public
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
nstall httpd mysql-server php php-mysql php-snmp mysql-devel httpd-devel net-snmp net-snmp-devel
 net-snmp-utils rrdtoolproc senmail 10 1
exec echotest /bin/echo hello world
disk / 10000
EOF
/etc/init.d/httpd start
chkconfig httpd on
/etc/init.d/mysqld start
chkconfig mysqld on
/etc/init.d/snmpd start
chkconfig snmpd on
#############################################
if [ -d /var/www/html ];then
    cd /var/www/html
else
    mkdir -p /var/www/html && cd /var/www/html
fi
wget -c -O /var/www/html/cacti-0.8.8h.tar.gz  http://www.cacti.net/downloads/cacti-0.8.8h.tar.gz
tar -zxvf cacti-0.8.8h.tar.gz
mv cacti-0.8.8h cacti
cd cacti
chown -R root.root *
useradd cacti
echo "cacti" | passwd --stdin cacti
echo "*/1 * * * * php /var/www/html/cacti/poller.php >/dev/null 2>&1">>/var/spool/cron/root
mysqladmin -uroot password "mysqladmin"
mysql -uroot -pmysqladmin -e "create database cacti character set utf8;" 
mysql -uroot -pmysqladmin cacti </var/www/html/cacti/cacti.sql
mysql -uroot -pmysqladmin -e "CREATE USER 'cacti'@'localhost' IDENTIFIED BY 'cacti';"
mysql -uroot -pmysqladmin -e "grant all privileges on cacti.* to cacti@'localhost' identified by 'cacti';"
mysql -uroot -pmysqladmin -e "flush privileges;"
CONF=/var/www/html/cacti/include/config.php
cat >$CONF<<EOF
<?php
\$database_type = "mysql";
\$database_default = "cacti";
\$database_hostname = "localhost";
\$database_username = "cacti";
\$database_password = "cacti";
\$database_port = "3306";
?>
EOF
 
 
##################################################
DIR=/var/www/html/cacti/plugins
if [ -d $DIR ];then
    cd $DIR
else
    mkdir -p $DIR  && cd DIR
fi
wget -c -O $DIR/monitor.tgz http://docs.cacti.net/_media/plugin:monitor-v1.3-1.tgz
tar -zxvf monitor.tgz
 
wget -c -O $DIR/flowview.tgz http://docs.cacti.net/_media/plugin:flowview-v1.1-1.tgz
tar -zxvf flowview.tgz
 
wget -c -O $DIR/ntop.tgz http://docs.cacti.net/_media/plugin:ntop-v0.2-1.tgz
tar -zxvf ntop.tgz
 
wget -c -O $DIR/thold.tgz http://docs.cacti.net/_media/plugin:thold-v0.5.0.tgz
tar -zxvf thold.tgz
 
wget -c -O $DIR/mobile.tgz http://docs.cacti.net/_media/plugin:mobile-latest.tgz
tar -zxvf mobile.tgz
 
wget -c -O $DIR/syslog.tgz http://docs.cacti.net/_media/plugin:syslog-v1.22-2.tgz
tar -zxvf syslog.tgz
wget -c -O $DIR/settings.tgz http://docs.cacti.net/_media/plugin:settings-v0.71-1.tgz
tar -zxvf settings.tgz
wget -c -O $DIR/discovery.tgz http://docs.cacti.net/_media/plugin:discovery-v1.5-1.tgz
tar -zxvf discovery.tgz
echo -e "\033[32m Cacti install success!\033[0m"
echo -e "\033[32m Mysql user:root  passwd:mysqladmin\033[0m"
echo -e "\033[32m Mysql user:cacti  passwd:cacti\033[0m"
echo -e "\033[32m Cacti Web Login user:admin  Passwd:admin\033[0m"
echo -e "\033[32m URL:http://IP/cacti\033[0m"
