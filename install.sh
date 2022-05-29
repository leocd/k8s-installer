#!/usr/bin/env bash
#########################################################################
# Author:  Leo Lou                                                      #
# Contact: leo@leocd.com                                                #
# Date:    2020-09-21 10:02                                             #
# Desc:    完成ansible初始化、集群系统初始化和docker安装加速、k8s集群和组建安装  #
# Last Modify:  2022-05-29 11:20                                        #
#########################################################################
super=$(sudo -l | grep -c "(ALL).*ALL")
root_case=$(dirname "$(readlink -f "$0")")
if [[ $super -eq 0 ]] || [[ $EUID -eq 0 ]]; then
    echo -e "\033[31m [ERROR] 请使用具备sudo权限的用户执行脚本,请勿使用root用户执行本脚本。 \033[0m"
    exit 1
fi
if command -v docker &> /dev/null; then
    echo -e "\033[31m [ERROR] 您的系统已经安装了Docker,无法运行本脚本。 \033[0m"
    exit 1
fi
if command -v kubectl &> /dev/null; then
    echo -e "\033[31m [ERROR] 您的系统已经安装了kubernetes,无法运行本脚本。 \033[0m"
    exit 1
fi

repo_init(){
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
    cd "$root_case" || exit
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
    sudo touch /var/log/ansible.log
    sudo chown "$(whoami)"."$(whoami)" /var/log/ansible.log
    sudo chown "$(whoami)"."$(whoami)" /etc/ansible
}

config_ansible(){
    cp "$root_case"/hosts /etc/ansible/hosts
    echo -e "\033[32m [INFO] 修改ansible配置文件 \033[0m"
    cat <<EOF > /etc/ansible/ansible.cfg
[defaults]
inventory      = /etc/ansible/hosts
forks          = 50
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

sys_init(){
    echo -e "\033[32m [INFO] 进行系统优化和安装docker \033[0m"
    ansible all -m shell -a "mkdir -p /tmp/ansible && chmod 755 /tmp/ansible"
    ansible-playbook "$root_case"/playbooks/sysinit.yaml
    ansible-playbook "$root_case"/playbooks/docker.yaml
}

k8s_install(){
  echo "开始安装k8s"
  ansible-playbook "$root_case"/playbooks/kubelet.yaml
  ansible-playbook "$root_case"/playbooks/kubeadm.yaml
  ansible-playbook "$root_case"/playbooks/todeploy.yaml
}

nfs_plugin(){
  echo "本脚本只安装k8s nfs plugin,不提供nfs服务安装功能"
  echo "在进行安装之前,请确认您的环境中已具备可用的nfs服务"
  read -r -p '是否安装nfs plugin作为k8s默认的storageclass?(y/n): ' confire
  if [ "$confire" != 'y' ]; then
    echo "您也可用在做好准备后执行下述命令进行安装:"
    echo "ansible-playbook playbooks/nfs-sc.yaml -e 'nfs_address='nfs服务器地址' nfs_dir='共享路径''"
    exit 1
  else
    read -r -p '请输入nfs服务器的IP或者域名: ' address
    read -r -p '请输入nfs服务器提供的完整共享路径(如/home/share): ' sharedir
    ansible-playbook "$root_case"/playbooks/nfs-sc.yaml -e 'nfs_address='$address' nfs_dir='$sharedir''
  fi
}

repo_init
install_ansible
config_ansible
sys_init
k8s_install
echo  -e "\033[32m [INFO] 集群安装完毕, Enjoy it! \033[0m"
nfs_plugin
