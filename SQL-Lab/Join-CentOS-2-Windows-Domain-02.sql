--	https://computingforgeeks.com/join-centos-rhel-system-to-active-directory-domain/

--	Step 1: Install required packages
dnf install realmd sssd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation 

--	Step 2: Discover Active Directory domain on CentOS 8 / RHEL 8
	-- 2.1 - Verify DNS settings
	cat /etc/resolv.conf
	-- 2.2 - Check if AD domain discovery is successful
	realm  discover contso.com
	-- 2.3 - If 2.2 does not resolve, then add dc.contso.com & contso.com in /etc/hosts
	vim /etc/hosts

--	Step 3: Join CentOS 8 / RHEL 8 Linux machine in Active Directory domain
	-- 3.1 - Join to domain
	realm join contso.com -U Administrator
	-- 3.2 - Confirm that join was successful
	realm list

--	Step 4: 
realm permit -g 'SQLDBAs'