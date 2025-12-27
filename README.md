We have used nginx as a reverse proxy through which we access the kibana dashboard.

For the compose files within docker, the kibana, elastic search and logstash have not been exposed to the internet. Hence we have avoided usage of ports: and used expose: instead for these services
Only nginx is exposed to the internet so ports: is only used for nginx.

In the compose files within the swarm, folder we have used ports: only for nginx and for others
we have completely skipped ports: and expose:
This is because all containers within the swarm cluster communicate via the overlay network,
there is no need to specify any ports for services not exposed to the internet. They run
on their default ports.

The compose files within the docker folder are used when you are running all the microservices, whose
logs require processing within the same server as the elk.
Simple docker compose does not allow communication between containers running on different servers.
So for a very simple, single server deployment for all microservices, elk and gateway containers,
docker compose is useful. So we can keep 2 servers for seperating the environments: 1 server for dev and other for prod. 

Docker swarm is required for communicating between containrts running on different servers.
A swarm cluster is created for the servers, where apps are deployed i.e the worker nodes and the also
the servers where apps can be deployed but preferably should not atleast in production env. It does the job of managing the worker nodes alone and assigning tasks to them. Its the manager node.
The server acting as the manager node initialises a swarm cluster. You can have multiple managers for
a swarm cluster. Then we add multiple worker nodes to the cluster.

In swarm deployment, we never ssh into the worker nodes for any app deployment.
The required compose files are copied to the manager node, the manager node creates the deployment stack,
assigns task to the worker nodes based on the placement constraints we have given.
The apps will run in the worker nodes only but deployment of apps will be done by the manager node.
Also we will access the manager node DNS to access the worker node apps. We never expose the apps running
in the worker node via the worker node DNS.

Any shared config eg: nginx config files are shared between the nodes using Configs.
Any shared secrets eg: ssl certificates and keys are shared between the nodes using Secrets.
This ensures we dont need to copy anything into the worker nodes.
We just need to have everything in the manager node. It can be shared with the worker nodes via
configs and secrets.

When you run `docker stack deploy` in a Swarm cluster, the **manager node** is the brain that orchestrates everything. Here’s what happens step by step:

## 🔎 Role of the Manager Node During `docker stack deploy`

1. **Parse the Compose file(s)**  
   - The manager reads your `docker-compose.stack.yml` (and any overrides).  
   - It expands environment variables, validates syntax, and builds a service specification.

2. **Create Swarm objects**  
   - For each declared resource, the manager creates corresponding Swarm objects in the Raft database:  
     - **Services** (with desired replicas, image, env vars, configs, secrets, networks, volumes).  
     - **Configs and secrets** (stored in Raft, encrypted if secrets).  
     - **Networks** (overlay networks spanning nodes).  
     - **Volumes** (if defined at Swarm level).

3. **Schedule tasks**  
   - The manager decides which worker node(s) should run each service task.  
   - It uses placement constraints (`node.labels.role == worker3` in your case), resource limits, and availability.  
   - It then issues task assignments to workers.

4. **Distribute configs/secrets**  
   - Configs and secrets are only sent to nodes that run tasks needing them.  
   - Secrets are encrypted in Raft and delivered securely to containers via `/run/secrets/...`.  
   - Configs are delivered as plaintext files.

5. **Monitor and reconcile state**  
   - The manager continuously watches the cluster.  
   - If a container crashes, it reschedules a replacement task.  
   - If a node goes down, it reassigns tasks to other nodes.  
   - It enforces the desired state defined in your stack file.

6. **Networking setup**  
   - The manager ensures overlay networks are created and connected across nodes.  
   - It configures the routing mesh so published ports are accessible cluster‑wide.

---

## ✅ Key Insight
The manager node doesn’t run your services (unless it’s also a worker), but it **owns the control plane**:
- Parses and validates your stack spec.  
- Stores configs/secrets/networks in Raft.  
- Schedules tasks to workers.  
- Keeps the cluster in sync with the declared desired state.



# Logging in Microservices

Challenges of logging in microservices:
1. distributed in nature: Need to locate in which microservice the issue is occuring.
2. log correlation
3. high volume
4. centralisation and management

What is observability ?

Ability to understand the internal state of the system by examining the outputs.
This is possible using logs,metrics, alerts and traces.

Popular logging libraries:

1. winston
2. pino
3. morgan
4. bunyan
5. log4js

Logging Levels:

1. Fatal: Fatal errors can bring the entire app down
2. Error: error in app  that is fatal only for the current operation but the rest of the app continues to function
3. Warning:potential issues but app works
4. info: important details like startup,shutdown
5. debug: state of the app for debugging
6. trace: most detailed logging level. It is used to find the specific place where the error has occured.


Log formats:
1. Unstructured: not recommended. eg: common and combined log format
2. Structured: most recommended. eg: json,xml,key-value pair
3. semi-strucutured

Best Practices

1. Use log levels effectively
2. use structured json
3. use iso-8601 timestamps
4. standardise context like include eventId, microservice name, file detaild, method name, line no etc
5. use correlation id and stack traces
6. be selective for privacy and compliance. do not log sensitive information.

We are using winston + morgan in the microservices project and the gateway project to append the log messages to files. These files are then picked by Filebeat and sent to the ELK stack.

# ELK
The ELK Stack works by using Beats or Logstash to collect data from various sources, Logstash to process and transform it, Elasticsearch to index and store the data, and Kibana to visualize and analyze it through dashboards and charts. Essentially, data is gathered, sent to Elasticsearch for analysis, and then displayed in Kibana for monitoring and troubleshooting purposes.

So each of the microservices and the gateways have the filebeat to collect the log messages. Filebeat will send the log messages to logstash,
which in turn will send it to elastic search. Kibana provides a visual display.

Elastic provides official Docker images for Elasticsearch, Logstash, and Kibana. These images contain the necessary software and dependencies for each component.

# Running in docker

Better not to run these locally with docker desktop because they consume lot of memory and docker
dekstop hangs.

```
docker compose -p elk -f docker-compose.yml build

docker compose -p elk -f docker-compose.yml  up -d --remove-orphans --no-build

```

- Kibana: [http://localhost:5601](http://localhost:5601)
- Elasticsearch: [http://localhost:9200](http://localhost:9200)
- LogStash is listening on 5000 and 5001.

It is important that ElasticSearch is healthy before Kibana starts. Hence you will see a depends-on:
in the kibana service.
If you feel Elastic search keep restarting and there is no specific error, it could be related to
shortage of memory. So you can increase the memory constraints in the compose file so that more
memory can be used in its startup.


# Logstash

Logstash is the gateway to centralised logging system

Ways of injesting logs:

1. direct transport: directly sending the logs to elastic search

2. file: write the logs to a file. logstash/filebeat then picks up the file, parses them and sends them to elastic search

We are using the 2nd method, where filebeat picks the logs from the file, sends to logstash, which in turn sends to elastic search.

Logstash pipeline is configured using a yml file. It has 3 main sections: input, filter and output

The Logstash configuration is defined in the [`logstash.conf`](./logstash/logstash.conf) file. This configuration listens for Filebeat input on port `5001` and TCP input on port `5000`, and sends the logs to Elasticsearch.

Observe the index field. It picks up the service_name field from the logs. Recall that this has been added to log message for each microservice.
This helps to differentiate between the logs of different microservices and gateways.

```
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    # index => "app-%{+YYYY.MM.dd}"
    index => "%{[service_name]}-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}


```

Hit localhost:5601 to access the Kibana dashboard.

![Alt text](documentation/image.png)

On the RHS, go to Stack Management ---> Index Management.

![Alt text](documentation/image-1.png)

You can see an index for every microservice

![Alt text](documentation/image-2.png)

Click on discover index

![Alt text](documentation/image-3.png)

You can find the logs for that index

![Alt text](documentation/image-4.png)

Check how github actions works from other README.md of other microservices repo

# Docker Swarm Configs and Secrets

**You should use Docker Swarm configs whenever you need to distribute non‑sensitive configuration files (like Nginx templates, app configs, YAMLs) across nodes, instead of relying on bind mounts. They are best used when the same config must be available consistently on all nodes, and they are injected into containers at runtime.**

---

## 🔎 What Docker Swarm Configs Are
- **Configs** are objects managed by Swarm that store text files (JSON, YAML, conf, etc.).  
- They are similar to **secrets**, but intended for non‑sensitive data.  
- Swarm automatically distributes configs to the nodes running your service.  
- Inside the container, configs appear as files at the path you specify.

---

## ✅ When to Use Configs
- **Nginx/HAProxy templates**: Instead of bind mounting `/home/.../nginx.conf`, store it as a config.  
- **Application configs**: JSON/YAML files that define service behavior.  
- **Cluster‑wide configs**: Anything that must be identical across nodes.  
- **Avoiding invalid mounts**: When bind mounts fail because files don’t exist on worker nodes.  

Configs are **not for sensitive data** (use secrets for certs, private keys, passwords).

Since nginx is acting as reverse proxy for elk, it will receive all client requests.
The stack compose files and nginx config files are copied to the manager node to deploy the stack.

When the worker node tries to run the container, it requires these nginx config files as well.
So a better approach would be to use swarm configs to distribute such data that multiple
nodes require, instead of copying the nginx config files to every node that requires it.

In docker-compose.stack.yml, I have defined 2 configs for nginx for 2 environments.
We are seperating dev and prod using different stack names and different overlay networks.
So 2 different env cannot use the same config because the data in the nginx config file will be
different for different env.

The configs: field must be defined in the same level as services:
We provide the swarm config's name and the file to be used as the source file. 
The file path you provide here will be the manager node's path. This is because during
deployment, you will be copying the compose stack files, env files and nginx config files
to the manager node.
Swarm Config is a way for the manager node to distribute the required configuration data to the required
node.

```
configs:
     nginx_conf_dev:
       file: /home/${VM_USER}/${APPNAME}/nginx/nginx.dev.conf
     nginx_conf_prod:
       file: /home/${VM_USER}/${APPNAME}/nginx/nginx.prod.conf

```

You can access it in the docker service that requires it. For example, in the docker-compose.stack.prod.override.yml, I have referenced the nginx_conf_prod swarm config as you see below
In the source field, I have provided the swarm config name and in the target, I have provided the 
path in the container, where the configuration file will be accessed. This means the content of 
/home/${VM_USER}/${APPNAME}/nginx/nginx.prod.conf in the manager node appears as the content of 
/etc/nginx/templates/default.conf.template in the nginx container in the worker3 node.It’s read‑only by default.
If I had to use volumes instead of swarm configs, I had to ssh into the worker3 node and copy the
nginx config file, which is totally not required.

```
 nginx:
     environment:
      - NGINX_PORT=8700
     configs: 
         - source: nginx_conf_prod
           target: /etc/nginx/templates/default.conf.template
     secrets:
      - source: ssl_cert
        target: /etc/nginx/ssl/live/${AZURE_VM_DOMAIN}/fullchain.pem
      - source: ssl_key
        target: /etc/nginx/ssl/live/${AZURE_VM_DOMAIN}/privkey.pem
     ports: 
        - 8700:8700
     networks:
         - shared-swarm-net-prod

```

Take docker-compose.stack.dev.override.yml as another example, where I have referenced the nginx_conf_dev
swarm config. This means the content of /home/${VM_USER}/${APPNAME}/nginx/nginx.dev.conf in the manager
node appears as the content of /etc/nginx/templates/default.conf.template in the nginx container in the
worker3 node.It’s read‑only by default.

```
nginx:
     environment:
      - NGINX_PORT=8600
     configs: 
         - source: nginx_conf_dev
           target: /etc/nginx/templates/default.conf.template
     ports: 
         - 8600:8600
     networks:
         - shared-swarm-net-dev

```

These swarm configs will be created when you execute the deploy stack command. Below are
the commands for inspecting the configs created from the manager node.

 **Inspect configs**
   ```bash
   docker config ls
   docker config inspect nginx_conf
   ```

 **Inside the container in the worker3 node**
   - The config file will appear at `/etc/nginx/templates/default.conf.template`. The content will
   change based on the environment i.e the stack name  
   - It is **read‑only** by default.


## ⚖️ Benefits vs Bind Mounts

| **Aspect**            | **Bind Mounts**                          | **Configs**                                |
|------------------------|------------------------------------------|--------------------------------------------|
| Node dependency        | File must exist on every node            | Swarm distributes automatically            |
| Portability            | Brittle (path must match)                | Portable across nodes                      |
| Security               | Can expose sensitive files accidentally  | Intended for non‑sensitive configs         |
| Mutability             | Can be changed on host                   | Immutable once deployed (update via redeploy) |
| Best use case          | Local dev, one‑node setups               | Production, multi‑node Swarm clusters      |


## ⚠️ Risks & Trade‑offs
- **Immutable**: You can’t edit configs in place; you must create a new config and redeploy.  
- **Not for secrets**: Don’t store certs/keys here — use `docker secret`.  
- **Read‑only**: Apps can’t modify configs at runtime.  


## 🔎 Difference Between Swarm Configs and Secrets
- **Configs**:  
  - Designed for non‑sensitive data (templates, config files).  
  - Stored in Swarm’s Raft database in **plaintext**.  
  - Distributed to nodes as regular files, readable by any container that mounts them.  
- **Secrets**:  
  - Designed for sensitive data (passwords, private keys, certificates).  
  - Stored encrypted in the Raft database.  
  - Only delivered to containers that explicitly request them.  
  - Mounted in memory‑backed filesystems (`/run/secrets/...`), not persisted to disk.


## ✅ Best Practice for SSL Certificates
- **Private keys** (e.g. `server.key`) → **must be stored as Swarm secrets**.  
  - They are sensitive and must be encrypted at rest.  
- **Public certificates** (e.g. `server.crt`, intermediate CA chain) → can be stored as **configs** or **secrets**, depending on your security posture.  
  - Many teams still store them as secrets for consistency, even though they’re not confidential.  


## ⚠️ Why Not Use Configs for Keys
If you put private keys in configs:
- They’re stored unencrypted in the Raft database.  
- Any container with access to configs can read them.  
- This violates security best practices and may fail compliance checks.


We required ssl certificates for nginx container when accessing the kibana dashboard in the prod
environment. We again face the same issue of the certificates installed in the manager node but the
nginx container running in the worker3 node, which actually requires the certificates but has none.

For ssl certificates, we will go for swarm secrets instead of swarm configs because the data involved is
more sensitive. We will store the certificate file and key as a swarm secret which can be distributed
securely by the manager node to other nodes.

SSL certificates are required only in the prod environment. So i have defined the secrets only in the
docker-compose.stack.prod.override.yml. 
Note that we used certbot to request the certificates in the manager node and they were stored in the
location "/etc/letsencrypt/live". But you cannot directly access certificates from this location
due to permission issues.

Thus in the swarm-deploy.yml file, prior to "deploy stack", we have copied the certificates from the
above location to /home/${{ env.VM_USER }}/${{vars.APP_NAME}}/certs and given read-write permissions
on the .pem files.

```
 TARGET_DIR="/home/${{ env.VM_USER }}/${{vars.APP_NAME}}/certs" 
 # Create the directory if it doesn't exist 
 sudo mkdir -p "$TARGET_DIR" 
 sudo cp "/etc/letsencrypt/live/${{env.VM_DOMAIN}}/fullchain.pem" "$TARGET_DIR/fullchain.pem"
 sudo cp "/etc/letsencrypt/live/${{env.VM_DOMAIN}}/privkey.pem" "$TARGET_DIR/privkey.pem"
 sudo chmod 644 "$TARGET_DIR"/*.pem
```
In the secrets: in the ocker-compose.stack.prod.override.yml, we have defined 2 secrets with names:
ssl_cert and ssl_key. It could be any name. The file path is the path to the certificate and key on 
the manager node.

```
secrets:
     ssl_cert:
       file: /home/${VM_USER}/${APPNAME}/certs/fullchain.pem
     ssl_key:
       file: /home/${VM_USER}/${APPNAME}/certs/privkey.pem


```

We have accessed these secrets within the same file in the nginx service as below.
The source will be the secret name and the target will be the location in the nginx container
in the worker3 node, where the certificate/key needs to be available.
```
 nginx:
     environment:
      - NGINX_PORT=8700
     configs: 
         - source: nginx_conf_prod
           target: /etc/nginx/templates/default.conf.template
     secrets:
      - source: ssl_cert
        target: /etc/nginx/ssl/live/${AZURE_VM_DOMAIN}/fullchain.pem
      - source: ssl_key
        target: /etc/nginx/ssl/live/${AZURE_VM_DOMAIN}/privkey.pem
     ports: 
        - 8700:8700
     networks:
         - shared-swarm-net-prod

```

We have referenced these target locations again in the nginx.prod.conf file as below.
```
 ssl_certificate     /etc/nginx/ssl/live/${AZURE_VM_DOMAIN}/fullchain.pem;
 ssl_certificate_key /etc/nginx/ssl/live/${AZURE_VM_DOMAIN}/privkey.pem;

```

### How does DNS work ?

## 🔎 How It Works
- **Azure DNS**: You’ve configured DNS records for all nodes (manager + workers). Each node has a public DNS name that resolves to its IP.
- **Swarm routing mesh**: When you publish a port in a Swarm service (`listen 8600;` in your Nginx config), Swarm automatically sets up a routing mesh. That means any node in the cluster (manager or worker) will accept traffic on that published port and forward it internally to the node where the service task is actually running.
- **Result**: Even though Nginx is running on a worker node, if you hit the manager node’s DNS on the published port, Swarm forwards the request to the worker node where Nginx is active.

## ✅ Practical Example
Suppose:
- Worker node DNS: `worker1.cloudapp.azure.com`
- Manager node DNS: `manager.cloudapp.azure.com`
- Nginx service published on port `8600` and port opened on firewall in both nodes.

You can reach Kibana through either:
```
http://worker1.cloudapp.azure.com:8600/
http://manager.cloudapp.azure.com:8600/
```

Both will work, because Swarm’s routing mesh forwards traffic from the manager node to the worker node where Nginx is running.

So yes, with Swarm’s default routing mesh, you can access the reverse proxy via the manager node’s DNS even though the container is running on a worker.  


## 🔎 Why access only via manager node's DNS and not expose worker node ?
 If you open inbound ports on every worker, you’re increasing the attack surface unnecessarily. Since the routing mesh already forwards traffic, you only need to expose the port on one entry point.
In Azure, it’s common to expose only the manager node (or a load balancer fronting the cluster) to the internet. Workers stay behind the scenes, reachable only through the overlay network.

## ✅ Recommended Pattern
- **Open inbound firewall ports only on the manager node (or load balancer)**.  
- **Keep worker nodes closed to direct inbound traffic** — they’ll still receive traffic internally via Swarm’s routing mesh.  
- **Set `server_name` in Nginx to the external DNS that clients use** (manager DNS or load balancer DNS).  

This means if a nginx container is running in worker3 on port 8600 to receive browser request to open
kibana dashboard,then not just worker3, but any of other worker nodes or manager
nodes DNS can be used to receive this request. The only pre-requisute is that port 8600
must be open on worker3 node or that particular worker node or manager node's firewall.

The best practice is that the worker nodes should not be exposed and the manager node DNS alone should
be used to receive requests.
So just open port 8600 or whatever the port no is on the manager node firewall.
And use the manager node DNS to navigate to kibana dashboard.
Set the server_name to the manager node DNS name in nginx config file
The manager node will forward the requests to the nginx container listening on port 8600 in 
worker3 node to handle the request.

So although nginx reverse proxy for elk is running in a worker node, the manager node can also
recieve requests and forward it to the worker node.
This is also the best practice.

This ensures all client requests are received only by the manager node and forwarded to the
worker node running the nginx container for elk.
