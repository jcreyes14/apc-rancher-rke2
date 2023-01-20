#!/bin/bash
sudo curl -sfL https://get.rke2.io | sudo sh -
sudo systemctl enable rke2-server.service
n=0
until [ "$n" -ge 5 ]
do
   sudo systemctl start rke2-server.service && break  # substitute your command here
   n=$((n+1)) 
   sleep 60
done
