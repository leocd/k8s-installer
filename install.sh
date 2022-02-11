#!/usr/bin/env bash
#########################################################################
# Author:  Leo Lou                                                      #
# Contact: leo@leocd.com                                                #
# Date:    2020-09-21 10:02                                             #
# Desc:    完成k8s多master高可用集群、calico、nginx ingress、nfs插件安装     #
#########################################################################
if [[ $EUID -eq 0 ]]; then
    echo "本脚本请勿使用sudo执行,执行命令为sh install.sh" 1>&2
    exit 1
fi
if command -v kubectl &> /dev/null; then
    echo "您的系统已经安装了k8s,无法运行本脚本!" 1>&2
    exit 1
fi

k8s_install(){
  echo "开始安装k8s"
  ansible-playbook "playbooks/kubelet.yaml"
  ansible-playbook "playbooks/kubeadm.yaml"
  ansible-playbook "/playbooks/todeploy.yaml"
}

nfs_plugin(){
  echo "本脚本只安装k8s nfs plugin,不提供nfs服务安装功能"
  echo "在进行安装之前,请确认您的环境中已具备可用的nfs服务"
  read -r -p '是否安装nfs plugin作为k8s默认的storageclass?(y/n): ' confire
  if [ "$confire" != 'y' ]; then
    echo "您也可用在做好准备后执行下述命令进行安装:"
    echo "sh nfsplugin.sh"
    exit 1
  else
    read -r -p '请输入nfs服务器的IP或者域名: ' address
    read -r -p '请输入nfs服务器提供的完整共享路径(如/home/share): ' sharedir
    ansible-playbook "playbooks/nfs-sc.yaml" -e 'nfs_address='$address' nfs_dir='$sharedir''
  fi
}

k8s_install
nfs_plugin
echo  -e "\033[32m [INFO] 集群安装完毕, Enjoy it! \033[0m"