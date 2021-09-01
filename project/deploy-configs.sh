kubectl config set-context --current --namespace=prod
export HOSTNAME=`kubectl get ingress solr-ingress -o jsonpath="{.status.loadBalancer.ingress[].hostname}"`

echo $HOSTNAME

curl -u admin:admin https://$HOSTNAME/api/cluster/security/authentication -H 'Content-type:application/json' -d  '{"set-property": {"blockUnknown":true}}' --insecure

(cd project-configs/conf && zip -r - *) > project-configs.zip

curl -u admin:admin -X POST -H "Content-Type:application/octet-stream" --data-binary @project-configs.zip "https://$HOSTNAME/solr/admin/configs?action=UPLOAD&name=project-configs&overwrite=true" --insecure

curl -u admin:$PASSWORD "https://$HOSTNAME/solr/admin/collections?action=RELOAD&name=my-collection" --insecure

curl -u admin:admin https://$HOSTNAME/api/cluster/security/authentication -H 'Content-type:application/json' -d  '{"set-property": {"blockUnknown":false}}' --insecure
