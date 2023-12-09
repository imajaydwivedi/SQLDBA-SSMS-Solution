--	https://www.youtube.com/watch?v=4jh6VwEaRt8

# Installing realmd package 

yum install sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python

# Edit Host File to add DNS IP address and Server Information

vi /etc/hosts

# View File /etc/resolv.conf 

It should resolve Domain name and IP address

# Join with Windows Domain
realm join --user=clusteradmin tbsdc.Techbrothers.local

# Verify domain Join 
realm list
# id clusteradmin@Techbrothers.local

# Turning off Fully Qualified Name requirement of AD user

vi /etc/sssd/sssd.conf

systemctl restart sssd 
systemctl daemon-reload

# adding user to sudo or admin - Where "wheel" is group and cluster admin is active directory user

 sudo usermod -a -G wheel clusteradmin