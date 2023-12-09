#!/bin/bash
yum -y update
yum -y install httpd
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h1>Hello! This is ${prefix}'s VM. My Private IP is $myip <font color="turquoise"> in the ${env} environment</font></h1><br>Built by Terraform!"  >  /var/www/html/index.html
sudo systemctl start httpd
sudo systemctl enable httpd
