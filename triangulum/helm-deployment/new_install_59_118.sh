wget  https://repo.sc.eng.hitachivantara.com/artifactory/triangulum-helm-dev-sc
trgbuild=`cat triangulum-helm-dev-sc | egrep ucpadvisor | cut -d" " -f 2 | grep -Eo '[0-9]+' | sort -rn | head -n 1`
echo "Latest Triangulum Build is "$trgbuild


kubectl label node kubeslave120 app=ucp --overwrite


./unInstall-and-deploy.sh --package=ucpadvisor-v4.0.0.dev-$trgbuild.tgz \
--externalIP=172.25.59.118 \
--secondaryExternalIP=172.25.59.121 \
--licensingServerIP=172.25.59.118 \
--gatewayRootPassword=Passw0rd! \
--defaultGateway=172.25.59.118 \
--cmds=sdb,sdc

rm triangulum-helm-dev-sc -f

