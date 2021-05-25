SOLR1_EFS_FS_ID=$(aws efs create-file-system \
  --creation-token SOLR1-on-Fargate \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=SOLR1-Volume \
  --region $SOLR_AWS_REGION \
  --output text \
  --query "FileSystemId")

sleep 5

export SOLR1_EFS_FS_ID=$SOLR1_EFS_FS_ID

SOLR1_EFS_AP=$(aws efs create-access-point \
  --file-system-id $SOLR1_EFS_FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/bitnami/solr,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
  --region $SOLR_AWS_REGION \
  --query 'AccessPointId' \
  --output text)

sleep 5

export SOLR1_EFS_AP=$SOLR1_EFS_AP

for subnet in $(aws eks describe-fargate-profile \
  --output text --cluster-name $SOLR_EKS_CLUSTER\
  --fargate-profile-name fp-default  \
  --region $SOLR_AWS_REGION  \
  --query "fargateProfile.subnets"); \
do (aws efs create-mount-target \
  --file-system-id $SOLR1_EFS_FS_ID \
  --subnet-id $subnet \
  --security-group $SOLR_EFS_SG_ID \
  --region $SOLR_AWS_REGION); \
done

sleep 5

SOLR2_EFS_FS_ID=$(aws efs create-file-system \
  --creation-token SOLR2-on-Fargate \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=SOLR2-Volume \
  --region $SOLR_AWS_REGION \
  --output text \
  --query "FileSystemId")

sleep 5

export SOLR2_EFS_FS_ID=$SOLR2_EFS_FS_ID

SOLR2_EFS_AP=$(aws efs create-access-point \
  --file-system-id $SOLR2_EFS_FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/bitnami/solr,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
  --region $SOLR_AWS_REGION \
  --query 'AccessPointId' \
  --output text)

sleep 5

export SOLR2_EFS_AP=$SOLR2_EFS_AP

for subnet in $(aws eks describe-fargate-profile \
  --output text --cluster-name $SOLR_EKS_CLUSTER\
  --fargate-profile-name fp-default  \
  --region $SOLR_AWS_REGION  \
  --query "fargateProfile.subnets"); \
do (aws efs create-mount-target \
  --file-system-id $SOLR2_EFS_FS_ID \
  --subnet-id $subnet \
  --security-group $SOLR_EFS_SG_ID \
  --region $SOLR_AWS_REGION); \
done

sleep 5

SOLR3_EFS_FS_ID=$(aws efs create-file-system \
  --creation-token SOLR3-on-Fargate \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=SOLR3-Volume \
  --region $SOLR_AWS_REGION \
  --output text \
  --query "FileSystemId")

sleep 5

export SOLR3_EFS_FS_ID=$SOLR3_EFS_FS_ID

SOLR3_EFS_AP=$(aws efs create-access-point \
  --file-system-id $SOLR3_EFS_FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/bitnami/solr,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
  --region $SOLR_AWS_REGION \
  --query 'AccessPointId' \
  --output text)

sleep 5

export SOLR3_EFS_AP=$SOLR3_EFS_AP

for subnet in $(aws eks describe-fargate-profile \
  --output text --cluster-name $SOLR_EKS_CLUSTER\
  --fargate-profile-name fp-default  \
  --region $SOLR_AWS_REGION  \
  --query "fargateProfile.subnets"); \
do (aws efs create-mount-target \
  --file-system-id $SOLR3_EFS_FS_ID \
  --subnet-id $subnet \
  --security-group $SOLR_EFS_SG_ID \
  --region $SOLR_AWS_REGION); \
done

sleep 5

ZOOKEEPER1_EFS_FS_ID=$(aws efs create-file-system \
  --creation-token Zookeeper1-on-Fargate \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=Zookeeper1-Volume \
  --region $SOLR_AWS_REGION \
  --output text \
  --query "FileSystemId")

sleep 5

export ZOOKEEPER1_EFS_FS_ID=$ZOOKEEPER1_EFS_FS_ID

ZOOKEEPER1_EFS_AP=$(aws efs create-access-point \
  --file-system-id $ZOOKEEPER1_EFS_FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/bitnami/zookeeper,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
  --region $SOLR_AWS_REGION \
  --query 'AccessPointId' \
  --output text)

sleep 5

export ZOOKEEPER1_EFS_AP=$ZOOKEEPER1_EFS_AP

for subnet in $(aws eks describe-fargate-profile \
  --output text --cluster-name $SOLR_EKS_CLUSTER\
  --fargate-profile-name fp-default  \
  --region $SOLR_AWS_REGION  \
  --query "fargateProfile.subnets"); \
do (aws efs create-mount-target \
  --file-system-id $ZOOKEEPER1_EFS_FS_ID \
  --subnet-id $subnet \
  --security-group $SOLR_EFS_SG_ID \
  --region $SOLR_AWS_REGION); \
done

sleep 5

ZOOKEEPER2_EFS_FS_ID=$(aws efs create-file-system \
  --creation-token Zookeeper2-on-Fargate \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=Zookeeper2-Volume \
  --region $SOLR_AWS_REGION \
  --output text \
  --query "FileSystemId")

sleep 5

export ZOOKEEPER2_EFS_FS_ID=$ZOOKEEPER2_EFS_FS_ID

ZOOKEEPER2_EFS_AP=$(aws efs create-access-point \
  --file-system-id $ZOOKEEPER2_EFS_FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/bitnami/zookeeper,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
  --region $SOLR_AWS_REGION \
  --query 'AccessPointId' \
  --output text)

sleep 5

export ZOOKEEPER2_EFS_AP=$ZOOKEEPER2_EFS_AP

for subnet in $(aws eks describe-fargate-profile \
  --output text --cluster-name $SOLR_EKS_CLUSTER\
  --fargate-profile-name fp-default  \
  --region $SOLR_AWS_REGION  \
  --query "fargateProfile.subnets"); \
do (aws efs create-mount-target \
  --file-system-id $ZOOKEEPER2_EFS_FS_ID \
  --subnet-id $subnet \
  --security-group $SOLR_EFS_SG_ID \
  --region $SOLR_AWS_REGION); \
done

sleep 5

ZOOKEEPER3_EFS_FS_ID=$(aws efs create-file-system \
  --creation-token Zookeeper3-on-Fargate \
  --encrypted \
  --performance-mode generalPurpose \
  --throughput-mode bursting \
  --tags Key=Name,Value=Zookeeper3-Volume \
  --region $SOLR_AWS_REGION \
  --output text \
  --query "FileSystemId")

sleep 5

export ZOOKEEPER3_EFS_FS_ID=$ZOOKEEPER3_EFS_FS_ID

ZOOKEEPER3_EFS_AP=$(aws efs create-access-point \
  --file-system-id $ZOOKEEPER3_EFS_FS_ID \
  --posix-user Uid=1000,Gid=1000 \
  --root-directory "Path=/bitnami/zookeeper,CreationInfo={OwnerUid=1000,OwnerGid=1000,Permissions=777}" \
  --region $SOLR_AWS_REGION \
  --query 'AccessPointId' \
  --output text)

sleep 5

export ZOOKEEPER3_EFS_AP=$ZOOKEEPER3_EFS_AP

for subnet in $(aws eks describe-fargate-profile \
  --output text --cluster-name $SOLR_EKS_CLUSTER\
  --fargate-profile-name fp-default  \
  --region $SOLR_AWS_REGION  \
  --query "fargateProfile.subnets"); \
do (aws efs create-mount-target \
  --file-system-id $ZOOKEEPER3_EFS_FS_ID \
  --subnet-id $subnet \
  --security-group $SOLR_EFS_SG_ID \
  --region $SOLR_AWS_REGION); \
done