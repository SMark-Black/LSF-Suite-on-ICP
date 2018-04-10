#!/bin/bash
#--------------------------------------------------------
# Copyright IBM Corp. 1992, 2017. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#--------------------------------------------------------

function init_log()
{
    LOGFILE="$1"
    if [ ! -e "$LOGFILE" ];then
        touch "$LOGFILE"
        if [ $? != 0 ];then
            echo "ERROR: failed to initial logging. can't create log file $LOGFILE"
        fi
    fi
}

function log()
{
    echo `date` "$@" | tee -a "$LOGFILE"
}

function log_info()
{
    log "INFO:" "$@"
}

function log_error()
{
    log "ERROR:" "$@"
}

function log_warn()
{
    log "WARN:" "$@"
}

# config_ldap()
# Uses:
#   LDAP Parameters
#   LDAP_ENABLE         (manditory)
function config_ldap()
{
    log_info "Running:  config_ldap()"
    cp /etc/nsswitch.conf /etc/nsswitch.conf.ORIG
    sed -i -e 's/passwd.*/passwd:         compat sss ldap/g' /etc/nsswitch.conf
    sed -i -e 's/group.*/group:          compat sss ldap/g' /etc/nsswitch.conf
    sed -i -e 's/^shadow.*/shadow:         compat sss ldap/g' /etc/nsswitch.conf
    echo "session required        pam_mkhomedir.so skel=/etc/skel umask=077" >> /etc/pam.d/comm
on-session

    # User has provided there own sssd.conf
    /usr/sbin/sssd > /tmp/sssd-startup.out 2>&1
}

function init_share_dir()
{
    log_info "Running:  init_share_dir()"
    log_info "ROLE=$ROLE, MYHOST=$MYHOST, LSF_MASTER_LIST=$LSF_MASTER_LIST"

    # Fix the shared directories since we have mounted over them
    if [ ! -d /home/lsfuser ]; then
        mkdir -p /home/lsfuser
        cp /etc/skel/.* /home/lsfuser/
        chown -R lsfuser /home/lsfuser
    fi
    if [ ! -d /home/mariadb ]; then
        mkdir -p /home/mariadb
        cp /etc/skel/.* /home/mariadb/
        chown -R mysql /home/mariadb
    fi
    if [ ! -d /home/lsfadmin ]; then
        mkdir -p /home/lsfadmin
        cp /etc/skel/.* /home/lsfadmin/
        chown -R lsfadmin /home/lsfadmin
    fi

    # share the conf/work dir for recover
    mkdir -p $HOME_DIR/lsf/conf
    mkdir -p $HOME_DIR/lsf/work
    mkdir -p $HOME_DIR/ext/gui/conf
    mkdir -p $HOME_DIR/ext/gui/work
    mkdir -p $HOME_DIR/ext/perf/conf
    mkdir -p $HOME_DIR/ext/perf/work
    mkdir -p $HOME_DIR/ext/ppm/conf
    mkdir -p $HOME_DIR/ext/ppm/work
    mkdir -p $HOME_DIR/ext/rule-engine/conf

    if [ "$ROLE" = "master" ]; then
	# Create the hosts file
	cat /etc/hosts |grep $MYHOST > $HOME_DIR/lsf/conf/hosts

        # Clean the hostcache
        mkdir -p $HOME_DIR/lsf/work/myCluster/ego/lim
        cat /dev/null > $HOME_DIR/lsf/work/myCluster/ego/lim/hostcache

        # Create conf and work as needed
        cp -narp $LSF_TOP/conf/* $HOME_DIR/lsf/conf
        cp -narp $LSF_TOP/work/* $HOME_DIR/lsf/work
        cp -narp $PAC_TOP/gui/conf/* $HOME_DIR/ext/gui/conf
        cp -narp $PAC_TOP/gui/work/* $HOME_DIR/ext/gui/work
        cp -narp $PAC_TOP/ppm/conf/* $HOME_DIR/ext/ppm/conf
        cp -narp $PAC_TOP/ppm/work/* $HOME_DIR/ext/ppm/work
        cp -narp $PAC_TOP/perf/conf/* $HOME_DIR/ext/perf/conf
        cp -narp $PAC_TOP/perf/work/* $HOME_DIR/ext/perf/work
        cp -narp $PAC_TOP/rule-engine/conf/* $HOME_DIR/ext/rule-engine/conf

        # Maybe using existing conf so update the MASTER host
	sed -i -e s:^LSF_MASTER_LIST=.*:LSF_MASTER_LIST=$MYHOST:g $HOME_DIR/lsf/conf/lsf.conf
	sed -i -e s:^EGO_MASTER_LIST=.*:EGO_MASTER_LIST=$MYHOST:g $HOME_DIR/lsf/conf/ego/myCluster/kernel/ego.conf
        cat $HOME_DIR/lsf/conf/lsf.cluster.myCluster |awk 'BEGIN { hb=0 } $1 == "Begin" && $2 == "Host" { hb=1 } $1 == "End" && $2 == "Host" { hb=0 } $5 == "(mg)" && hb == 1 { print "'$MYHOST'    !   !   1   (mg)" } $5 != "(mg)" || hb != 1 { print $0 }' > $HOME_DIR/lsf/conf/lsf.cluster.myCluster.mod
        mv $HOME_DIR/lsf/conf/lsf.cluster.myCluster.mod $HOME_DIR/lsf/conf/lsf.cluster.myCluster

        rm -rf $LSF_TOP/conf/ && ln -s $HOME_DIR/lsf/conf/ /$LSF_TOP/
        rm -rf $LSF_TOP/work/ && ln -s $HOME_DIR/lsf/work/ /$LSF_TOP/
        rm -rf $PAC_TOP/gui/conf/ && ln -s $HOME_DIR/ext/gui/conf/ $PAC_TOP/gui/conf
        rm -rf $PAC_TOP/gui/work/ && ln -s $HOME_DIR/ext/gui/work/ $PAC_TOP/gui/work
        rm -rf $PAC_TOP/ppm/conf/ && ln -s $HOME_DIR/ext/ppm/conf/ $PAC_TOP/ppm/conf
        rm -rf $PAC_TOP/ppm/work/ && ln -s $HOME_DIR/ext/ppm/work/ $PAC_TOP/ppm/work
        rm -rf $PAC_TOP/perf/work/ && ln -s $HOME_DIR/ext/perf/work/ $PAC_TOP/perf/work
        rm -rf $PAC_TOP/perf/conf/ && ln -s $HOME_DIR/ext/perf/conf/ $PAC_TOP/perf/conf
        rm -rf $PAC_TOP/rule-engine/conf/ && ln -s $HOME_DIR/ext/rule-engine/conf/ $PAC_TOP/rule-engine/conf
 
    else
	while true; do
            if [ ! -e $HOME_DIR/lsf/conf/hosts ];then
                sleep 2
                log_info "waiting for lsf master service startup ..."
            else
                break
            fi
        done
	# Remove any conflicting IPs and names
	sed -i "/\b`hostname -i`\b/d" $HOME_DIR/lsf/conf/hosts
	sed -i "/\b`hostname`\b/d" $HOME_DIR/lsf/conf/hosts
	cat /etc/hosts |grep $MYHOST >> $HOME_DIR/lsf/conf/hosts
	rm -rf $LSF_TOP/conf/ && ln -s $HOME_DIR/lsf/conf/ /$LSF_TOP/
    fi
}

function config_lsfs()
{
    log_info "Running:  config_lsfs()"
    # the host name from base image
    IMAGE_HOST=`awk -F'"' '/MASTER_LIST/ {print $(NF-1)}' $LSF_TOP/conf/lsf.conf`
    log_info "Fixing LSF Suite config.  Old host = $IMAGE_HOST.  New host = $MYHOST"

    find $LSF_TOP/work/myCluster/logdir \
        $LSF_TOP/conf \
        $PAC_TOP/gui/conf \
        $PAC_TOP/ppm/conf \
        $PAC_TOP/perf \
        $PAC_TOP/gui/3.0/wlp/usr/servers/platform/logs/state/plugin-cfg.xml \
        $PAC_TOP/gui/3.0/wlp/usr/servers/notification/logs/state/plugin-cfg.xml \
        $PAC_TOP/gui/3.0/wlp/usr/servers/notification/server.env \
        $PAC_TOP/explorer/server/model \
        $PAC_TOP/rule-engine/conf/rule-engine-config.xml \
    -type f -print0 | xargs -0 sed -i "s/$IMAGE_HOST/$MYHOST/g"

    log_info "Fixing ELK config.  Old host = $IMAGE_HOST.  New host = $MYHOST"
    ELK_TOP=/opt/ibm/elastic
    find $ELK_TOP/elasticsearch/config \
        $ELK_TOP/logstash/config/pipeline \
        $ELK_TOP/metricbeat/config \
        $ELK_TOP/filebeat/config \
    -type f -print0 | xargs -0 sed -i "s/$IMAGE_HOST/$MYHOST/g"

    # make lsf read hosts file when new hosts added to cluster
    echo "LSF_HOST_CACHE_NTTL=0" >> $LSF_TOP/conf/lsf.conf
    echo "LSF_DHCP_ENV=y" >> $LSF_TOP/conf/lsf.conf
    echo "LSF_HOST_CACHE_DISABLE=y" >> $LSF_TOP/conf/lsf.conf
    echo "LSF_DYNAMIC_HOST_TIMEOUT=10m" >> $LSF_TOP/conf/lsf.conf
    # enable floating client
    grep -v FLOAT_CLIENTS_ADDR_RANGE $LSF_TOP/conf/lsf.cluster.myCluster > $LSF_TOP/conf/lsf.cluster.myCluster.mod
    grep -v FLOAT_CLIENTS $LSF_TOP/conf/lsf.cluster.myCluster.mod > $LSF_TOP/conf/lsf.cluster.myCluster
    rm -rf $LSF_TOP/conf/lsf.cluster.myCluster.mod
    sed -i -e "s:Begin\ Parameters:Begin\ Parameters\nFLOAT_CLIENTS_ADDR_RANGE=*.*.*.*\nFLOAT_CLIENTS=1000:g" $LSF_TOP/conf/lsf.cluster.myCluster
}


function update_etc_hosts()
{
    # update etc/hosts file so that no "HOST_NOT_FOUND" issue
    # raised by pmpi, since pmpi depends on 'gethostbyname' get
    # ip/hostname mapping
    (
cat << EOF
# Kubernetes-managed hosts file.
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
fe00::0 ip6-mcastprefix
fe00::1 ip6-allnodes
fe00::2 ip6-allrouters
`cat $HOME_DIR/lsf/conf/hosts`
EOF
    ) > /etc/hosts
}

function init_database()
{
    while true; do
        </dev/tcp/127.0.0.1/3306 && break
        sleep 3
        log_info "waiting for maria database service startup ..."
    done
    (
cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<ds:DataSources xmlns:ds="http://www.ibm.com/perf/2006/01/datasource" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xsi:schemaLocation="http://www.ibm.com/perf/2006/01/datasource datasource.xsd">
   <ds:DataSource Name="ReportDB"
        Driver="org.gjt.mm.mysql.Driver"
        Connection="jdbc:mysql://127.0.0.1:3306/pac"
        Default="true"
        Cipher="des56"
        UserName="uOTzmooF4Qw="
        Password="uOTzmooF4Qw=">
        <ds:Properties>
            <ds:Property>
                <ds:Name>maxActive</ds:Name>
                <ds:Value>30</ds:Value>
            </ds:Property>
        </ds:Properties>
   </ds:DataSource>
</ds:DataSources>
EOF
    ) > $PAC_TOP/perf/conf/datasource.xml
    log_info "check whether database already exists."
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -D$DB_NAME -h127.0.0.1 -e "select count(1) from PMC_USER;"
    if [ $? -eq 0 ]; then
        log_info "pac database already exists."
        return
    fi
    log_info "creating MYSQL database for Platform Application Center"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "create database if not exists $DB_NAME default character set utf8 default collate utf8_bin;"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -e "GRANT ALL ON $DB_NAME.* TO pacuser@127.0.0.1 IDENTIFIED BY 'pacuser';"
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/lsf/10.0/DBschema/MySQL/lsf_sql.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/ego/1.2/DBschema/MySQL/egodata.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/perf/lsf/10.0/DBschema/MySQL/lsfdata.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/create_schema.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/create_pac_schema.sql
    /usr/bin/mysql -uroot -p$MYSQL_PASSWORD -h127.0.0.1 -D$DB_NAME < $PAC_TOP/gui/DBschema/MySQL/init.sql
    log_info "MYSQL database for Platform Application Center is created."
}

function start_lsf()
{
    log_info "Start LSF services on $ROLE host $MYHOST..."
    source $LSF_TOP/conf/profile.lsf
    lsadmin limstartup >>$LOGFILE 2>&1
    lsadmin resstartup >>$LOGFILE 2>&1
    badmin hstartup >>$LOGFILE 2>&1
    log_info "LSF services on $ROLE host $MYHOST started."
}

function start_pac()
{
    log_info "Start PAC services on $ROLE host $MYHOST..."
    source  $PAC_TOP/profile.platform
    pmcadmin https disable >>$LOGFILE 2>&1
    perfadmin start all >>$LOGFILE 2>&1
    pmcadmin start PNC >>$LOGFILE 2>&1
    pmcadmin start EXPLORER >>$LOGFILE 2>&1
    pmcadmin start WEBGUI >>$LOGFILE 2>&1
}

function start_elastic()
{
    export ES_HOME=/opt/ibm/elastic/elasticsearch
    export CONF_DIR=/opt/ibm/elastic/elasticsearch/config
    export DATA_DIR=/opt/ibm/elastic/elasticsearch/data
    export LOG_DIR=/opt/ibm/elastic/elasticsearch/log
    export PID_DIR=/var/run/elasticsearch
    export PIDFile=/var/run/elasticsearch/elasticsearch-for-lsf.pid
    export JAVA_HOME=/opt/ibm/jre
    /opt/ibm/elastic/elasticsearch/bin/elasticsearch-systemd-pre-exec
    /opt/ibm/elastic/elasticsearch/bin/eslauncher.sh -p ${PID_DIR}/elasticsearch-for-lsf.pid --quiet -Edefault.path.logs=${LOG_DIR} -Edefault.path.data=${DATA_DIR} -Edefault.path.conf=${CONF_DIR}
}

function start_logstash()
{
    export CONF_DIR=/opt/ibm/elastic/logstash/config
    export LOG_DIR=/opt/ibm/elastic/logstash/log
    export JAVA_HOME=/opt/ibm/jre
    /opt/ibm/elastic/logstash/bin/logstash "--path.settings" "${CONF_DIR}" "--path.logs" "${LOG_DIR}" 2>&1 >/dev/null &
}

function generate_lock()
{
    log_info "generate lock file."
    echo 1 > $LOCKFILE
}


###############################  main  ############################################

############## CMD parameter from docker run ##########
#lsf master or slave
ROLE=$1

# db root password
MYSQL_PASSWORD=$2

#lsf master host name
LSF_MASTER_LIST=$3

log_info "CMD parameter: ROLE=$1 MYSQL_PASSWORD=$2 LSF_MASTER_LIST=$3 MORE_ARGS=$4"

#######################################

MYHOST=`uname -n`
HOME_DIR="/home/lsfadmin"
LSF_TOP="/opt/ibm/lsfsuite/lsf"
PAC_TOP="/opt/ibm/lsfsuite/ext"
LOGFILE="/tmp/start_lsf_ce_$MYHOST.log"
LOCKFILE="$LSF_TOP/lsf_ce_$MYHOST.lock"
DB_NAME="pac"
ETC_HOSTS_UPDATE_TIME_1=0



if [ -f "$LOCKFILE" ]; then
    log_info "lock file exists in $LOCKFILE, just start LSF service."
else
    init_log $LOGFILE
    if [ "$ROLE" = "master" ]; then
        config_lsfs
        # FIX THIS --------------------------------
        #init_database
    fi
    init_share_dir
fi

start_lsf

if [ "$ROLE" = "master" ]; then
    start_elastic
    start_logstash
    start_pac
fi

generate_lock

# --- Add any code needed to start other daemons here ---



# Can't exit or container stops.  Output state and update hosts if needed
while true; do
    if test $(pgrep -f lim | wc -l) -eq 0
    then
        log_error "LIM process has exited due to a fatal error."
        log_error `tail -n 20 /opt/ibm/lsflogs/lim.log.*`
        #exit 1
    else
        if [ "$ROLE" = "master" ]; then
            echo `date` "LSF is running on master $MYHOST."
        else
            echo `date` "LSF is running on slave $MYHOST."
            sleep 50
        fi
    fi
    ETC_HOSTS_UPDATE_TIME_2=`stat -c %Y $HOME_DIR/lsf/conf/hosts`
    if [ "$ETC_HOSTS_UPDATE_TIME_1" != "$ETC_HOSTS_UPDATE_TIME_2" ]; then
        log_info "Host file has changed.  Updating hosts"
        update_etc_hosts
        ETC_HOSTS_UPDATE_TIME_1=ETC_HOSTS_UPDATE_TIME_2
    fi
    sleep 10
done
