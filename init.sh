#!/usr/bin/env bash
#########################################################################
# Author:  Leo Lou                                                      #
# Contact: leo@leocd.com                                                #
# Date:    2020-09-21 10:02                                             #
# Desc:    初始化脚本，完成ansible初始化、集群系统初始化和docker安装加速        #
#########################################################################
super=$(sudo -l | grep -c "(ALL) ALL")
if [[ $super -eq 0 || $(whoami) = 'root' ]]; then
    echo -e "\033[31m [ERROR] 请使用具备sudo权限的用户执行脚本,请勿使用root用户执行本脚本。 \033[0m"
    exit 1
fi
if command -v docker &> /dev/null; then
    echo -e "\033[31m [ERROR] 您的系统已经安装了Docker,无法运行本脚本。 \033[0m"
    exit 1
fi

install_offlinerepo(){
    echo -e "\033[32m [INFO] 移除原有依赖,预防安装冲突。 \033[0m"
    sudo rpm -qa | grep libxml2 | xargs sudo rpm -e --nodeps
    sudo rpm -qa | grep deltarpm | xargs sudo rpm -e --nodeps
    sudo rpm -qa | grep createrepo | xargs sudo rpm -e --nodeps

    echo -e "\033[32m [INFO] 安装createrepo,创建离线源。 \033[0m"
    cd package || exit
    sudo rpm -ivh createc/deltarpm-3.6-3.el7.x86_64.rpm
    sudo rpm -ivh createc/python-deltarpm-3.6-3.el7.x86_64.rpm
    sudo rpm -ivh createc/libxml2-2.9.1-6.el7.5.x86_64.rpm
    sudo rpm -ivh createc/libxml2-python-2.9.1-6.el7.5.x86_64.rpm
    sudo rpm -ivh createc/createrepo-0.9.9-28.el7.noarch.rpm

    sudo tar xf rpm_offline.tgz -C /opt/
    sudo createrepo -v /opt/rpm_offline
    cd /opt/rpm_offline && sudo python -m SimpleHTTPServer 6440 &
    sleep 5

    echo -e "\033[32m [INFO] 为本机设置离线yum源。 \033[0m"
    cat <<EOF | sudo tee /etc/yum.repos.d/offline.repo
[offline]
name=Local Repo
baseurl=http://127.0.0.1:6440/
gpgcheck=0
enable=1
EOF
    sudo yum clean all && sudo yum makecache
}

install_ansible(){
    sudo yum install ansible -y
    sudo rm -rf /etc/ansible/*
    touch /var/log/ansible.log
    chown "$(whoami)"."$(whoami)" /var/log/ansible.log
    chown "$(whoami)"."$(whoami)" /etc/ansible
}

config_ansible(){
    cp hosts /etc/ansible/hosts
    echo -e "\033[32m [INFO] 修改ansible配置文件 \033[0m"
    cat <<EOF > /etc/ansible/ansible.cfg
[defaults]
inventory      = /etc/ansible/hosts
forks          = 50
become         = root
remote_port    = 22
host_key_checking = False
timeout           = 10
log_path          = /var/log/ansible.log
remote_tmp        = /tmp/ansible

[ssh_connection]
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True

EOF
}

key_init(){
    read -r -p '请确认集群内所有机器是否已对本机设置免密登录(y/n): ' keyauth
    if [ "$keyauth" != 'y' ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa -q -b 2048
    cp -p ~/.ssh/id_rsa.pub /tmp/id_rsa.pub
    ansible-playbook playbooks/add_key.yaml
    ansible-playbook laybooks/sysinit.yaml
    ansible-playbook playbooks/docker.yaml
  else
    ansible-playbook playbooks/sysinit.yaml
    ansible-playbook playbooks/docker.yaml
  fi
}

install_ansible
config_ansible
key_init
echo -e "\033[32m [INFO] 集群内所有服务将在1分钟后重启,在此期间请勿进行其它操作 \033[0m"
echo -e "\033[32m [INFO] 请在重启完成后执行sh install.sh \033[0m"