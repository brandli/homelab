#setup.sh
kubectl apply -k .

#enable time slicing of GPU to have 4 GPUs available
kubectl patch clusterpolicies.nvidia.com/cluster-policy     -n gpu-operator-resources --type merge     -p '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config", "default": "any"}}}}'

#setup ComfyUI
helm install jupyterhub comfyui-onprem-k8s/charts/jupyterhub --namespace comfyui --set ingress.enabled=false

#setup MLflow
helm repo add mlops-for-all https://mlops-for-all.github.io/helm-charts
helm repo update
helm install mlflow-server mlops-for-all/mlflow-server -f helm/mlflow-values.yaml --namespace mlflow-system
kubectl patch svc mlflow-server-service -n mlflow-system -p '{"spec": {"type": "NodePort", "ports": [{"port": 5000, "nodePort": 30500}]}}'

#setup SLURM cluster
bash slurm-k8s-cluster/start-cluster.sh

#If of interest: Option to host Flyte
#helm upgrade flyte-binary flyteorg/flyte-binary --install --values helm/flyte-values.yaml -n flyte