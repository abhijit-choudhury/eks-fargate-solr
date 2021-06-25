# Autoscale SolrCloud setup on Kubernetes with Fargate

I was recently tasked to upgrade our current Solr version, and while discussing the SolrCloud setup someone interjected why don't we try running it using Containers. As interesting the thought was, which would definitely bring much needed resiliency to our current SolrCloud setup, it certainly seemed daunting (at first) to run stateful application such as Solr on Container Orchestration platform like Kubernetes.

So the journey begins,

## First Problem: Run SolrCloud on Kubernetes

Quick search landed me to Solr Operator currently under Apache Foundation, and I know operators are the best thing to automate deployments and manage workloads on K8s, but after playing around with it for some time, I realized the Solr Operator documentation still requires some work, and as I dived in further I felt that this may not be the right fit for me for now.

After looking through Google, I stumbled upon Bitnami Helm Chart (https://bitnami.com/stack/solr/helm), there may be other helm charts too. Helm is to K8s as NPM is to the Javascript world, anyways I started working with it and it worked like a charm, the below SolrCloud 8.8 cluster came up as a breeze with default configs.

Make sure your local K8s cluster is having free resources of atleast 3 CPU and 5GB of RAM, you would also need to checkout the repo @ https://github.com/abhijit-choudhury/eks-fargate-solr for yamls referenced here. Below deploys a StatefulSet for SolrCloud with 2 Solr servers and 3 Zookeepers

    helm repo add bitnami https://charts.bitnami.com/bitnami

    helm repo update

    helm install solr --set authentication.adminPassword=admin,replicaCount=2,javaMem=512m,heap=512m bitnami/solr

We would also need to setup an ingress to reach the Solr service which is running in ClusterIP mode. For this we would first need to install a Ingress controller e.g. nginx

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.46.0/deploy/static/provider/cloud/deploy.yaml

Check if ingress-nginx-controller pod gets installed correctly and is ready

    kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --watch

Deploy Ingress and wait a minute for hostname to populate

    kubectl apply -f local-ingress.yml

Get hostname using 

    echo $(kubectl get ingress solr-ingress -o jsonpath="{.status.loadBalancer.ingress[].hostname}")

It may take a few minutes, check if all pods are running healthy using below, once ready we should be able access SOLR on http://HOSTNAME/solr, login via admin/admin

    kubectl get pods --watch

## Deploy Project Specific Configs (Optional)

I have some project specific schema configs that is needed to be deployed, let's zip those configs and make sure they are compatible with Solr 8.8
    
    (cd project-configs/conf && zip -r - *) > project-configs.zip

Now let's push those configs to my-collection.AUTOCREATED configset (cloned from _default configset), note that configs can be pushed only when SolrCloud is running in authenticated mode, in unauthenticated mode the configs get uploaded as untrusted and doesn't apply

    curl -u admin:admin -X POST -H "Content-Type:application/octet-stream" --data-binary @project-configs.zip "http://HOSTNAME/solr/admin/configs?action=UPLOAD&name=my-collection.AUTOCREATED&overwrite=true"

Create any new collections with TLOG replicas and aliases as required, if needed reload the collections

    curl -u admin:admin "http://HOSTNAME/solr/admin/collections?action=CREATE&name=new-collection-name&numShards=1&tlogReplicas=2&maxShardsPerNode=1&collection.configName=my-collection.AUTOCREATED"
    
    curl -u admin:admin "http://HOSTNAME/solr/admin/collections?action=RELOAD&name=my-collection"

So now my SolrCloud is resilient and no longer someone needs wake up in the middle of the night to restart Solr or Zookeeper servers if anything went wrong.

## Second Problem: How do I scale my SolrCloud automatically

K8s only gives you the tools (Horizontal Pod Autoscaler, not discussing VPA here) to scale physical architecture (StatefulSets Replicas i.e. PODs and Persistence), but I also wanted to scale the logical architecture (i.e.Solr Nodes and Collection Replicas) as well. 

Meaning based on load I not only want to add more StatefulSet replicas, but also for each Solr node that is added to the SolrCloud cluster, I want to add 1 replica of each shard for every collection on the new Solr node

### Scaling Logical Architecture

Before we discuss autoscaling, I should highlight that SOLR 7 introduced 2 new replica types TLOG and PULL in addition to already existing default NRT type. TLOG and PULL replicas both don't index data locally rather they poll index segments from leader replica (which greatly improves performance for the entire cluster), but if the leader replica is behind authentication, TLOG or PULL replicas are unable to fetch those index segments. There is a bug (https://issues.apache.org/jira/browse/SOLR-11904) that is being tracked and it will be fixed in 8.9. This is not the case for NRT replicas, where the leader NRT replica pushes data to all other NRT replicas which again re-indexes locally

So we need to disable the authentication for the SolrCloud at this point, if you want to reapply configs you would need to revert below to true and once configs are installed set it back to false, just that in that interval TLOG/PULL replicas will continue to serve stale data. 

    curl -u admin:admin http://HOSTNAME/api/cluster/security/authentication -H 'Content-type:application/json' -d  '{"set-property": {"blockUnknown":false}}'

**You would need to secure the cluster now that all requests are unblocked**

Next we want to setup the SolrCloud cluster autoscaling policies as below, which will take care of scaling the Logical Architecture

    curl --location --request POST 'http://HOSTNAME/api/cluster/autoscaling' \
    --header 'Content-Type: text/plain' \
    --data-raw '{
    "set-trigger": {
        "name": "node_added_trigger",
        "event": "nodeAdded",
        "waitFor": "120s",
        "preferredOperation": "ADDREPLICA",
        "enabled": true,
        "replicaType": "PULL"
    },
    "set-trigger": {
        "name": "node_lost_trigger",
        "event": "nodeLost",
        "waitFor": "120s",
        "preferredOperation": "DELETENODE"
    },
    "set-cluster-policy": [
            {"replica": "1", "shard": "#EACH", "node": "#ANY"}
    ]
    }'

You can do a GET to the same URL to check if above got added. Above we are doing few interesting things

1. Adding a cluster wide policy to have/add 1 replica for each shard on any node

2. Adding a SOLR trigger to add PULL replica after 120s once a node is added.

3. Adding a SOLR trigger to delete the node after 120s once it is lost

If you want to dynamically add NRT replicas, then in above POST request ignore setting replicaType, as NRT is default type, and you can ignore setting blockUnknown to false and let the SolrCloud run in auth mode

### Scaling Physical Architecture

Now we want to focus on scaling the physical architecture, first thing we need is a metrics server (you can also track other SOLR metrics via Prometheus SOLR exporter, there is another flag in our helm chart refer documentation), but here we are just trying to scale based on memory utilization

Download Metrics Server yaml and update below to allow running it in insecure tls mode and apply it

    wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Update components.yaml as below for local only

    spec:
    containers:
    - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-insecure-tls                #### Add this new line ####

Deploy Metrics Server

    kubectl apply -f components.yaml

Once the metrics server pod is up and running in kube-system namespace, check if the metrics are coming up by below command

    kubectl top pods

Now we are all set to apply our Horizontal Pod Autoscaler

    kubectl apply -f hpa.yml

I'm using type: AverageValue as I want to check on actual values instead of working with percentages, use type: Utilization and averageUtilization if you want to test with percentages.

Also I could have run a load test on Solr to spike the memory utilization, but rather than that I updated the averageValue so low that it would start scaling as soon as HPA kicks in.

Run below and wait for a replica pod to be spawned and once its healthy and ready check Solr console for cloud nodes, a new Solr node will be added to the cluster, and roughly after 120s you would see a new replica added to the my-collection in graph view
    
    kubectl get pods --watch

And similarly for scaling down I re-applied the same hpa.yml with really high value like 100Gi, scaling down takes a little longer than scale up so have patience

## Reinstall Local SolrCloud with Custom Persistent Volumes

Now that I was able to run Solr on K8s and autoscale it, I decided to tweak things a little which will be needed when I plan to move things into cloud

Let's first delete the SolrCloud stack we created earlier

    helm delete solr

Delete the HPA as well else it will kick in during reinstallation is in progress

    kubectl delete -f hpa.yml

Let's set up persistent volumes to be used with our installation

1. Create 2 storage classes solr-storage and zookeeper-storage

2. Create 3 persistent volumes of type zookeeper-storage for the 3 Zookeepers

3. Depending on maximum number of replicas e.g. 3 configured in HPA, create as many persistent volumes of type solr-storage for Solr servers

4. Finally creating a storage class, persistent volume and persistent volume claim for Solr backup

    sh setup-local-storage.sh

    kubectl apply -f local-volumes.yml

Helm chart will take care of creating persistent volume claims and attaching them to the above created persistent volumes, but for this update helm values.yaml respectively with solr-storage, zookeeper-storage storage class names

And instead of passing parameters in commandline, you can customize the default config values for the helm installation in values.yml as well, and deploy using below, but here too I felt documentation could have been a little better with more examples, eventually figured it out. Updated the the values like Java Heap memory, K8s resource limits (THIS IS MUST), adminPassword, initial solr replica count, storage class names to be used for persistent volumes (this will make more sense when we setup on cloud)

    helm install solr -f local-values.yaml bitnami/solr

Once SolrCloud is up and running with 2 Solr nodes, check via console if default replicas are also all green in graph view

    kubectl get pods --watch

Re-apply authentication flag blockUnknown to false and autoscaling cluster policies as above. Also re-apply the HPA configured with averageValue as 10Mi

In a minute autoscaling kicks in, validate once again if new replica gets attached to my-collection in graph view

## Third Problem: Take SolrCloud setup to AWS

First thing we need is a K8s cluster, now AWS allows running EKS (Elastic Kubernetes Service) with managed nodes or using Fargate, 

Why choose Fargate, because HPA only allows autoscaling pods, but if your cluster doesn't have any more resources, pods will remain in pending state. And in most cases we would never provision a large cluster upfront, rather we depend on Cluster Autoscaler to scale out/in the K8s cluster as needed.

Fargate is the most awesome thing that makes our K8s cluster completely serverless, and we don't need to bother about cluster autoscaling as it can scale infinitely, so HPA never gets blocked due to resource constraints.

**BUT make sure you are configuring maxReplicas in HPA appropriately and setting up alerts else it will burn a hole in your pocket.**

Additionally until early last year Fargate was unable to run Stateful workloads, but then it announced EFS (also serverless) support in April and we had all the pieces to put up an awesome architecture, a big thanks to **Re Alvarez-Parmar** for guiding the way with his talks and blogs

### Home Stretch

Let's set up our EKS with Fargate, AWS CLI should be installed and configured correctly with proper credentials, also install eksctl

    SOLR_AWS_REGION=eu-west-1

    SOLR_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

    SOLR_EKS_CLUSTER=eks-fargate-solr

    eksctl create cluster \
    --name $SOLR_EKS_CLUSTER \
    --region $SOLR_AWS_REGION \
    --fargate

    OR use below to use predefined VPC and Subnets

    eksctl create cluster -f eks-cluster-config.yaml

It takes a while for cluster to get up and running, please be patient you should be able to monitor the progress events in cloud formation on AWS console

If more replicas are needed we need to create more EFS (Its access point and mount paths) and update the hpa.yml with maxReplicas

### Logging

We will use FluentBit framework, explore more details here https://aws.amazon.com/blogs/containers/fluent-bit-for-amazon-eks-on-aws-fargate-is-here/

    kubectl apply -f logging.yml

    curl -o permissions.json \
    https://raw.githubusercontent.com/aws-samples/amazon-eks-fluent-logging-examples/mainline/examples/fargate/cloudwatchlogs/permissions.json

    aws iam create-policy \
        --policy-name FluentBitEKSFargate \
        --policy-document file://permissions.json 

    aws iam attach-role-policy \
        --policy-arn arn:aws:iam::123456789012:policy/FluentBitEKSFargate \
        --role-name eksctl-fluentbit-cluster-FargatePodExecutionRole-XXXXXXXXXX

Replace eksctl-fluentbit-cluster-FargatePodExecutionRole-XXXXXXXXXX role from IAM, once the SOLR is up and running we should be able to find our logs under 
    
    /aws/eks/solr-application/logs log group

Get VPC and CIDR details and setup security group for accessing EFS volumes

    SOLR_VPC_ID=$(aws eks describe-cluster --name $SOLR_EKS_CLUSTER --query "cluster.resourcesVpcConfig.vpcId" --region $SOLR_AWS_REGION --output text)

    SOLR_CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $SOLR_VPC_ID --query "Vpcs[].CidrBlock" --region $SOLR_AWS_REGION --output text)

    SOLR_EFS_SG_ID=$(aws ec2 create-security-group \
    --description SOLR-on-Fargate \
    --group-name SOLR-on-Fargate \
    --vpc-id $SOLR_VPC_ID \
    --region $SOLR_AWS_REGION \
    --query 'GroupId' --output text)

    aws ec2 authorize-security-group-ingress \
    --group-id $SOLR_EFS_SG_ID \
    --protocol tcp \
    --port 2049 \
    --cidr $SOLR_CIDR_BLOCK

Create EFS volumes for Solr servers, create as many required for maximum number of replicas to be configured in HPA, don't worry you will get charged only based on /GB-month not on number of EFS we setup, also I'm using general purpose performance setting below, but there are other more performant modes available to choose from

Don't run below 3 commands, there is a script setup-aws-efs.sh which need to be executed

    SOLR_EFS_FS_ID=$(aws efs create-file-system \
    --creation-token SOLR1-on-Fargate \
    --encrypted \
    --performance-mode generalPurpose \
    --throughput-mode bursting \
    --tags Key=Name,Value=SOLR1-Volume \
    --region $SOLR_AWS_REGION \
    --output text \
    --query "FileSystemId")

Create access point for the above EFS

    SOLR_EFS_AP=$(aws efs create-access-point \
    --file-system-id $SOLR1_EFS_FS_ID \
    --posix-user Uid=1000,Gid=1000 \
    --root-directory "Path=/bitnami/solr,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
    --region $SOLR_AWS_REGION \
    --query 'AccessPointId' \
    --output text)

Create Mount Paths for the above EFS in every Availability Zone

    for subnet in $(aws eks describe-fargate-profile \
    --output text --cluster-name $SOLR_EKS_CLUSTER\
    --fargate-profile-name fp-default  \
    --region $SOLR_AWS_REGION  \
    --query "fargateProfile.subnets"); \
    do (aws efs create-mount-target \
    --file-system-id $SOLR_EFS_FS_ID \
    --subnet-id $subnet \
    --security-group $SOLR_EFS_SG_ID \
    --region $SOLR_AWS_REGION); \
    done

Similarly we do the same for all the Zookeepers run below script and wait for it to complete

    source setup-aws-efs.sh

Update FSID and AccessPoint IDs in aws-volumes.yml from output of above

    envsubst < aws-volumes.yml > aws-volumes-updated.yml

Deploy the persistent volumes

    kubectl apply -f aws-volumes-updated.yml

### Deploy the AWS Load Balancer Controller

Associate OIDC provider

    eksctl utils associate-iam-oidc-provider \
    --region $SOLR_AWS_REGION \
    --cluster $SOLR_EKS_CLUSTER \
    --approve

Download the IAM policy document

    curl -S https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json -o iam-policy.json

Create an IAM policy

    aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

Create a service account

    eksctl create iamserviceaccount \
    --cluster=$SOLR_EKS_CLUSTER \
    --region $SOLR_AWS_REGION \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --override-existing-serviceaccounts \
    --attach-policy-arn=arn:aws:iam::$SOLR_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve

The AWS Load Balancer Controller uses cert-manager to inject certificate configuration into the webhooks. Create a Fargate profile for cert-manager namespace so Kubernetes can schedule cert-manager pods on Fargate:

    eksctl create fargateprofile \
    --cluster $SOLR_EKS_CLUSTER \
    --name cert-manager \
    --namespace cert-manager \
    --region $SOLR_AWS_REGION

Install the AWS Load Balancer Controller using Helm:

    helm repo add eks https://aws.github.io/eks-charts

    helm repo update

    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

    helm install aws-load-balancer-controller \
    eks/aws-load-balancer-controller \
    --namespace kube-system \
    --set clusterName=$SOLR_EKS_CLUSTER \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set vpcId=$SOLR_VPC_ID \
    --set region=$SOLR_AWS_REGION

Finally Deploy SolrCloud, if for some reason pod stay in pending, describe the pods to know the reason, and kill them once if you have to, start with zookeepers

    helm install solr -f aws-values.yaml bitnami/solr

Deploy Ingress, important annotations can be used from following link to configure the AWS Load Balancer https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/

    kubectl apply -f aws-ingress.yml

If we need to reinstall ingress and its not getting deleted try below, reason is there are some finalizers attached to the ingress which the controller is not able to clean

    kubectl patch ingress solr-ingress -n default -p '{"metadata":{"finalizers":[]}}' --type=merge

Wait for some time to get the AWS ALB created and then get the hostname

    echo $(kubectl get ingress solr-ingress -o jsonpath="{.status.loadBalancer.ingress[].hostname}")

Re-apply configsets, then set authentication flag blockUnknown to false and autoscaling cluster policies as above. 

Install Metrics Server

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Give it a minute and check if the metrics-server pod is ready using below

    kubectl get pods -n kube-system

Now re-apply the HPA configured with averageValue as 10Mi, and check again for the new solr pod to be spawned and get ready

    kubectl apply -f hpa.yml

    kubectl get pods --watch

In few minutes autoscaling should kick in, validate once again if new replica gets attached to my-collection in graph view and thats it we are done.

If more replicas are needed we need to create more EFS (Its access point and mount paths) and update the hpa.yml with maxReplicas

## Backup
We can use collections api for backup and restore on SolrCloud and single shared volume needs to be mounted on all Solr replicas.

For local I have updated the local-values.yaml with a busybox init container to fix the permissions on the mounted volume, as the volume gets mounted with root user and Solr process needs to write on it

For AWS mounted EFS volumes, permissions are marked with 777 hence don't need the init container

    http://HOSTNAME/solr/admin/collections?action=BACKUP&name=myBackupName&collection=my-collection&location=/backup

    http://HOSTNAME/solr/admin/collections?action=RESTORE&name=myBackupName&collection=my-collection&location=/backup


## Upgrade

Update SolrCloud stack if values.yaml is updated

    helm upgrade solr -f aws-values.yaml bitnami/solr

## Finally delete the cluster

Delete the EFS volumes first and then try deleting the EKS cluster

    eksctl delete cluster \
    --name $SOLR_EKS_CLUSTER \
    --region $SOLR_AWS_REGION

## Miscellaneous

If you want to curl K8s services from within the cluster e.g curl to individual Solr nodes, you can install radial busybox

    kubectl run curl --image=radial/busyboxplus:curl -i --tty

    curl --location --request GET 'http://solr-2.solr-headless.default.svc.cluster.local:8983/solr/my-collection/select?q=*:*&wt=json' --header 'Content-Type: application/json'

After exit if you want to get back in run below

    kubectl attach curl -c curl -i -t
