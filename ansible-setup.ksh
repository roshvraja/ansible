## Setup standalone AWX Ansible Tower

echo "What is the IP address of Ansible Tower?"
read IP
echo ""
echo "What is the FQDN Ansible Tower?"
read FQDN
echo ""
SHORTNAME=$( echo ${FQDN} | awk -F. '{print $1}' )

hostnamectl set-hostname ${FQDN}

# Update /etc/hosts
cat <<EOF>> /etc/hosts
##------------------------------------
## Ansible
##------------------------------------
${IP} ${FQDN} ${Setup} ${SHORTNAME}
##------------------------------------
EOF

# Setup ssh key
ssh-keygen -b 2048 -t rsa
ssh-copy-id root@ansible

# Disable firewall
systemctl stop firewalld
systemctl disable firewalld
systemctl mask --now firewalld
systemctl status firewalld

# Disable Selinux, as this is required to allow containers to access the host filesystem, which is needed by pod networks and other services.
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
cat /etc/sysconfig/selinux | grep SELINUX=
sestatus

# Install additional packages
yum install -y python3-pip git net-tools

# set python command to use python 3
alternatives --set python /usr/bin/python3

# Update the system
yum update -y

# Add Docker and EPEL Repository and disable it
yum config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
yum install -y epel-release.noarch
yum repolist
yum config-manager --disable epel
yum config-manager --disable epel-modular
yum config-manager --disable docker-ce-stable
yum repolist

# Install Docker and start it
yum -y --enablerepo=docker-ce-stable install docker-ce --nobest -y
systemctl start docker
systemctl enable docker --now
docker --version

# Install Docker Compose
pip3 install docker-compose
docker-compose --version

# Install Ansible
yum -y --enablerepo=epel install ansible
ansible --version

# Git clone awx
git clone https://github.com/ansible/awx.git

# Update inventory file
sed -i --follow-symlinks 's/# awx_official=false/awx_official=true/g' /root/awx/installer/inventory
sed -i --follow-symlinks 's/#project_data_dir/project_data_dir/g' /root/awx/installer/inventory

# Run aws install playbook
cd /root/awx/installer
ansible-playbook -i inventory install.yml

# Open AWX tower
echo "http://${IP}/#/login
