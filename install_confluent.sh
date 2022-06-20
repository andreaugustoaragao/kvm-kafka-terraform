#!/bin/bash
IP=$1
ID=$2
ZOOKEPER_ID=$(($ID+1))
sudo apt update && sudo apt upgrade -y
sudo apt install gnupg curl jq -y

# add Azul's public key
sudo apt-key adv \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys 0xB1998361219BD9C9

# download and install the package that adds 
# the Azul APT repository to the list of sources 
curl -O https://cdn.azul.com/zulu/bin/zulu-repo_1.0.0-3_all.deb

# install the package
sudo apt-get install ./zulu-repo_1.0.0-3_all.deb -y

# update the package sources
sudo apt-get update -y

sudo apt-get install zulu18-jdk -y

#sudo adduser --system --no-create-home --disabled-password --disabled-login kafka
#sudo mkdir /opt/confluent
#curl -O http://packages.confluent.io/archive/7.1/confluent-community-7.1.1.tar.gz
#sudo tar -xzvf confluent-community-7.1.1.tar.gz --directory /opt/confluent --strip-components 1
#sudo mkdir -p /var/lib/zookeeper
#sudo mkdir -p /var/lib/kafka-logs
#sudo mkdir -p /var/lib/kafka-streams
#sudo chown -R kafka:nogroup /opt/confluent
#sudo chown -R kafka:nogroup /var/lib/zookeeper
#sudo chown -R kafka:nogroup /var/lib/kafka-logs
#sudo chown -R kafka:nogroup /var/lib/kafka-streams
#sudo ln -s /opt/confluent/etc/kafka /etc/kafka
#sudo ln -s /opt/confluent/etc/schema-registry /etc/schema-registry

#sudo touch /etc/profile.d/confluent-vars.sh
#echo "export CONFLUENT_HOME=/o |pt/confluent" | sudo tee -a /etc/profile.d/confluent-vars.sh
#echo "export CONFLUENT_BOOTSTRAP_SERVERS=${IP}:9092" | sudo tee -a /etc/profile.d/confluent-vars.sh 
#echo "export CONFLUENT_SCHEMA_REGISTRY_URL=http://${IP}:8081" | sudo tee -a /etc/profile.d/confluent-vars.sh
#echo "export PATH=\$PATH:\$CONFLUENT_HOME/bin" | sudo tee -a /etc/profile.d/confluent-vars.sh

echo "192.168.100.2 kafka-vm-0"|sudo tee -a /etc/hosts
echo "192.168.100.3 kafka-vm-1"|sudo tee -a /etc/hosts
echo "192.168.100.4 kafka-vm-2"|sudo tee -a /etc/hosts

wget -qO - https://packages.confluent.io/deb/7.1/archive.key | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://packages.confluent.io/deb/7.1 stable main" -y
sudo add-apt-repository "deb https://packages.confluent.io/clients/deb $(lsb_release -cs) main" -y
sudo apt-get update && sudo apt-get install confluent-community-2.13 -y
sudo chown cp-kafka:confluent /var/log/confluent && sudo chmod u+wx,g+wx,o= /var/log/confluent

sudo mv /home/ubuntu/zookeeper.properties /etc/kafka/zookeeper.properties
echo ${ZOOKEPER_ID} | sudo tee -a /var/lib/zookeeper/myid
sudo systemctl start confluent-zookeeper

#sudo sed -i 's/\/tmp\/kafka-logs/\/var\/lib\/kafka-logs/g' /etc/kafka/server.properties
sudo sed -i "s/broker.id=0/broker.id=${ID}/g" /etc/kafka/server.properties
sudo sed -i 's/zookeeper.connect=localhost:2181/zookeeper.connect=192.168.100.2:2181,192.168.100.3:2181,192.168.100.4:2181/g' /etc/kafka/server.properties
sudo systemctl start confluent-kafka



sudo sed -i 's/kafkastore.bootstrap.servers=PLAINTEXT:\/\/localhost:9092/kafkastore.bootstrap.servers=PLAINTEXT:\/\/kafka-vm-0:9092,PLAINTEXT:\/\/kafka-vm-1:9092,PLAINTEXT:\/\/kafka-vm-2:9092/g' /etc/schema-registry/schema-registry.properties
echo "host.name=${IP}" | sudo tee -a /etc/schema-registry/schema-registry.properties

sudo systemctl start confluent-schema-registry
