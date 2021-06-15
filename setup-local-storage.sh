kubectl delete pvc data-solr-0 data-solr-1 data-solr-2 
kubectl delete pvc data-solr-zookeeper-0 data-solr-zookeeper-1 data-solr-zookeeper-2
kubectl delete -f local-volumes.yml

rm -rf ~/work/mine/solr-data/zoo1
rm -rf ~/work/mine/solr-data/zoo2
rm -rf ~/work/mine/solr-data/zoo3
rm -rf ~/work/mine/solr-data/solr1 
rm -rf ~/work/mine/solr-data/solr2 
rm -rf ~/work/mine/solr-data/solr3
rm -rf ~/work/mine/solr-data/backup

mkdir ~/work/mine/solr-data/zoo1
mkdir ~/work/mine/solr-data/zoo2
mkdir ~/work/mine/solr-data/zoo3
mkdir ~/work/mine/solr-data/solr1
mkdir ~/work/mine/solr-data/solr2
mkdir ~/work/mine/solr-data/solr3
mkdir ~/work/mine/solr-data/backup