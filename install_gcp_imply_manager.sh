#!/bin/bash

BILLING_ACCOUNT="014361-7E4821-XXXX"
PROJECT_NAME="imply-poc-7"
CLUSTER_NAME="imply-poc"
REGION="us-east1"
CLUSTER_CIDR="172.16.0.0/20"
MASTER_CIDR="172.16.0.32/28"
EXTRA_ARGS=""
NETWORK_NAME="imply-poc"
# change these to your CIDRs
FIREWALL_MANAGER_INBOUND="75.166.183.18/32"
FIREWALL_PIVOT_INBOUND="75.166.183.18/32"
FIREWALL_DRUID_INBOUND="75.166.183.18/32"
# update to POC instance types
MACHINE_TYPE="n1-standard-1"
NUM_NODES=1
KAFKA_CONTAINER_NAME="kafka"


function create_firewalls(){
	gcloud compute firewall-rules create imply-manager-ingress \
	--network $NETWORK_NAME \
	--direction "in" \
	--action "allow" \
	--source-ranges $FIREWALL_MANAGER_INBOUND \
	--rules "TCP:9097" \
	--project $PROJECT_NAME

	gcloud compute firewall-rules create imply-druid-ingress \
	--network $NETWORK_NAME \
	--direction "in" \
	--action "allow" \
	--source-ranges $FIREWALL_DRUID_INBOUND \
	--rules "TCP:8888" \
	--project $PROJECT_NAME

	gcloud compute firewall-rules create imply-pivot-ingress \
	--network $NETWORK_NAME \
	--direction "in" \
	--action "allow" \
	--source-ranges $FIREWALL_PIVOT_INBOUND \
	--rules "TCP:9095" \
	--project $PROJECT_NAME

}

function delete_firewalls(){
	gcloud compute firewall-rules delete \
	imply-manager-ingress imply-druid-ingress imply-pivot-ingress \
	--project $PROJECT_NAME
}

function create_kafka_container(){
	gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_NAME
	helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
	helm repo update
	helm install $KAFKA_CONTAINER_NAME  incubator/kafka --set external.enabled=true,external.type=LoadBalancer
}

function delete_kafka_container(){
	helm uninstall $KAFKA_CONTAINER_NAME
}

function create_project(){
	gcloud auth application-default login
	gcloud projects create $PROJECT_NAME
	gcloud beta billing projects link $PROJECT_NAME --billing-account=$BILLING_ACCOUNT
	gcloud services enable "container.googleapis.com" --project $PROJECT_NAME
}

function delete_project(){
	gcloud projects delete $PROJECT_NAME
}

function create_network(){
	gcloud compute networks create $NETWORK_NAME \
	--subnet-mode=auto \
	--project $PROJECT_NAME
}

function delete_network(){
	gcloud compute networks delete $NETWORK_NAME \
	--project $PROJECT_NAME
}

function create_cluster(){
	gcloud container clusters create $CLUSTER_NAME \
	--region $REGION \
	--num-nodes=$NUM_NODES \
	--machine-type=$MACHINE_TYPE \
	--project $PROJECT_NAME \
	--network $NETWORK_NAME \
	--create-subnetwork name=$CLUSTER_NAME-subnet \
	--enable-ip-alias \
	--project $PROJECT_NAME

}

function delete_cluster(){
	gcloud container clusters delete $CLUSTER_NAME \
	--project $PROJECT_NAME \
	--region=$REGION
}

function install_imply_manager(){
	gcloud auth application-default login
	gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_NAME
	kubectl delete secret imply-secrets
	kubectl create secret generic imply-secrets --from-file=./imply/IMPLY_MANAGER_LICENSE_KEY
	helm install $CLUSTER_NAME imply/imply --set manager.service.enabled=true,manager.service.type=LoadBalancer,manager.service.port=9097,query.service.type=LoadBalancer
}

case $1 in

	"create_cluster")
	create_project
	create_network
	create_firewalls
	create_cluster
	;;

	"install_imply")
	install_imply_manager
	;;

	"uninstall_imply")
	helm uninstall $CLUSTER_NAME
	;;

	"delete_cluster")
	delete_cluster
	delete_firewalls
	delete_network
	delete_project
	;;

	"install_kafka")
	create_kafka_container
	;;

	"uninstall_kafka")
	delete_kafka_container
	;;

	*)
	echo "Usage: sh start_gcp_imply_manager.sh "
	echo "	create_cluster	- Create the Kubernetes cluster along with networking (VPC) and firewalls"
	echo "	install_imply	- Install the imply druid containers from helm"
	echo "	uninstall_imply	- Remove the imply containers from the Kubernetes cluster"
	echo "	delete_cluster	- Delete the Kubernetes cluster along with all networking and firewalls"
	echo "	install_kafka	- Install a kafka container along with a stand alone zookeeper"
	echo "	uninstall_kafka	- Remove the kafka container and zookeeper container "
	;;

esac
