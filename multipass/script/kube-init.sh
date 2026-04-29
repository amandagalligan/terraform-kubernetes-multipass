#!/bin/bash
echo "*** Waiting for Cloud-Init to finish ***"
cloud-init status --wait
echo "*** Kubernetes Pulling Images:"
kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock
echo "*** Kubernetes Initializing:"
export LOCAL_IP=$(hostname -I | awk '{print $1}')
export HAPROXY_IP=$(cat /tmp/haproxy_ip)
kubeadm init \
  --upload-certs \
  --pod-network-cidr 10.244.0.0/16 \
  --apiserver-advertise-address $LOCAL_IP \
  --control-plane-endpoint $HAPROXY_IP:6443 \
  --cri-socket unix:///var/run/cri-dockerd.sock | tee /tmp/kubeadm.log
echo "*** Installing Calico:"
# export K8S_VERSION="$(kubectl version | base64 | tr -d '\n')"
# export WEAVE_URL="https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml"
# kubectl apply -f "$WEAVE_URL"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/tigera-operator.yaml
echo "*** Waiting for tigera-operator to be ready..."
kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=300s || true
sleep 5
echo "*** Downloading and configuring custom resources:"
wget -q https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/custom-resources.yaml || { echo "Failed to download custom-resources.yaml"; exit 1; }
sed -i -e 's,cidr: 192.168.0.0/16,cidr: 10.244.0.0/16,' custom-resources.yaml
echo "*** Creating Calico custom resources/CRD:"
for attempt in {1..5}; do
  echo "Attempt $attempt to create custom resources..."
  if kubectl create -f custom-resources.yaml 2>&1; then
    echo "Custom resources created successfully"
    break
  else
    if [ $attempt -lt 5 ]; then
      echo "Waiting for operator webhooks to be ready..."
      sleep 10
    fi
  fi
done
echo "*** Waiting for Kubernetes to get ready:"
STATE="NotReady"
WAIT_TIME=0
MAX_WAIT=600
while test "$STATE" != "Ready" -a $WAIT_TIME -lt $MAX_WAIT ; do
  STATE=$(kubectl get node | tail -1 | awk '{print $2}')
  echo -n "." ; sleep 2
  WAIT_TIME=$((WAIT_TIME + 2))
done
echo ""
if [ $WAIT_TIME -ge $MAX_WAIT ]; then
  echo "WARNING: Node did not reach Ready state within timeout"
fi
echo "*** Waiting for Calico components to be ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n calico-system --timeout=300s || true
kubectl wait --for=condition=ready pod -l k8s-app=calico-typha -n calico-system --timeout=300s || true
if grep "kubeadm join" /tmp/kubeadm.log >/dev/null; then
  echo -n '{"join":"'$(kubeadm token create --ttl 0 --print-join-command)'"}' > /etc/join.json
  kubeadm init phase upload-certs --upload-certs --one-output | tail -1 > cert_id.txt
  echo -n '{"join":"'$(kubeadm token create --ttl 0 --certificate-key $(cat cert_id.txt) --print-join-command)'"}' > /etc/join-master.json
fi
sleep 10
echo "*** Bind API to 0.0.0.0 address:"
sed -i -e 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-scheduler.yaml
sed -i -e 's/host: 127.0.0.1/host: 0.0.0.0/' /etc/kubernetes/manifests/kube-scheduler.yaml
sed -i -e 's/127.0.0.1:2381/0.0.0.0:2381/' /etc/kubernetes/manifests/etcd.yaml
sed -i -e 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/' /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -i -e 's/host: 127.0.0.1/host: 0.0.0.0/' /etc/kubernetes/manifests/kube-controller-manager.yaml
echo "*** Sleep 90s"
sleep 90
