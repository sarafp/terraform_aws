#!/bin/bash
yum update -y
yum remove java-1.7.0-openjdk -y
yum install java-1.8.* -y
yum-config-manager --enable epel
yum repolist
yum install ansible -y
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins.io/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
yum install jenkins -y
service jenkins start
yum install git -y
wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
yum install -y apache-maven

echo "export JRE_HOME=/usr/lib/jvm/java-1.8.0-openjdk.x86_64/jre">> /etc/profile.d/java.sh
echo "export PATH=\$PATH:\$JRE_HOME/bin">> /etc/profile.d/java.sh
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk.x86_64">> /etc/profile.d/java.sh
echo "export JAVA_PATH=\$JAVA_HOME">> /etc/profile.d/java.sh
echo "export PATH=\$PATH:\$JAVA_HOME/bin">> /etc/profile.d/java.sh
