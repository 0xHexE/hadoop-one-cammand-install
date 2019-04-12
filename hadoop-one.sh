#!/usr/bin/env bash

# Author Omkar Yadav <httpsOmkar@gmail.com>
# Github https://github.com/httpsOmkar
# Stackoverflow https://stackoverflow.com/users/7177984/omkar-yadav

APACHE_HADOOP_VERSION="hadoop-3.1.2"
CURRENT_OS=""
JAVA_PATH=""

function check_is_root() {
    if [[ "$EUID" -ne 0 ]]
      then echo "Please run as root"
      exit
    fi
}

function get_java_home() {
    javaPath="$(readlink -f $(which java))"
    replace_string=""
    JAVA_PATH=${javaPath/"jre/bin/java"/$replace_string}
}

function check_java_version() {
    if type -p java; then
        readlink -f $(which java)
        get_java_home
    else
        echo "Java is not installed"
        case "$CURRENT_OS" in
            "UBUNTU") {
                apt-get install default-jdk ssh
            } ;;
            "ARCH LINUX") {
                pacman -S jdk8-openjdk ssh
            } ;;
        esac
        get_java_home
    fi
}

function detect_os() {
    echo "Finding the current OS"
    osType=$(uname)
    case "$osType" in
            "Darwin") {
                CURRENT_OS="OSX"
                echo "We currently not support Mac OS"
                exit 1
            } ;;
            "Linux") {
                # If available, use LSB to identify distribution
                if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
                    DISTRO=$(gawk -F= '/^NAME/{print $2}' /etc/os-release)
                else
                    DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
                fi
                CURRENT_OS=$(echo $DISTRO | tr 'a-z' 'A-Z')
            } ;;
            *)
            {
                echo "Unsupported OS, exiting"
                exit -1
            } ;;
    esac
    echo "You are using $CURRENT_OS"
}

function download_apache_hadoop() {
    wget -c "http://apache.mirrors.tds.net/hadoop/common/$APACHE_HADOOP_VERSION/$APACHE_HADOOP_VERSION.tar.gz"
    tar -xzvf "$APACHE_HADOOP_VERSION.tar.gz"
    mkdir -p /usr/local/hadoop
    sudo mv "$APACHE_HADOOP_VERSION" /usr/local/hadoop
}

function setup_apache_hadoop() {
    sudo chown -R hduser:hadoop /usr/local/hadoop
    echo "export JAVA_HOME=$JAVA_PATH" >> ~/.bashrc
    echo "export HADOOP_HOME=/usr/local/hadoop" >> ~/.bashrc
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin" >> ~/.bashrc
    echo "export PATH=\$PATH:\$HADOOP_HOME/sbin" >> ~/.bashrc
    echo "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" >> ~/.bashrc
    echo "export HADOOP_COMMON_HOME=\$HADOOP_HOME" >> ~/.bashrc
    echo "export HADOOP_HDFS_HOME=\$HADOOP_HOME" >> ~/.bashrc
    echo "export YARN_HOME=\$HADOOP_HOME" >> ~/.bashrc
    echo "export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native" >> ~/.bashrc
    echo "export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_HOME/lib" >> ~/.bashrc
    source ~/.bashrc
    echo "export JAVA_HOME=$JAVA_PATH">> /usr/local/hadoop/etc/hadoop/hadoop-env.sh
    mkdir -p /app/hadoop/tmp
    chown hduser:hadoop /app/hadoop/tmp

    echo "
    <configuration>
        <property>
            <name>hadoop.tmp.dir</name>
            <value>/app/hadoop/tmp</value>
            <description>A base for other temporary directories.</description>
        </property>
        <property>
          <name>fs.default.name</name>
          <value>hdfs://localhost:54310</value>
          <description>The name of the default file system.  A URI whose scheme and authority determine the FileSystem implementation.  The uri’s scheme determines the config property (fs.SCHEME.impl) naming the FileSystem implementation class.  The uri’s authority is used to determine the host, port, etc. for a filesystem.</description>
         </property>
    </configuration>
    " >> /usr/local/hadoop/etc/hadoop/core-site.xml

    mkdir -p /usr/local/hadoop_store/hdfs/namenode
    mkdir -p /usr/local/hadoop_store/hdfs/datanode
    chown -R hduser:hadoop /usr/local/hadoop_store

    echo "
    <configuration>
        <property>
            <name>dfs.replication</name>
            <value>1</value>
            <description>Default block replication.The actual number of replications can be specified when the file is created. The default is used if replication is not specified in create time.</description>
        </property>
        <property>
            <name>dfs.namenode.name.dir</name>
            <value>file:/usr/local/hadoop_store/hdfs/namenode</value>
        </property>
        <property>
            <name>dfs.datanode.data.dir</name>
            <value>file:/usr/local/hadoop_store/hdfs/datanode</value>
        </property>
    </configuration>
    " >> /usr/local/hadoop/etc/hadoop/hdfs-site.xml

    "
    <configuration>
        <property>
            <name>yarn.nodemanager.aux-services</name>
            <value>mapreduce_shuffle</value>
        </property>
    </configuration>
    " >> /usr/local/hadoop/etc/hadoop/yarn-site.xml

    hadoop namenode -format
    source /usr/local/hadoop/sbin/start-all.sh
}

function check_is_hadoop_already_installed() {
    echo "Checking is hadoop already installed or not..."
}

function setup_user_and_groups() {
    addgroup hadoop
    adduser "–ingroup hadoop hduser"
    sudo adduser hduser sudo
    ssh-keygen -t rsa -f id_rsa -t rsa -N ''
    HOME_FOLDER_OF_HDUSER="$(getent passwd someuser | cut -f6 -d:))"
    cat ./id_rsa.pub >> ${HOME_FOLDER_OF_HDUSER}/.ssh/authorized_keys
}

if [[ $# -lt 1 ]]; then
  echo "Hadoop one cammand install"
  echo "Usage: [sudo] $0 [--test | --delete | --import csv_file]"
  exit 1
fi


check_is_root
check_is_hadoop_already_installed
detect_os
check_java_version
setup_apache_hadoop
