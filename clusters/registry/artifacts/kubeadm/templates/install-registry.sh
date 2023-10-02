#!/bin/sh

# Install ingress-controller
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml | kubectl apply -f -  

# Patch hostnetwork  
cat << EOF > patch.yaml
spec:
  template:
    spec:
      hostNetwork: true
EOF

kubectl patch deployment ingress-nginx-controller --patch-file patch.yaml -n ingress-nginx

# Install storage class as default
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Generate registry certs

cp kubeadm/certs/* /etc/pki/ca-trust/source/anchors/
update-ca-trust

echo "${registry_ip}  ${registry_domain}" >> /etc/hosts

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
    - ${registry_domain}
  tls:
    - secretName: docker-tls
      hosts:
        - ${registry_domain}
  annotations: 
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
persistence:
  accessMode: 'ReadWriteOnce'
  enabled: true
  size: 5Gi
EOF
# Install registry 
#helm repo add twuni https://helm.twun.io
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
helm upgrade -i docker-registry -f registry-values.yaml kubeadm/packages/docker-registry-2.2.2.tgz -n registry  


# Install minio s3 storage
cat << EOF > minio-values.yaml
mode: standalone
rootUser: "minio"
rootPassword: "minio123"
resources:
  requests:
    memory: 256Mi
persistence:
  enabled: true
  storageClass: "local-path"
  accessMode: ReadWriteOnce
  size: 1Gi
consoleIngress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  path: /
  hosts:
    - minio-console.kw01
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  path: /
  hosts:
    - minio.kw01
users:
  ## make sure to disable this if you are using LDAP.
  - accessKey: console
    secretKey: console123
    policy: consoleAdmin
buckets:
  - name: kubeadm
EOF

kubectl create ns apache

helm upgrade -i minio -f minio-values.yaml kubeadm/packages/minio-5.0.14.tgz -n apache

mc config host add minio http://minio.kw01 minio minio123

# Copy yum repo packages to minio
createrepo kubeadm/packages
mc cp --recursive kubeadm/packages minio/kubeadm

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
      - name: minio
        persistentVolumeClaim:
          claimName: minio
      containers:
      - args:
        - rm -rf /app/*; cp -r /minio/kubeadm/* /app
        command:
        - /bin/sh
        - -c
        image: docker.io/bash
        name: bash
        volumeMounts:
        - mountPath: /app
          name: apache-repo
        - mountPath: /minio
          name: minio
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

kubectl apply -f repo-setup.yaml

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
  tls:
  - hosts:
    - repo.kw01
    secretName: repo-tls
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
EOF

kubectl apply -f nginx-ingress.yaml
