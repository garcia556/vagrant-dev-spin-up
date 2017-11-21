#!/bin/bash

HOSTS="/etc/hosts"
VBM="VBoxManage"

V_FILE="Vagrantfile"
V_IMAGE="ubuntu/xenial64"
V_PROVIDER="virtualbox"

NW_FILE="_tmp_nw"
NS_FILE="_tmp_ns"

SED=sed
if [ "$(uname)" == "Darwin" ]; then
	SED="g${SED}"
fi

###################################

function cleanup()
{
	rm -f ${NW_FILE}
	rm -f ${NS_FILE}
}

###################################

cleanup

if [ ! -x "$(which ${VBM})" ]; then
	echo "VirtualBox is not found"
	exit 5
fi

# checking status if Vagrantfile exists
if [ -f $V_FILE ]; then
	# checking if Vagrant machine does exist
	exists=$(vagrant status | grep --color=never default | grep -v "provider will be shown" | grep -v "not created")
	if [ "${exists}" != "" ]; then
		echo "VM is created already"
		exit 10
	fi
fi

# ask for image
read -p "Enter image [${V_IMAGE}]: " image
if [ "${image}" == "" ]; then
	image="${V_IMAGE}"
fi

# ask for provider
read -p "Enter provider [${V_PROVIDER}]: " provider
if [ "${provider}" == "" ]; then
	provider="${V_PROVIDER}"
fi

# ask for name
read -p "Enter machine name: " name
if [ "${name}" == "" ]; then
	echo "Name not set"
	exit 20
fi

# save networks
${VBM} list hostonlyifs									\
	| grep --color=never "IPAddress"					\
	| cut -d ":" -f 2									\
	| awk '{ $1=$1; print substr($1, 1, length($1)-1)}'	\
	>> ${NW_FILE}

# save hosts
touch ${NS_FILE}
for nw in $(cat ${NW_FILE}); do
	cat ${HOSTS} | grep ${nw} | grep -v "#${nw}" >> ${NS_FILE}
done

echo ""
echo "VirtualBox host-only networks available:"
cat ${NW_FILE}
echo ""
echo "Hosts configured:"
cat ${NS_FILE}
echo ""

# ask for hostname
read -p "Enter VM hostname: " host
if [ "${host}" == "" ]; then
	echo "Host not set"
	exit 30
fi

# checking hostname is in hosts already
res="ok"
for ns in $(cat ${NS_FILE} | tr \\t ' ' | awk '{$1=$1;print}' | cut -d ' ' -f 2); do
	if [ "${host}" == "${ns}" ]; then
		res=""
	fi
done

if [ "${res}" == "" ]; then
	echo "Hostname already exists in ${HOSTS}"
	cleanup
	exit 40
fi

# ask for IP address
read -p "Enter VM IP address: " ip
if [ "${ip}" == "" ]; then
	echo "IP not set"
	cleanup
	exit 50
fi

# checking IP address against networks
res=""
for nw in $(cat ${NW_FILE}); do
	res=$(echo ${ip} | grep "${nw}")
done

if [ "${res}" == "" ]; then
	echo "No corresponding networks found"
	cleanup
	exit 60
fi

# checking IP address is in hosts already
res="ok"
for ns in $(cat ${NS_FILE} | tr \\t ' ' | awk '{$1=$1;print}' | cut -d ' ' -f 1); do
	if [ "${ip}" == "${ns}" ]; then
		res=""
	fi
done

if [ "${res}" == "" ]; then
	echo "IP address already exists in ${HOSTS}"
	cleanup
	exit 70
fi

cleanup

# ask for comment
read -p "Enter comment []: " comment

# append line to hosts
line="${ip} ${host}"
if [ "${comment}" != "" ]; then
	line="${line} # ${comment}"
fi

echo "Creating hosts file backup ..."
sudo cp ${HOSTS} ${HOSTS}.bak
echo "Adding new record to ${HOSTS}: \"${line}\" ..."
sudo -- sh -c "echo \"${line}\" >> ${HOSTS}"

# prepare Vagrantfile
rm -rf ${V_FILE}
cp ${V_FILE}.template ${V_FILE}

echo "Generating ${V_FILE} ..."

# escale slash
image=$(echo ${image} | ${SED} 's/\//\\\//g')

${SED} -i "s/__image__/${image}/g"			${V_FILE}
${SED} -i "s/__provider__/${provider}/g"	${V_FILE}
${SED} -i "s/__name__/${name}/g"			${V_FILE}
${SED} -i "s/__host__/${host}/g"			${V_FILE}
${SED} -i "s/__ip__/${ip}/g"				${V_FILE}

echo "Spinning up ..."

# run machine
vagrant plugin install vagrant-disksize
vagrant --force destroy
VM_HOSTNAME=${host} vagrant up --provider=${provider}

vagrant status
vagrant port

echo "Deleting host keys ..."
ssh-keygen -R ${host}
ssh-keygen -R ${ip}

sleep 3

echo "Adding host key ..."
ssh-keyscan -t ecdsa-sha2-nistp256 ${host} 2>&1 | grep -v OpenSSH >> ~/.ssh/known_hosts
ssh-keyscan -t ecdsa-sha2-nistp256   ${ip} 2>&1 | grep -v OpenSSH >> ~/.ssh/known_hosts

#vagrant ssh
#vagrant ssh -- -t 'cd /var/www; /bin/bash'

