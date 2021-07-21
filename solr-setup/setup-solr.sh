export SOLR_AWS_REGION=eu-west-1

export SOLR_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

export SOLR_EKS_CLUSTER=eks-fargate-solr

source setup-aws-efs.sh

envsubst < aws-volumes.yml > aws-volumes-updated.yml

kubectl create namespace $SOLR_ENV

eksctl create fargateprofile \
    --cluster $SOLR_EKS_CLUSTER \
    --name $SOLR_ENV \
    --namespace $SOLR_ENV \
    --region $SOLR_AWS_REGION

kubectl config set-context --current --namespace=$SOLR_ENV

kubectl apply -f aws-volumes-updated.yml

sleep 120

helm install solr -f aws-values-$SOLR_ENV_TYPE.yaml bitnami/solr

sleep 300

envsubst < aws-ingress.yml > aws-ingress-updated.yml

kubectl apply -f aws-ingress-updated.yml

sleep 300

export HOSTNAME=`kubectl get ingress solr-ingress -o jsonpath="{.status.loadBalancer.ingress[].hostname}"`

echo $HOSTNAME

#source deploy-collections.sh