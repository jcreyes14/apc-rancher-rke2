#!/bin/bash
echo "Create ~/.kube"
mkdir -p /root/.kube

echo "Grab kubeconfig"
while [ ! -f /etc/rancher/rke2/rke2.yaml ]
do
  echo "waiting for kubeconfig"
  sleep 2 
done

echo "Put kubeconfig to /root/.kube/config"
cp -a /etc/rancher/rke2/rke2.yaml /root/.kube/config

echo "Wait for nodes to come online"
i=0
echo "i have $i nodes"
while [ $i -le 2 ]
do
  i=`/var/lib/rancher/rke2/bin/kubectl get nodes | grep Ready | wc -l`
  echo I have: $i nodes
  sleep 2s
done

echo "Wait for complete deployment of node three, 30 seconds"
sleep 30

echo "Install helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

echo "Add Repo jetstack & Install Cert-Manager"
helm repo add jetstack https://charts.jetstack.io
/var/lib/rancher/rke2/bin/kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.crds.yaml
# Change version if needed
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.8.2

echo "Install stable Rancher chart"
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# Modify hostname and bootstrap password if needed
helm install rancher rancher-stable/rancher \
  --namespace cattle-system --create-namespace \
  --set hostname=rancher.your.domain \
  --set bootstrapPassword=admin

echo "Wait for Rancher deplotment rollout"
/var/lib/rancher/rke2/bin/kubectl -n cattle-system rollout status deploy/rancher
