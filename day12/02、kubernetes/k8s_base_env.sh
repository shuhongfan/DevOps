#/bin/sh

#######################开始设置环境##################################### \n


printf "##################正在配置所有基础环境信息################## \n"


printf "##################关闭selinux################## \n"
sed -i 's/enforcing/disabled/' /etc/selinux/config
setenforce 0
printf "##################关闭swap################## \n"
swapoff -a  
sed -ri 's/.*swap.*/#&/' /etc/fstab 

printf "##################配置路由转发################## \n"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf

## 必须 ipv6流量桥接
echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
## 必须 ipv4流量桥接
echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/k8s.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/k8s.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.d/k8s.conf
echo "net.ipv6.conf.all.forwarding = 1"  >> /etc/sysctl.d/k8s.conf
modprobe br_netfilter
sudo sysctl --system
	
	
printf "##################配置ipvs################## \n"
cat <<EOF | sudo tee /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules 
sh /etc/sysconfig/modules/ipvs.modules


printf "##################安装ipvsadm相关软件################## \n"
yum install -y ipset ipvsadm




printf "##################安装docker容器环境################## \n"
sudo yum remove docker*
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce-19.03.9  docker-ce-cli-19.03.9 containerd.io
systemctl enable docker
systemctl start docker

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://82m9ar63.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker


printf "##################安装k8s核心包 kubeadm kubelet kubectl################## \n"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
   http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

###指定k8s安装版本
yum install -y kubelet-1.21.0 kubeadm-1.21.0 kubectl-1.21.0

###要把kubelet立即启动。
systemctl enable kubelet
systemctl start kubelet

printf "##################下载api-server等核心镜像################## \n"
sudo tee ./images.sh <<-'EOF'
#!/bin/bash
images=(
kube-apiserver:v1.21.0
kube-proxy:v1.21.0
kube-controller-manager:v1.21.0
kube-scheduler:v1.21.0
coredns:v1.8.0
etcd:3.4.13-0
pause:3.4.1
)
for imageName in ${images[@]} ; do
docker pull registry.cn-hangzhou.aliyuncs.com/lfy_k8s_images/$imageName
done
## 全部完成后重新修改coredns镜像
docker tag registry.cn-hangzhou.aliyuncs.com/lfy_k8s_images/coredns:v1.8.0 registry.cn-hangzhou.aliyuncs.com/lfy_k8s_images/coredns/coredns:v1.8.0
EOF
   
chmod +x ./images.sh && ./images.sh
   
### k8s的所有基本环境全部完成