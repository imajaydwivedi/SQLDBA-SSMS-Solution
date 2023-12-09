--	Set static Ip on Ubuntu 18.0+
https://www.techrepublic.com/article/how-to-configure-a-static-ip-address-in-ubuntu-server-18-04/

-- Edit the file
sudo vim file
sudo netplan apply

network:
    ethernets:
        enp0s3:
            dhcp4: no
            addresses: [10.10.10.12/24]
            gateway4: 10.10.10.11
            nameservers:
                    addresses: [10.10.10.11,10.10.10.10]
        enp0s8:
            addresses: [192.168.1.52/24]
            dhcp4: no
            gateway4: 192.168.1.1
            nameservers:
                    addresses: [8.8.8.8,8.8.4.4]

    version: 2
    renderer: networkd
