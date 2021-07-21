export SOLR_ENV=prod

export SOLR_ENV_TYPE=prod

export SOLR_VPC_SUBNETS="subnet-xxxxxxx, subnet-xxxxxx"
#Public Subnets

#Security Group Fetched From Cluster Setup
export SOLR_EFS_SG_ID="sg-xxxxxxxx"

export SOLR_ALB_CERT_ARN="arn:aws:acm:eu-west-1:123456789012:certificate/xxxxxxxxxx"

export SOLR_ALB_SEC_GRPS="sg-xxxxxx, sg-xxxxxx"

source setup-solr.sh