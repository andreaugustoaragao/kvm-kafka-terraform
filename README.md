# kvm-kafka-terraform

Simple scripts to create a 3 nodes kafka cluster in KVM using terraform

## usage

1. configure you KVM bridge
2. update zookeeper.properties and terraform.tfvars.json to reflect your environment
3. terraform init; terraform apply --auto-approve
4. have fun! - you should have a cluster of X nodes with zookeeper, kafka and schema-registry installed

