#!/bin/bash

#==============================================================================
#title           :install_imply_manager.sh
#description     :This script will run required commands to install imply manager and dependencies
#author		 :jon.king@imply.io
#date            :2019-12-18
#version         :0.1
#usage		 :bash install_imply_manager.sh (install|uninstall|status)
#notes		 : Removing need for docker hub credentials
#bash_version    :3.2
#==============================================================================


HELM_VERSION="helm-v3.0.2-darwin-amd64"
KUBERNETES_VERSION=1.16.3
MINIKUBE_VERSION=1.6.1
KUBECTL_VERSION=1.16.3
IMPLY_REPO="imply/imply"
IMPLY_DEV_REPO="imply-dev/imply"

function sanity_check(){

	if [[ ! "$OSTYPE" == "darwin"* ]]; then
		echo "OS MUST BE OSX"
		exit 1
	fi

	if [ -z "$DOCKER_USERNAME" ]; then
		echo "DOCKER_USERNAME not set in env variables"
		exit 1
	fi
	if [ -z "$DOCKER_PASSWORD" ]; then
		echo "DOCKER_PASSWORD not set in env variables"
		exit 1
	fi
	if [ -z "$DOCKER_EMAIL" ]; then
		echo "DOCKER_EMAIL not set in env variables"
		exit 1
	fi
}

function install_virtualbox(){
	echo "INSTALLING VIRTUALBOX"
	brew cask install virtualbox
}

function install_kubectl(){
	echo "INSTALLING KUBECTL"
	curl -s -LO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/darwin/amd64/kubectl
	chmod +x ./kubectl
	echo "MOVING kubectl to /usr/local/bin"
	mv ./kubectl /usr/local/bin/kubectl
}

function remove_kubectl(){
	echo "REMOVING KUBECTL"
	rm -f /usr/local/bin/kubectl
}

function install_minikube(){
	echo "INSTALLING MINIKUBE"
	curl -s -LO https://storage.googleapis.com/minikube/releases/v${MINIKUBE_VERSION}/minikube-darwin-amd64
	echo "MOVING minikube to /usr/local/bin"
	sudo install minikube-darwin-amd64 /usr/local/bin/minikube
}

function remove_minikube(){
	echo "REMOVE MINIKUBE"
	minikube delete
	rm -f /usr/local/bin/minikube
}

function install_helm(){
	echo "INSTALL HELM"
	local HELM_TARBALL=${HELM_VERSION}.tar.gz
	curl -s -LO https://get.helm.sh/${HELM_TARBALL}
	tar -zxvf ${HELM_TARBALL}
	echo "MOVING helm to /usr/local/bin"
	cp darwin-amd64/helm /usr/local/bin/helm
}

function remove_helm(){
	echo "REMOVING HELM"
	rm -f /usr/local/bin/helm
}

function start_minikube(){
	echo "STARTING MINIKUBE"
	minikube delete
	minikube config set vm-driver virtualbox
	minikube start --cpus 2 --memory 6144 --disk-size 16g --vm-driver=virtualbox --kubernetes-version v${KUBERNETES_VERSION}
}

function add_imply_dev_helm_repo(){
	echo "ADDING IMPLY DEV HELM REPO"
	helm --v 3 repo add imply-dev https://s3.amazonaws.com/static.imply.io/onprem/helm-dev
        echo "UPDATING HELM REPO"
        helm --v 3 repo update
}

function add_imply_helm_repo(){
	echo "ADDING IMPLY HELM REPO"
	helm --v 3 repo add imply https://static.imply.io/onprem/helm
	echo "UPDATING HELM REPO"
	helm --v 3 repo update
}

# DEPRECATED AS OF IMPLY 3.2
#function create_secret_registry(){
#	echo "CREATING SECRET REGISTRY"
#	kubectl delete secret regcred
#	kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=${DOCKER_USERNAME} --docker-email=${DOCKER_EMAIL} --docker-password=${DOCKER_PASSWORD}
#}

function create_secrets_license_key(){
	echo "CREATING SECRETES FOR IMPLY LICENSE KEY"
	if [ -z "IMPLY_MANAGER_LICENSE_KEY" ]; then
		echo "! Cannot find Imply license key !"
		exit 1
	fi
	kubectl create secret generic imply-secrets --from-file=IMPLY_MANAGER_LICENSE_KEY
}


function install_imply_manager_dev_helm_chart(){
	echo "CREATING IMPLY MANAGER CHART"
	helm --v 3 install imply-dev/imply --generate-name --set manager.secretName=imply-secrets
}


function install_imply_manager_helm_chart(){
	echo "CREATING IMPLY MANAGER CHART"
	helm --v 3 install imply/imply --generate-name --set manager.secretName=imply-secrets
}

function get_pod_info(){
	kubectl get pods
}

function get_logs(){
	kubectl logs -f -lapp.kubernetes.io/name=imply-manager --tail=1000
}


case $1 in

	"install-minikube-cluster")
	install_virtualbox
        install_kubectl
        install_minikube
        start_minikube
        install_helm
	;;

	"install-dev")
	echo "RUNNING SANITY CHECK"
	sanity_check

	echo "installing Local Imply Manager"
	install_virtualbox
	install_kubectl
	install_minikube
	start_minikube
	install_helm
	add_imply_dev_helm_repo
	#create_secret_registry
	create_secrets_license_key
	install_imply_manager_dev_helm_chart
	;;

	"install")
	echo "RUNNING SANITY CHECK"
	sanity_check

	echo "installing Local Imply Manager"
	install_virtualbox
	install_kubectl
	install_minikube
	start_minikube
	install_helm
	add_imply_helm_repo
	#create_secret_registry
	create_secrets_license_key
	install_imply_manager_helm_chart
	;;

	"uninstall")
	echo "UNINSTALLING IMPLY MANAGER"
	remove_minikube
	remove_helm
	remove_kubectl
	;;

	"status")
	get_pod_info

esac
