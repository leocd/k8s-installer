# k8s-installer

基于Ansible自动化安装kubernetes  
默认安装了metrics-server、calico、nginx ingress、nfs provisioner  
默认使用nfs作为storageclass  
nginx ingress修改了一些默认参数，以提升性能  
安装需要提供额外的负载均衡和nfs server，本程序未集成安装

## 使用指南

* ansible执行机需要与hosts文件中配置的master机器一致
* 程序需直接放置在用户家目录下，示例：/home/leo可以，/home/leo/apps不可以，执行路径应该为/home/leo/k8s-installer
* 因为访问gcr经常出现问题，因此使用docker registry v2把镜像load到本地，镜像包需要单独下载
* 在进行操作前，请根据实际情况 `修改` 程序根目录下的hosts文件和playbooks/group_vars/all.yaml文件
* 修改前请 `务必仔细阅读` 两个文件中的注释部分
* 修改完成后，输入sh init.sh进行内核升级等操作
* 待机器重启完毕后输入sh install.sh进行k8s集群安装

### 镜像包下载地址

[点这里](https://share.weiyun.com/gAts26OA)  
下载后放在package目录下，执行`tar xf package.tar.gz`

### TODO

&#x274E; 添加EFK stack  
&#x274E; 添加prometheus stack  
&#x274E; 用istio替换nginx ingress
