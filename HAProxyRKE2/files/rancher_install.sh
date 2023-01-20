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

echo "Modify ingress controller to use-forwarded-headers"
cat << EOF > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-ingress-nginx
  namespace: kube-system
spec:
  valuesContent: |-
    controller:
      config:
        use-forwarded-headers: "true"
EOF

echo "Install stable Rancher chart"
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
/var/lib/rancher/rke2/bin/kubectl create namespace cattle-system
/var/lib/rancher/rke2/bin/kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem=/tmp/cacerts.pem
# Modify hostname and bootstrap password if needed
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.your.domain \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=secret \
  --set tls=external \
  --set additionalTrustedCAs=true \
  --set privateCA=true

/var/lib/rancher/rke2/bin/kubectl -n cattle-system create secret generic tls-ca-additional --from-file=ca-additional.pem=/tmp/cacerts.pem

echo "Wait for Rancher deployment rollout"
/var/lib/rancher/rke2/bin/kubectl -n cattle-system rollout status deploy/rancher
