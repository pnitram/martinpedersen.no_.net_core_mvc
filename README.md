
# Build and push image to azure container registry
az acr build --registry $acrname --image $imagename --file Dockerfile .

# Get Helm and deploy certmanager
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 <br>
chmod 700 get_helm.sh <br>
./get_helm.sh <br>
helm repo add jetstack https://charts.jetstack.io <br>
helm repo update <br>
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

# Install kubectl-cert_manager plugin locally
curl -L -o kubectl-cert-manager.tar.gz https://github.com/jetstack/cert-manager/releases/latest/download/kubectl-cert_manager-linux-amd64.tar.gz <br>
tar xzf kubectl-cert-manager.tar.gz <br>
sudo mv kubectl-cert_manager /usr/local/bin <br>

# Install cmtl locally
curl -L -o cmctl.tar.gz https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cmctl-linux-amd64.tar.gz <br>
tar xzf cmctl.tar.gz <br>
sudo mv cmctl /usr/local/bin <br>

# Deploy nginx ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx <br>
helm repo update <br>
helm install ingress-controller ingress-nginx/ingress-nginx <br>

# Create letsencrypt config

# Create letsencrypt config for stage/testing 
vim letsencrypt-staging.yaml
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: email@address.com
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
      - http01:
          ingress:
            class: nginx
```

# Create letsencrypt config for production 
vim letsencrypt-production.yaml
```yaml
piVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: email@address.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
```
# Apply certificate configuration 
kubectl create -f letsencrypt-production.yaml

# Create confguration for deployment
vim martinpedersenno.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: martinpedersenno
  labels:
    app: martinpedersenno
spec:
  replicas: 2
  selector:
    matchLabels:
      app: martinpedersenno
  template:
    metadata:
      labels:
        app: martinpedersenno
    spec:
      containers:
      - name: martinpedersenno
        image: "PATH TO IMAGE:v1"
        imagePullPolicy: IfNotPresent
        resources: {}
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 3
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: martinpedersenno
  labels:
    app: martinpedersenno
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 5000
  selector:
    app: martinpedersenno
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: martinpedersenno
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  rules:
    - host: martinpedersen.no
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: martinpedersenno
                port:
                  number: 80
  tls:
    - hosts:
      - martinpedersen.no
      secretName: tls-prod-cert
```

# Deploy the solution
kubectl apply -f martinpedersenno.yaml -n homepage

