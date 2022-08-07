This site is created with ASP.NET Core MVC, packaged in a Docker container and deployed in Azure Kubernetes Service (AKS).

# Build and push image to azure container registry
```bash
az acr build --registry $acrname --image $imagename --file Dockerfile .
```
# Get Helm and deploy certmanager
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true
```

# Install kubectl-cert_manager plugin locally
```bash
curl -L -o kubectl-cert-manager.tar.gz https://github.com/jetstack/cert-manager/releases/latest/download/kubectl-cert_manager-linux-amd64.tar.gz
tar xzf kubectl-cert-manager.tar.gz
sudo mv kubectl-cert_manager /usr/local/bin
```
# Install cmtl locally
```bash
curl -L -o cmctl.tar.gz https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cmctl-linux-amd64.tar.gz
tar xzf cmctl.tar.gz
sudo mv cmctl /usr/local/bin
```
# Deploy nginx ingress controller
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-controller ingress-nginx/ingress-nginx
```
# Create letsencrypt config

# Create letsencrypt config for stage/testing 
```bash
vim letsencrypt-staging.yaml
```
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
```bash
vim letsencrypt-production.yaml
```
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
```bash
kubectl create -f letsencrypt-production.yaml
```

# Create configuration for deployment
```bash
vim martinpedersenno.yaml
```
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
```bash
kubectl apply -f martinpedersenno.yaml -n homepage
```

# To deploy as Azure containerapp instead:

az containerapp create \
  --name mpwebsite \
  --resource-group MPwebsiteRG \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --registry-server mpwebsiteacr.azurecr.io \
  --image mpwebsiteacr.azurecr.io/martinpedersen.no:v2.0 \
  --registry-username abcde --registry-password abcde  \
  --target-port 5000 \
  --ingress 'external' \
  --query properties.configuration.ingress.fqdn

