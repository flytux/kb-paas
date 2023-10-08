#!/bin/sh

# Install ingress-controller
kubectl apply -f kubeadm/kubernetes/config/nginx-deploy.yaml 

# Patch hostnetwork  
cat << EOF > patch.yaml
spec:
  template:
    spec:
      hostNetwork: true
EOF

kubectl patch deployment ingress-nginx-controller --patch-file patch.yaml -n ingress-nginx

# Install storage class as default
kubectl apply -f kubeadm/kubernetes/config/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Generate registry certs

cp kubeadm/certs/* /etc/pki/ca-trust/source/anchors/
update-ca-trust

echo "10.10.10.101  docker.kw01" >> /etc/hosts

# Create secret certs
kubectl create ns registry
kubectl create secret tls docker-tls -n registry --cert=kubeadm/certs/registry.crt --key=kubeadm/certs/registry.key

# Create registry values
cat << EOF > registry-values.yaml
ingress:
  enabled: true
  className: nginx
  path: /
  hosts:
    - docker.kw01
  tls:
    - secretName: docker-tls
      hosts:
        - docker.kw01
  annotations: 
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
persistence:
  accessMode: 'ReadWriteOnce'
  enabled: true
  size: 5Gi
EOF
# Install registry 
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
while !  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s ; do echo please waits for nginx-ingress up; sleep 5; done

helm upgrade -i docker-registry -f registry-values.yaml kubeadm/packages/docker-registry-2.2.2.tgz -n registry  


# Copy packages
kubectl create ns apache
createrepo kubeadm/packages

cat << EOF > repo-setup.yaml
---
apiVersion: batch/v1
kind: Job
metadata:
  namespace: apache
  name: repo-copy
  labels:
    app: repo-copy
spec:
  template:
    metadata:
      name: repo-copy
    spec:
      restartPolicy: OnFailure
      volumes:
      - name: apache-repo
        persistentVolumeClaim:
          claimName: pvc-apache-repo
      - name: packages
        hostPath:
          path: /root/kubeadm/packages
      containers:
      - args:
        - rm -rf /app/*; mkdir -p /app/repo; cp -r /packages/* /app/repo
        command:
        - /bin/sh
        - -c
        image: bash
        imagePullPolicy: IfNotPresent
        name: bash
        volumeMounts:
        - mountPath: /app
          name: apache-repo
        - mountPath: /packages
          name: packages
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-apache-repo
  namespace: apache
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f repo-setup.yaml -n apache

kubectl wait --for=condition=complete job/repo-copy -n apache

# Install yum repo
cat << EOF > apache-values.yaml
service:
  type: ClusterIP
htdocsPVC: pvc-apache-repo

EOF

helm upgrade -i apache -f apache-values.yaml kubeadm/packages/apache-10.1.2.tgz -n apache

kubectl get secret docker-tls -n registry -o yaml | sed 's/name:.*/name: repo-tls/g' | sed '/namespace: /d' | kubectl apply -n apache -f -

cat << EOF > nginx-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: repo
  namespace: apache
spec:
  ingressClassName: nginx
  rules:
  - host: repo.kw01
    http:
      paths:
      - backend:
          service:
            name: apache
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - repo.kw01
    secretName: repo-tls
EOF

kubectl apply -f nginx-ingress.yaml

# Tag and push images
nerdctl tag bash:latest docker.kw01/bash:latest
nerdctl tag bitnami/git:2.42.0-debian-11-r26 docker.kw01/bitnami/git:2.42.0-debian-11-r26
nerdctl tag bitnami/apache:2.4.57-debian-11-r163 docker.kw01/bitnami/apache:2.4.57-debian-11-r163
nerdctl tag registry.k8s.io/kube-apiserver:v1.27.6 docker.kw01/kube-apiserver:v1.27.6
nerdctl tag registry.k8s.io/kube-proxy:v1.27.6 docker.kw01/kube-proxy:v1.27.6
nerdctl tag registry.k8s.io/kube-scheduler:v1.27.6 docker.kw01/kube-scheduler:v1.27.6
nerdctl tag registry.k8s.io/kube-controller-manager:v1.27.6 docker.kw01/kube-controller-manager:v1.27.6
nerdctl tag registry.k8s.io/kube-apiserver:v1.26.8 docker.kw01/kube-apiserver:v1.26.8
nerdctl tag registry.k8s.io/kube-controller-manager:v1.26.8 docker.kw01/kube-controller-manager:v1.26.8
nerdctl tag registry.k8s.io/kube-scheduler:v1.26.8  docker.kw01/kube-scheduler:v1.26.8
nerdctl tag registry.k8s.io/kube-proxy:v1.26.8  docker.kw01/kube-proxy:v1.26.8
nerdctl tag busybox:latest  docker.kw01/busybox:latest
nerdctl tag registry:2.8.1  docker.kw01/registry:2.8.1
nerdctl tag rancher/local-path-provisioner:v0.0.24  docker.kw01/rancher/local-path-provisioner:v0.0.24
nerdctl tag registry.k8s.io/coredns/coredns:v1.10.1  docker.kw01/coredns:v1.10.1
nerdctl tag registry.k8s.io/etcd:3.5.7-0  docker.kw01/etcd:3.5.7-0
nerdctl tag registry.k8s.io/etcd:3.5.6-0  docker.kw01/etcd:3.5.6-0
nerdctl tag registry.k8s.io/pause:3.9  docker.kw01/pause:3.9
nerdctl tag haproxy:2.3  docker.kw01/haproxy:2.3
nerdctl tag registry.k8s.io/coredns/coredns:v1.9.3  docker.kw01/coredns:v1.9.3

nerdctl push docker.kw01/bash:latest
nerdctl push docker.kw01/bitnami/git:2.42.0-debian-11-r26
nerdctl push docker.kw01/bitnami/apache:2.4.57-debian-11-r163
nerdctl push docker.kw01/kube-apiserver:v1.27.6
nerdctl push docker.kw01/kube-proxy:v1.27.6
nerdctl push docker.kw01/kube-scheduler:v1.27.6
nerdctl push docker.kw01/kube-controller-manager:v1.27.6
nerdctl push docker.kw01/kube-apiserver:v1.26.8
nerdctl push docker.kw01/kube-controller-manager:v1.26.8
nerdctl push docker.kw01/kube-scheduler:v1.26.8
nerdctl push docker.kw01/kube-proxy:v1.26.8
nerdctl push docker.kw01/busybox:latest
nerdctl push docker.kw01/registry:2.8.1
nerdctl push docker.kw01/rancher/local-path-provisioner:v0.0.24
nerdctl push docker.kw01/coredns:v1.10.1
nerdctl push docker.kw01/etcd:3.5.7-0
nerdctl push docker.kw01/etcd:3.5.6-0
nerdctl push docker.kw01/pause:3.9
nerdctl push docker.kw01/haproxy:2.3
nerdctl push docker.kw01/coredns:v1.9.3
