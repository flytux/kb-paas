# Install internal registry for air-gapped cluster

- install nginx ingress controller
- install local-path storage class
- install self-signed ca crt / key
- install docker registry with ingress
- config ca certificate to cluster's containerd runtime

**1) install nginx ingress controller**
- use host port 80/443

```bash
helm upgrade -i ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f values.yaml
```
**2) install storage class**

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml 
```

**3) generate registry cert / key**

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout registry.key -out registry.crt \
  -subj "/CN=docker.kw01" -addext "subjectAltName=DNS:docker.kw01,DNS:*.kw01,IP:10.10.10.101"
```

**4) copy registry cert, key to containerd**

```bash
scp registry.* registry:/etc/pki/ca-trust/source/anchors/
ssh registry

mkdir -p /etc/containerd
cat << EOF >> /etc/containerd/config.toml
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
   [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
	[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
	  runtime_type = "io.containerd.runc.v2"
	  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
	    SystemdCgroup = true
      [plugins."io.containerd.grpc.v1.cri".registry]
	[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
	  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.kw01"]
	    endpoint = ["https://docker.kw01"]
	    [plugins."io.containerd.grpc.v1.cri".registry.configs."docker.kw01".tls]
	      ca_file = "/etc/pki/ca-trust/source/anchors/registry.crt"
	      cert_file = "/etc/pki/ca-trust/source/anchors/registry.crt"
	      key_file = "/etc/pki/ca-trust/source/anchors/registry.key"
EOF
systemctl restart containerd
```

**5) create secret, chart values**

```bash
kubectl create ns registry
kubectl create secret tls docker-tls -n registry --cert=registry.crt --key=registry.key

cat << EOF >> values.yaml
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
persistence:
  accessMode: 'ReadWriteOnce'
  enabled: false
  size: 5Gi
EOF
```

**6) install helm chart**

```bash
helm repo add twuni https://helm.twun.io
helm upgrade -i docker-registry -f values.yaml twuni/docker-registry -n registry

kubectl edit ing docker-registry -n registry

add annotion to ingress => nginx.ingress.kubernetes.io/proxy-body-size: "0"
```
