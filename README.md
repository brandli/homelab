# AI HOMELAB

If you have a GPU in your desktop computer at home and you want to play with it to "do some AI" (image generation, coding, chat bot, training neural networks), this setup is for you. All of this for free (assuming you have a domain name).

The "AI Homelab" is an assemblage of some of the latest AI frameworks out there. Feel free to comment any part that you are not interested in. All of the apps are hosted on kubernetes ("k8s") so the learning curve is a bit steep initially but once you get the hang of it, k8s is very convenient.

- **Hello-World** test server to see if the setup is working correctly.  
- **Guacamole** server to access the homelab server from anywhere with only a browser
- **Ollama** instance serving LLMs (Meta Llama, deepseek R1, ...) to a web UI for local purposes (e.g. Continue)
- **OpenWebUI** as chatbot web user interface for the ollama instance
- **Automatic 1111** for image genertion using stable diffusion
- **ComfyUI** for fancy generative AI image creation using stable diffusion (web UI for jupyter notebooks also included)
- **Cloudflare Tunnel** to protect your web UIs (Guacamole, ComfyUI, OpenWebUI)
- **SLURM** cluster to train machine learning models
- **MLflow** server for experiment tracking and model management
- **MinIO** object storage (e.g. to act as remote for DVC)
- **Flyte** workflow orchestration engine for reproducible and scalable machine learning experiments (currently commented out) 

The k8s cluster is configured such that the storage is provided with a NAS.

## Installation

### microk8s

1. Follow these instructions to install microk8s: https://microk8s.io/

   Should you get post-installation warnings (e.g. because you have Docker installed), follow the provided instructions:

    ```bash
    WARNING:  IPtables FORWARD policy is DROP. Consider enabling traffic forwarding with: sudo iptables -P FORWARD ACCEPT 
    The change can be made persistent with: sudo apt-get install iptables-persistent
    WARNING:  Docker is installed. 
    Add the following lines to /etc/docker/daemon.json: 
    {
        "insecure-registries" : ["localhost:32000"] 
    }
    and then restart docker with: sudo systemctl restart docker
    WARNING:  Maximum number of inotify user watches is less than the recommended value of 1048576. 
        Increase the limit with: 
            echo fs.inotify.max_user_watches=1048576 | sudo tee -a /etc/sysctl.conf
            sudo sysctl --system
    ```
2. Install kubectl: `sudo snap install kubectl --classic` and also install helm: `sudo snap install helm --classic`
3. Enable community addons using: `sudo microk8s enable community`
4. Enable addons additional addons (with the above command): dashboard, ingress, hostpath-storage
5. Enable old Nvidia GPU addon (new one seems broken): microk8s enable gpu --version v24.3.0
6. Add the config of microk8s to the kubernetes config: https://microk8s.io/docs/working-with-kubectl
7. To enable data storage of your cluster on the NAS, you should enable NFS mounting of PVC: https://microk8s.io/docs/how-to-nfs (should you chose not not use NFS storage, you should update the storageClassName in the yaml files from "nfs-csi" to "microk8s-hostpath" such that the persistent volumes are provided by the local host machine)
8. To avoid frequent dashboard timeouts, follow https://stackoverflow.com/questions/58012223/how-can-i-make-the-automatic-timed-logout-longer 

### Local Networking

k8s services are published on nodeports (30000-32767). To allow access on the host machine on the default ports for other applications (ollama, ..), the according ports need to be forwarded with socat services. Forwarding k8s ports can also be achieved with the "kubectl port-forward" but it is not persistent and does not survive a reboot. The more elegant way would be to use a load balancer (for microk8s MetalLB) and/or an ingress controller but this has not yet been implemented.

1. Copy the files under /systemd to /usr/lib/systemd/system
2. Enable the services using `sudo systemctl enable k8-np-xxx.service` (do this for all services, replacing "xxx" with the according name from the files you copied)
3. Start the services using `sudo systemctl start k8-np-xxx.service`
4. Some ports need to be allowed in the local firewall such that they can be accessed in the local network: `sudo ufw allow 9031/tcp`

### Port Mapping

Once you are done with the port forwarding, the setup should looks a follows:

| Service           | Cluster Port  | Local Port    | Network Port |
|-------------------|---------------|---------------|--------------|
| RDP               |-              |3389           |3389          |
| web test          |8080           |30080          |-             |  
| guacd             |4822           |-              |-             |
| postgres (guac)   |5432           |-              |-             |
| Kubernetes API    |-              |6443           |-             |
| Ollama            |11434          |30303          |11434         |
| OpenWebUI         |8080           |30380          |-             |
| Automatic 1111    |7860           |30333          |-             |
| MinIO S3 (DVC)    |9000           |30990          |9030          |
| MLflow            |5000           |30500          |5000          |

If you want to check whether your cluster ports are the same and whether they are forwarded to the same NodePort ports, use `kubectl get svc -A`.

If you want to check whether a NodePort port (typically 30000-32767) is currently forwarded to another local port (e.g. for ollama to 11434), have a look the the currently running socat services `ps aux | grep socat | grep -v grep`.

If you want to see which ports are currently forwarded on your local machine (i.e. from your local IP e.g. 127.0.0.1 aka "localhost") to your network IP (e.g. "198.168.x.y") you can use `sudo netstat -tulpn`.

### Deployment

To deploy the homelab setup, execute the following steps (feel free to skip steps if not needed and comment the according lines in the kustomization.yaml):

1. If you plan to use SLURM, it is advisable to turn of hyperthreading in your BIOS.
2. It is also advisable to have a fixed IP in your network. Configure your network accordingly.
3. Copy and rename the file /manifest/sc-nfs-template.yaml to manifest/sc-nfs.yaml. Edit the file to point to the right NAS server IP and folder address. Make sure your user has enough permissions on the NFS server.
4. Copy and rename the file /manifest/cloudflare-secret-template.yaml to manifest/cloudflare-secret.yaml. Go to cloudflare.com, create and account. Head to Zero Trust -> Network -> Tunnels. Create new "cloudflared" tunnel. Head to "Docker" and copy the token. run `echo 'your_token' | base64`. Paste it into cloudflare secret file (replace 'your_token') as one long string.
5. Make sure you have xrdp running. Copy and rename the file /manifest/guacamole-secret-template.yaml to manifest/guacamole-secret.yaml. Create a password e.g. using `openssl rand -base64 16` and add it to the secret file (the username is base64 for "guacamole").
6. Spin the cluster up: `bash setup.sh`
7. Test the services and change the admin password where necessary.

### Web Hosting (Tunnel)

Be careful when exposing your services to the internet.

1. Log into your cloudflare account (the one you used to setup cloudflared). Register a domain.
2. Go to Zero Trust and under Access Policies, create a new rule e.g. use Github as authentication method and add a rule to only include users from a given Github organization.
3. For each service you want to expose, create an Application and configure it with the right login method and the previously created policy.
4. Under Network -> Tunnels go to the tunnel you created for cloudflared and add a public hostname for each service you want to expose (with the according Subdomain and domain). As service you should chose `service-name.namespace.svc.cluster.local:XXX` where XXX is the port on which the service is publish in the cluster (replace service-name and namespace as per your setup). **Make sure you open "Additional application settings" and under "Access" you select "Protect with Access" and then you chose the application you created before.**

## How To Use

### Code from anywhere With Guacamole

If you want to code or work on your machine from anywhere (your phone, a tablet, ...) without the need to install any software, just visit the domain at the exit of your guacamole tunnel (e.g. http: guacamole.my-server.com pointing to `http://guacamole.guacamole.svc.cluster.local:80`), set up 2FA, change the admin password, the set up a connection:

== EDIT CONNECTION ==

- Protocol: RDP

== PARAMETERS ==

- Hostname: IP of the host machine in the network
- Port: 3389
- Security mode: any
- Ignore server certificate: yes
- Resize method: "Display Update"

Go back to the "Home" menu and connect using your newly set up connection.

### AI Chatbot App with OpenWebUI and Ollama

Visit the domain at theend of the tunnel pointing to `http://open-webui-service.open-webui.svc.cluster.local:8080` or `http:localhost:30380`. Set up an account. And configure the UI. If you visit the domain on a smartphone, you can create a desktop shortcut which will make it appear as an app.

### AI Coding with Ollama

Install a VS Code plugin (e.g. Continue, Cline) and configure them to use the ollama port: `localhost:11434`

### AI Image Generation With A111 (Stable DIffusion)

The service can be found on: `http:localhost:30333` or if you set up a tunnel: `http://automatic1111-service.a1111.svc.cluster.local:7860`.

### AI Image Generation With ComfyUI (Stable DIffusion)

The service is currently not exposed to a NodePort, so it should be accessed via tunnel: `http://proxy-public.comfyui.svc.cluster.local:80`. Select a GPU server and in the jupyter environment you can then select the ComfyUI setup.

### AI Model Training on SLURM Cluster

Generate a SSH key:

```bash
kubectl exec -n slurm $(kubectl get pods -n slurm -l app.kubernetes.io/component=login -o name | head -1) -- cat /home/rocky/.ssh/id_rsa > ~/slurm-key && chmod 600 ~/slurm-key
```

Once you have the key in your home folder, you can log in using:

```bash
ssh rocky@127.0.0.1 -p 31100 -i ~/slurm-key
```

To check if everything works well, type: `sinfo`

### AI Model Training With MLflow

To track parameters in your experiment, use the following python code (make sure you replace the IP of your host computer)

```python
import mlflow

MLFLOW_TRACKING_URI = "http://XXX.XXX.X.XXX:5000"
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)

```

For further usage, have a look at the MLflow documentation here <https://www.mlflow.org/docs/>

To see the tracked experiments, visit localhost:5000

### AI Dataset Managment With DVC

To set up a DVC "remote" hosted in your MinIO instance, use

```bash
dvc init

dvc remote add -d minio s3://dvc/path/to/store/data \
    --endpointurl http://XXX.XXX.X.XXX:9030 \
    --access-key-id minio \
    --secret-access-key minio123
```

## To Do

- Configure port forwarding with MetalLB and/or ingress controller.
- Fix orphaned ollama/a1111 pods after cluster reboot.

## References

This Project is based on (including without limitation):

- <https://github.com/jwetzell/docker-guacamole>
- <https://github.com/Curt-Park/comfyui-onprem-k8s>
- <https://github.com/stackhpc/slurm-k8s-cluster>
- <https://github.com/ai-dock/stable-diffusion-webui/issues/25>
- <https://github.com/davidmirror-ops/flyte-the-hard-way/>
