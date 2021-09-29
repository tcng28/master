#!/usr/bin/env bash

# usage:
# ./unInstall-and-deploy.sh --package=ucpadvisor-v4.0.0.dev-1396.tgz --externalIP=172.25.20.157 --secondaryExternalIP=172.25.20.179 --cmds=sdb,sdc --licensingServerIP=172.25.20.166 

removeCRDs() {
	DOMAIN=$1
	echo "Removing CRs with domain $DOMAIN"
	## get list of CRDS
	CRDS=$(kubectl api-resources --verbs=list --namespaced -o name | grep -iF "$DOMAIN")
	for CRD in $CRDS
	do	
		echo "In CRD $CRD"
		## get list of namespaces these crs live
		NAMESPACES=$(kubectl get $CRD -A -o jsonpath="{.items[*].metadata.namespace}")
		for NAMESPACE in $NAMESPACES
		do
			echo "try to create namespace $NAMESPACE incase no longer exist"
			kubectl create namespace $NAMESPACE 
			## get list of CRs in each namespace
			CRS=$(kubectl get -n $NAMESPACE $CRD | tail -n +2 | sed 's/\s.*//g')

			for CR in $CRS
			do
				echo "Patch and Remove CR: $CRD $CR in namespace $NAMESPACE"
				kubectl patch $CRD $CR  -n $NAMESPACE --type="merge" -p '{"metadata": {"finalizers": null}}' -o yaml > /dev/null 2>&1
				kubectl delete $CRD $CR  -n $NAMESPACE --timeout 20s || true
			done
			kubectl delete namespace $NAMESPACE --timeout 5s || true
		done
		echo "Patch and Remove CRD: $CRD"
		kubectl patch crds $CRD --type="merge" -p '{"metadata": {"finalizers": null}}' -o yaml > /dev/null 2>&1
		kubectl delete crds $CRD --timeout 20s || true
		# kubectl delete --ignore-not-found=true $CRD --all -n $NAMESPACE --timeout 60s || true
	done
}

#Checking if JQ is installed
if ! command -v jq &> /dev/null
then 
	echo "jq is not found, please install jq"
	exit 
else
	echo "jq is installed"
fi
echo ""
HELM_INSTALL_CMD="helm install ucpadvisor "
HELM_UPGRADE_CMD="helm upgrade --install ucpadvisor "
#Parsing shell script command line input and construct helm install command
for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d= )
    VALUE=$(echo $ARGUMENT | cut -f2 -d= )   
    case "$KEY" in
		--package)
			PACKAGE=${VALUE} 
			HELM_INSTALL_CMD+="https://repo.sc.eng.hitachivantara.com/artifactory/triangulum-helm-dev-sc/${VALUE} "
			HELM_UPGRADE_CMD+="https://repo.sc.eng.hitachivantara.com/artifactory/triangulum-helm-dev-sc/${VALUE} "
			echo "Install helm package $PACKAGE"
			;;
		--externalIP)
			EXTERNALIP=${VALUE}
			HELM_INSTALL_CMD+="--set global.externalIP=${VALUE} "
			HELM_UPGRADE_CMD+="--set global.externalIP=${VALUE} "
			echo "setting externalIP $EXTERNALIP"
			;;
		--secondaryExternalIP)
			SECONDARYEXTERNALIP=${VALUE}
			if [[ -n $SECONDARYEXTERNALIP ]]
			then
				HELM_INSTALL_CMD+="--set global.secondaryExternalIP=$SECONDARYEXTERNALIP "
				HELM_UPGRADE_CMD+="--set global.secondaryExternalIP=$SECONDARYEXTERNALIP "
				echo "setting secondaryExternalIP $SECONDARYEXTERNALIP"
			fi

			;;
		--licensingServerIP)
			LICENSINGIP=${VALUE}
			HELM_INSTALL_CMD+="--set global.licensingServerIP=${VALUE} "
			HELM_UPGRADE_CMD+="--set global.licensingServerIP=${VALUE} "
			echo "setting licensingServerIP $LICENSINGIP"
			;;
		--scpHostIP)
			HOSTIP=${VALUE}
			HELM_INSTALL_CMD+="--set scpHostIP=${VALUE} "
			HELM_UPGRADE_CMD+="--set scpHostIP=${VALUE} "
			echo "setting scpHostIP $HOSTIP"
			;;
		--scpCredentialsUsername)
			SCPUSER=${VALUE}
			HELM_INSTALL_CMD+="--set scpCredentials.username=${VALUE} "
			HELM_UPGRADE_CMD+="--set scpCredentials.username=${VALUE} "
			echo "setting scpCredentialsUsername $SCPUSER"
			;;
		--scpCredentialsPassword)
			SCPPASS=${VALUE}
			HELM_INSTALL_CMD+="--set scpCredentials.password=${VALUE} "
			HELM_UPGRADE_CMD+="--set scpCredentials.password=${VALUE} "
			echo "setting scpCredentialsPassword $SCPPASS"
			;;
		--gatewayRootPassword)
			GATEPASS=${VALUE}
			HELM_INSTALL_CMD+="--set gatewayRootPassword=${VALUE} "
			HELM_UPGRADE_CMD+="--set gatewayRootPassword=${VALUE} "
			echo "setting gatewayRootPassword $GATEPASS"
			;;
		--defaultGateway)
			GATEWAYIP=${VALUE}
			HELM_INSTALL_CMD+="--set defaultGateway=${VALUE} "
			HELM_UPGRADE_CMD+="--set defaultGateway=${VALUE} "
			echo "setting defaultGateway $GATEWAYIP"
			;;
		--cmds)
		    if [ -z "${VALUE}" ]
            then
                  echo "cmds is empty"
            else
                  echo "cmds is NOT empty"
                  CMDDEVS=${VALUE}
        		  HELM_INSTALL_CMD+="--set sdi_gateway.block.cmdDevs={${CMDDEVS}} "
        		  HELM_UPGRADE_CMD+="--set sdi_gateway.block.cmdDevs={${CMDDEVS}} "
        		  echo "setting cmds $CMDDEVS"
            fi
		
			;;
		*)
    esac    
done

#Checking required input parameters
if [ -z "$PACKAGE" ]
then
    echo "ERROR: Package field must be set"
    exit 1
fi
if [ -z "$EXTERNALIP" ]
then
	echo "ERROR: External IP must be set"
	exit 1
fi
if [ -z "$GATEPASS" ]
then
	HELM_INSTALL_CMD+="--set gatewayRootPassword=Hitachi1 "
	HELM_UPGRADE_CMD+="--set gatewayRootPassword=Hitachi1 "
fi
if [ -z "$LICENSINGIP" ]
then
	HELM_INSTALL_CMD+="--set global.licensingServerIP=172.25.22.160 "
	HELM_UPGRADE_CMD+="--set global.licensingServerIP=172.25.22.160 "
fi
echo "get timezone of master node"
export TIMEZONE=$(readlink -f /etc/localtime)
sleep 5
echo ""
echo ""
echo ""

if [ "$EXTERNALIP" == "172.25.20.0" -o "$EXTERNALIP" == "172.25.20.99" -o "$EXTERNALIP" == "172.25.20.120" ]; then
	echo "upgrade ucpadvisor"
	HELM_UPGRADE_CMD+="--set global.timezoneconfig=$TIMEZONE "
	HELM_UPGRADE_CMD+="--create-namespace --namespace ucp --timeout 1500s"

	echo "${HELM_UPGRADE_CMD}"
	${HELM_UPGRADE_CMD}
else
	echo "install ucpadvisor"
	#uninstall existing helm releases
	helm uninstall cert-manager -n cert-manager
	helm uninstall prometheus-stack -n monitoring
	helm uninstall triangulum -n ucp
	helm uninstall ucpadvisor -n ucp

	removeCRDs "ucp.hitachivantara.com"
	removeCRDs "monitoring.coreos.com"
	removeCRDs "configuration.konghq.com"

	#delete all in namespaces
	for NAMESPACE in "ucp" "monitoring" "cert-manager" "kong"
	do
		echo "delete all pods in $NAMESPACE namespace" 
		kubectl delete pods -n $NAMESPACE --force --timeout 20s || true
		echo "delete all configmaps in $NAMESPACE namespace" 
		kubectl delete configmap --all -n $NAMESPACE   --timeout 20s || true
		echo "delete all secrets in $NAMESPACE namespace" 
		kubectl delete secrets --all -n $NAMESPACE --timeout 20s || true
		echo "delete all services in $NAMESPACE namespace" 
		kubectl delete services --all -n $NAMESPACE  --timeout 20s || true
		echo "delete all deployments,statefulset in $NAMESPACE namespace " 
		kubectl delete deployments --all -n $NAMESPACE  --timeout 20s || true
		kubectl delete statefulsets --all -n $NAMESPACE  --timeout 20s || true
		echo "delete all role and rolebindings in $NAMESPACE namespace " 
		kubectl delete role,rolebinding --all -n $NAMESPACE   --timeout 20s || true
		echo "delete events in $NAMESPACE namespace" 
		kubectl delete --ignore-not-found=true events --all -n $NAMESPACE --timeout 20s || true
		echo "delete jobs in $NAMESPACE namespace" 
		kubectl delete job --all -n $NAMESPACE --force --timeout 20s || true
		echo "delete serviceaccounts in $NAMESPACE namespace" 
		kubectl delete serviceaccount --all -n $NAMESPACE --timeout 20s || true
		echo "delete pvcs in $NAMESPACE namespace" 
		kubectl delete pvc --all -n $NAMESPACE --force --timeout 90s || true

	done

	echo "delete kube-prometheus" 
	kubectl delete --ignore-not-found=true -f third-party/kube-prometheus/manifests/  --timeout 20s || true
	kubectl delete --ignore-not-found=true -f third-party/kube-prometheus/manifests/setup   --timeout 20s || true
	echo "delete cert-manager" 
	kubectl delete --ignore-not-found=true -f third-party/cert-manager/cert-manager.yaml   --timeout 20s || true

	# just in case there are leftovers, use timeout, status might say Terminating, but there are no resources underneath this namespace ucp

	echo "delete cluster role/binding"
	kubectl delete role cert-manager-cainjector:leaderelection -n kube-system
	kubectl delete role prometheus-k8s -n default
	kubectl delete role prometheus-k8s -n kube-system
	kubectl delete rolebinding prometheus-k8s -n default
	kubectl delete rolebinding prometheus-k8s -n kube-system
	for NAMESPACE in "default" "kube-system"
	do
		for NAME in "cert-manager" "prometheus" "kong" "ucpadmin" "ucpadvisor" "triangulum" 
		do
			roles=$(kubectl get role -n $NAMESPACE | grep -iF $NAME)
			for role in $roles
			do
				kubectl delete role $role -n $NAMESPACE
			done
			rolebindings=$(kubectl get rolebindings -n $NAMESPACE | grep -iF $NAME)
			for rolebinding in $rolebindings
			do
				kubectl delete rolebinding $rolebinding -n $NAMESPACE
			done
		done
	done

	kubectl delete podsecuritypolicy --all --timeout 60s || true
	kubectl delete pv --all --timeout 60s || true
	kubectl delete storageclass --all 2>/dev/null

	echo "delete cluster role and cluster role bindings"

	for NAME in "triangulum" "ucpadvisor" "ucpadmin" "ucp-advisor" "prometheus" "node-exporter" "cert-manager" "operator" "kong" "rbd-provisioner" "editor-role" "viewer-role" "metrics-reader" "proxy-role" "manager-role"
	do
		clusterroles=$(kubectl get clusterrole | grep -iF "$NAME")
		for clusterrole in $clusterroles
		do
			kubectl delete clusterrole $clusterrole 2>/dev/null
		done
		clusterrolebindings=$(kubectl get clusterrolebinding | grep -iF "$NAME")
		for clusterrolebinding in $clusterrolebindings
		do
			kubectl delete clusterrolebinding $clusterrolebinding 2>/dev/null
		done
		roles=$(kubectl get role -A | grep -iF "$NAME")
		for role in $roles
		do
			kubectl delete role $role 2>/dev/null
		done
		rolebindings=$(kubectl get rolebinding | grep -iF "$NAME")
		for rolebinding in $rolebindings
		do
			kubectl delete rolebinding $rolebinding 2>/dev/null
		done

	done

	kubectl delete MutatingWebhookConfiguration --all
	kubectl delete ValidatingWebhookConfiguration --all
	kubectl delete svc triangulum-kube-prometheus-kubelet -n kube-system
	#create and permission folders
	mkdir -p /var/ucpadvisor/bundle/logs/operator
	chmod 777 /var/ucpadvisor/bundle/logs/operator
	mkdir -p /var/ucpadvisor/prometheus-0
	chmod 777 /var/ucpadvisor/prometheus-0
	mkdir -p /var/ucpadvisor/prometheus-1
	chmod 777 /var/ucpadvisor/prometheus-1
	chmod -R 777 /var/ucpadvisor
	touch /home/keycloak-post-install-job.log
	touch /home/service-validation.log
	chmod 777 /home/keycloak-post-install-job.log
	chmod 777 /home/service-validation.log
	rm -rf /home/keycloak-db/*

	NAMESPACE="ucp"
	DOMAIN="ucp.hitachivantara.com"

	echo "Check if any CRDS remaining in domain $DOMAIN"
	CRDS=($(kubectl api-resources --verbs=list --namespaced -o name | grep -iF "$DOMAIN"))
	if  [ ${#CRDS[@]} -gt 0 ]
	then
		echo "Not all crds in domain $DOMAIN are removed"
		exit 1
	fi

	kubectl delete namespace ucp --timeout 5s || true
	sleep 5
	function delete_namespace () {
		echo "Deleting namespace $1"
		kubectl get namespace $1 -o json > tmp.json
		sed -i 's/"kubernetes"//g' tmp.json
		kubectl replace --raw "/api/v1/namespaces/$1/finalize" -f ./tmp.json
		rm ./tmp.json
	}

	TERMINATING_NS=$(kubectl get ns | awk '$2=="Terminating" {print $1}')

	for ns in $TERMINATING_NS
	do
		delete_namespace $ns
	done
	systemctl disable rpcbind.service rpcbind.socket
	systemctl stop rpcbind.service rpcbind.socket
	echo "install ucpadvisor"
	HELM_INSTALL_CMD+="--set global.timezoneconfig=$TIMEZONE "
	HELM_INSTALL_CMD+="--create-namespace --namespace ucp --timeout 1500s"

	echo "${HELM_INSTALL_CMD}"
	${HELM_INSTALL_CMD}

fi
