#!/bin/sh

# Install ingress-controller
curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml | kubectl apply -f -  

# Patch hostnetwork  
cat << EOF > patch.yml
spec:
  template:
    spec:
      hostNetwork: true
EOF

kubectl patch deployment ingress-nginx-controller --patch-file patch.yml -n ingress-nginx

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
# Install yum repo
cat << EOF > apache-values.yaml
service:
  type: ClusterIP
cloneHtdocsFromGit:
  enabled: true
  repository: "https://github.com/flytux/kubeadm-kb"
  branch: "main"
EOF

helm upgrade -i apache -f apache-values.yaml kubeadm/packages/apache-10.1.2.tgz -n apache --create-namespace
kubectl get secret docker-tls -n registry -o yaml | sed 's/name:.*/name: repo-tls/g' | sed '/namespace: /d' | kubectl apply -n apache -f -

cat << EOF > apache-ingress.yaml
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

kubectl apply -f apache-ingress.yaml

