#!/usr/bin/env bash
set -xe
OS=$(awk -F= '/^ID=/ { print $2 }' /etc/os-release | tr -d '"')
if [[ $OS == ubuntu ]]; then
  source ubuntu_install_requirements.sh
else
  source centos_install_requirements.sh
fi

# if ! which minikube 2>/dev/null ; then
#     curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
#     chmod +x minikube
#     sudo mv minikube /usr/local/bin/.
# fi

# if ! which docker-machine-driver-kvm2 2>/dev/null ; then
#     curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2
#     chmod +x docker-machine-driver-kvm2
#     sudo mv docker-machine-driver-kvm2 /usr/local/bin/.
# fi

# Install kinder to replace minikube
eval $(go env)
if [ ! -d ~/go/src/kubeadm ]; then
  pushd ~/go/src/
  git clone https://github.com/kubernetes/kubeadm.git
  pushd kubeadm
  git checkout e90d3a7a43d7196b3e2c22e26cfa8a6e80c0e012
  popd
  popd
fi

if [ ! -d ~/go/src/sigs.k8s.io/kind ]; then
  GO111MODULE="on" go get -u sigs.k8s.io/kind@v0.4.0
fi

if [ ! -f ~/go/bin/kinder ]; then
  pushd $HOME/go/src/kubeadm/kinder
  GO111MODULE=on go install
  popd
fi

sudo docker pull kindest/node:v1.15.0

if [[ $(cat ~/.bashrc) != *go/bin* ]]; then
  echo 'export PATH=$GOPATH/bin:$PATH' >> ~/.bashrc
fi
if [[ $PATH != *go/bin*  ]]; then
  export PATH=$GOPATH/bin:$PATH 
fi

if ! which kubectl 2>/dev/null ; then
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/.
fi

if ! which kustomize 2>/dev/null ; then
    curl -Lo kustomize $(curl --silent -L https://github.com/kubernetes-sigs/kustomize/releases/latest 2>&1 | awk -F'"' '/linux_amd64/ { print "https://github.com"$2; exit }')
    chmod +x kustomize
    sudo mv kustomize /usr/local/bin/.
fi

# Download Ironic binary and Ironic inspector image

mkdir -p "$IRONIC_DATA_DIR/html/images"
pushd "$IRONIC_DATA_DIR/html/images"
if [ ! -f ironic-python-agent.initramfs ]; then
    curl --insecure --compressed -L https://images.rdoproject.org/master/rdo_trunk/current-tripleo-rdo/ironic-python-agent.tar | tar -xf -
fi

for IMAGE_VAR in IRONIC_IMAGE IRONIC_INSPECTOR_IMAGE ; do
    IMAGE=${!IMAGE_VAR}
    sudo "${CONTAINER_RUNTIME}" pull "$IMAGE"
done

## Download centos 7 qcow2 image

CENTOS_IMAGE=CentOS-7-x86_64-GenericCloud-1901.qcow2
if [ ! -f ${CENTOS_IMAGE} ] ; then
    curl --insecure --compressed -O -L http://cloud.centos.org/centos/7/images/${CENTOS_IMAGE}
    md5sum ${CENTOS_IMAGE} | awk '{print $1}' > ${CENTOS_IMAGE}.md5sum
fi
popd

ANSIBLE_FORCE_COLOR=true ansible-playbook \
  -e "working_dir=$WORKING_DIR" \
  -e "virthost=$HOSTNAME" \
  -i vm-setup/inventory.ini \
  -b -vvv vm-setup/libvirt-package-playbook.yml
