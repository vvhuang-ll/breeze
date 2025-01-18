#! /bin/bash

set -e

path=`dirname $0`

k8s_version=`cat ${path}/components-version.txt |grep "Kubernetes" |awk '{print $3}'`

podman run --rm --name=kubeadm-version wise2c/kubeadm-version:v${k8s_version} kubeadm config images list --kubernetes-version ${k8s_version} > ${path}/k8s-images-list.txt

echo "=== pulling kubernetes images ==="
for IMAGES in $(cat ${path}/k8s-images-list.txt |grep -v etcd); do
  podman pull ${IMAGES}
done
echo "=== kubernetes images are pulled successfully ==="

echo "=== saving kubernetes images ==="
mkdir -p ${path}/file
rm -f ${path}/file/k8s-*.tar.bz2

for IMAGES in $(cat ${path}/k8s-images-list.txt |grep -v etcd); do
  image_name=$(echo ${IMAGES} | sed 's/[\/:]/-/g')
  podman save ${IMAGES} -o ${path}/file/k8s-${image_name}.tar
  bzip2 -z --best ${path}/file/k8s-${image_name}.tar
done
echo "=== kubernetes images are saved successfully ==="

kubernetes_repo=`cat ${path}/k8s-images-list.txt |grep kube-apiserver |awk -F '/' '{print $1}'`
kubernetes_version=`cat ${path}/k8s-images-list.txt |grep kube-apiserver |awk -F ':' '{print $2}'`
dns_version=`cat ${path}/k8s-images-list.txt |grep coredns |awk -F ':' '{print $2}'`
pause_version=`cat ${path}/k8s-images-list.txt |grep pause |awk -F ':' '{print $2}'`

echo "" >> ${path}/inherent.yaml
echo "version: ${kubernetes_version}" >> ${path}/inherent.yaml

echo "" >> ${path}/yat/all.yml.gotmpl
echo "kubernetes_repo: ${kubernetes_repo}" >> ${path}/yat/all.yml.gotmpl
echo "kubernetes_version: ${kubernetes_version}" >> ${path}/yat/all.yml.gotmpl
echo "dns_version: ${dns_version}" >> ${path}/yat/all.yml.gotmpl
echo "pause_version: ${pause_version}" >> ${path}/yat/all.yml.gotmpl

flannel_repo="flannel"
flannel_version=v`cat ${path}/components-version.txt |grep "Flannel" |awk '{print $3}'`
flannel_cni_plugin_version=v`cat ${path}/components-version.txt |grep "flannel-cni-plugin" |awk '{print $3}'`

echo "flannel_repo: ${flannel_repo}" >> ${path}/yat/all.yml.gotmpl
echo "flannel_version: ${flannel_version}" >> ${path}/yat/all.yml.gotmpl
echo "flannel_cni_plugin_version: ${flannel_cni_plugin_version}" >> ${path}/yat/all.yml.gotmpl

curl -sSL https://raw.githubusercontent.com/coreos/flannel/${flannel_version}/Documentation/kube-flannel.yml \
   | sed -e "s,docker.io/flannel/,{{ registry_endpoint }}/{{ registry_project }}/,g" > ${path}/template/kube-flannel.yml.j2

echo "=== pulling flannel image ==="
podman pull ${flannel_repo}/flannel:${flannel_version}
podman pull ${flannel_repo}/flannel-cni-plugin:${flannel_cni_plugin_version}
echo "=== flannel image is pulled successfully ==="

echo "=== saving flannel image ==="
podman save ${flannel_repo}/flannel:${flannel_version} \
            ${flannel_repo}/flannel-cni-plugin:${flannel_cni_plugin_version} \
    > ${path}/file/flannel.tar
rm ${path}/file/flannel.tar.bz2 -f
bzip2 -z --best ${path}/file/flannel.tar
echo "=== flannel image is saved successfully ==="

export CPUArch=$(uname -m | awk '{ if ($1 == "x86_64") print ""; else if ($1 == "aarch64") print "-arm64"; else print $1 }')

calico_version=v`cat ${path}/components-version.txt |grep "Calico" |awk '{print $3}'`
echo "calico_version: ${calico_version}" >> ${path}/yat/all.yml.gotmpl
echo "=== downloading calico release package ==="
curl -L -o ${path}/file/calico-${calico_version}.tgz https://github.com/projectcalico/calico/releases/download/${calico_version}/release-${calico_version}.tgz
echo "=== calico release package is downloaded successfully ==="
tar zxf ${path}/file/calico-${calico_version}.tgz -C ${path}/file/
rm -f ${path}/file/calico-${calico_version}.tgz
mv ${path}/file/release-${calico_version} ${path}/file/calico
rm -rf ${path}/file/calico/bin
rm -rf ${path}/file/calico/images/*
podman pull calico/cni:${calico_version}${CPUArch}
podman tag calico/cni:${calico_version}${CPUArch} calico/cni:${calico_version}
podman save calico/cni:${calico_version} -o ${path}/file/calico/images/calico-cni.tar
podman pull calico/ctl:${calico_version}${CPUArch}
podman tag calico/ctl:${calico_version}${CPUArch} calico/ctl:${calico_version}
podman save calico/ctl:${calico_version} -o ${path}/file/calico/images/calico-ctl.tar
podman pull calico/node:${calico_version}${CPUArch}
podman tag calico/node:${calico_version}${CPUArch} calico/node:${calico_version}
podman save calico/node:${calico_version} -o ${path}/file/calico/images/calico-node.tar
podman pull calico/typha:${calico_version}${CPUArch}
podman tag calico/typha:${calico_version}${CPUArch} calico/typha:${calico_version}
podman save calico/typha:${calico_version} -o ${path}/file/calico/images/calico-typha.tar
podman pull calico/dikastes:${calico_version}${CPUArch}
podman tag calico/dikastes:${calico_version}${CPUArch} calico/dikastes:${calico_version}
podman save calico/dikastes:${calico_version} -o ${path}/file/calico/images/calico-dikastes.tar
podman pull calico/kube-controllers:${calico_version}${CPUArch}
podman tag calico/kube-controllers:${calico_version}${CPUArch} calico/kube-controllers:${calico_version}
podman save calico/kube-controllers:${calico_version} -o ${path}/file/calico/images/calico-kube-controllers.tar
podman pull calico/pod2daemon-flexvol:${calico_version}${CPUArch}
podman tag calico/pod2daemon-flexvol:${calico_version}${CPUArch} calico/pod2daemon-flexvol:${calico_version}
podman save calico/pod2daemon-flexvol:${calico_version} -o ${path}/file/calico/images/calico-pod2daemon-flexvol.tar
podman pull calico/flannel-migration-controller:${calico_version}${CPUArch}
podman tag calico/flannel-migration-controller:${calico_version}${CPUArch} calico/flannel-migration-controller:${calico_version}
podman save calico/flannel-migration-controller:${calico_version} -o ${path}/file/calico/images/calico-flannel-migration-controller.tar
echo "=== Compressing calico images ==="
bzip2 -z --best ${path}/file/calico/images/calico-cni.tar
bzip2 -z --best ${path}/file/calico/images/calico-ctl.tar
bzip2 -z --best ${path}/file/calico/images/calico-node.tar
bzip2 -z --best ${path}/file/calico/images/calico-typha.tar
bzip2 -z --best ${path}/file/calico/images/calico-dikastes.tar
bzip2 -z --best ${path}/file/calico/images/calico-kube-controllers.tar
bzip2 -z --best ${path}/file/calico/images/calico-pod2daemon-flexvol.tar
bzip2 -z --best ${path}/file/calico/images/calico-flannel-migration-controller.tar
echo "=== Calico images are compressed as bzip format successfully ==="



metrics_server_repo=${kubernetes_repo}
metrics_server_version=v`cat ${path}/components-version.txt |grep "MetricsServer" |awk '{print $3}'`

echo "metrics_server_repo: ${metrics_server_repo}" >> ${path}/yat/all.yml.gotmpl
echo "metrics_server_version: ${metrics_server_version}" >> ${path}/yat/all.yml.gotmpl



echo "=== pulling  metrics-server images ==="
podman pull ${metrics_server_repo}/metrics-server/metrics-server:${metrics_server_version}
echo "=== kubernetes metrics-server images are pulled successfully ==="

echo "=== saving kubernetes dashboard images ==="
podman save ${metrics_server_repo}/metrics-server/metrics-server:${metrics_server_version} -o ${path}/file/metrics-server.tar
rm -f ${path}/file/dashboard.tar.bz2
rm -f ${path}/file/metrics-scraper.tar.bz2
rm -f ${path}/file/metrics-server.tar.bz2
bzip2 -z --best ${path}/file/metrics-server.tar

echo "=== kubernetes dashboard and metrics-server images are saved successfully ==="

export CPUArch=$(uname -m | awk '{ if ($1 == "x86_64") print "amd64"; else if ($1 == "aarch64") print "arm64"; else print $1 }')

echo "=== download cfssl tools ==="
export CFSSL_VERSION=1.6.4
export CFSSL_URL=https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}
curl -L -o cfssl ${CFSSL_URL}/cfssl_${CFSSL_VERSION}_linux_${CPUArch}
curl -L -o cfssljson ${CFSSL_URL}/cfssljson_${CFSSL_VERSION}_linux_${CPUArch}
curl -L -o cfssl-certinfo ${CFSSL_URL}/cfssl-certinfo_${CFSSL_VERSION}_linux_${CPUArch}
chmod +x cfssl cfssljson cfssl-certinfo
tar zcvf ${path}/file/cfssl-tools.tar.gz cfssl cfssl-certinfo cfssljson
echo "=== cfssl tools is download successfully ==="

helm_version=v`cat ${path}/components-version.txt |grep "Helm" |awk '{print $3}'`

echo "=== download helm binary package ==="
rm ${path}/file/helm-linux-${CPUArch}.tar.gz -f
curl -o ${path}/file/helm-linux.tar.gz https://get.helm.sh/helm-${helm_version}-linux-${CPUArch}.tar.gz
echo "=== helm binary package is saved successfully ==="
