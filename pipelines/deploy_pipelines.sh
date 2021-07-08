#!/bin/bash
set -x

oc new-project analysis-cicd



oc adm policy add-role-to-user admin system:serviceaccount:analysis-test:pipeline -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-test
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-test -n analysis-cicd



oc adm policy add-role-to-user admin system:serviceaccount:analysis-prod:pipeline -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-prod -n analysis-cicd


oc adm policy add-scc-to-user anyuid system:serviceaccount:analysis-cicd:gitea -n analysis-cicd

oc adm policy add-scc-to-user privileged -z pipeline -n  analysis-cicd


            cluster_domain=""
            while [ "$cluster_domain" == "" ]
            do              
              oc create service clusterip test --tcp=5678:8080
              oc create route edge --service=test
              cluster_domain=$(oc get route test -o yaml | grep host: | awk '{print $2}' | tail -n 1 | cut -d "." -f 2-)
              oc delete route test
              oc delete service test
              namespace=$(oc project | awk -F '"' '{print $2}')
            done



REGISTRY_URL="myregistry-quay-$namespace.$cluster_domain"

sleep 60
#            REGISTRY_URL=""
#            while [ "$REGISTRY_URL" == "" ]
#            do
#              echo "waiting for Quay route..."
#              REGISTRY_URL=$(oc get route -n analysis-cicd myregistry-quay -o yaml | grep host: | awk '{print $2}' | tail -n 1)
#              sleep 15
#            done


#oc patch image.config.openshift.io/cluster -p '{"spec":{"allowedRegistriesForImport":[{"domainName":"'${REGISTRY_URL}'","insecure":true}],"registrySources":{"insecureRegistries":["'${REGISTRY_URL}'"]}}}' --type='merge'
oc patch image.config.openshift.io/cluster -p '{"spec":{"registrySources":{"insecureRegistries":["'${REGISTRY_URL}'"]}}}' --type='merge'


STATUS=no
while [ "$STATUS" != "" ]
do
 STATUS=$(oc get pod --all-namespaces | grep -v Complete | grep -v Runn  | grep -v READY )
 sleep 10
done




oc create secret docker-registry registry-auth-secret -n analysis-cicd --docker-server=$REGISTRY_URL --docker-username=quayadmin --docker-password=password


oc create secret docker-registry registry-auth-secret -n analysis-prod --docker-server=$REGISTRY_URL --docker-username=quayadmin --docker-password=password
oc secrets link default registry-auth-secret -n analysis-prod --for=pull





oc -n analysis-cicd create -f infra/quay-standalone-template.yaml
oc -n analysis-cicd create -f infra/sonarqube-template.yaml
oc -n analysis-cicd create -f infra/nexus-template.yaml
oc -n analysis-cicd create -f infra/gitea-template.yaml


oc process -f infra/quay-standalone-template.yaml  | oc create -f -
oc process -f infra/gitea-template.yaml | oc -n analysis-cicd create -f -
oc process -f infra/sonarqube-template.yaml | oc -n analysis-cicd create -f -
oc process -f infra/nexus-template.yaml | oc -n analysis-cicd create -f -



oc create -n analysis-cicd -f infra/gitea-init.yaml




oc create secret generic -n analysis-cicd webhook-secret --from-literal=url=https://hooks.slack.com/services/TGVFASDFG


oc create -f ./common-functions/tasks/send-to-webhook-slack.yaml -n analysis-cicd


oc create -n analysis-cicd -f ./common-functions/configmap/maven-settings.yaml



oc -n  analysis-cicd create -f ./common-functions/tasks/sonarqube-scanner.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/maven-local-repo.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/pull-request-gitea.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/pushImageToRegistry.yaml



oc -n analysis-cicd create -f  ./common-functions/pipeline/analysis-build-pipeline.yaml
oc -n analysis-cicd create -f  ./common-functions/pipeline/analysis-promote-pipeline.yaml


for i in analysis-gateway analysis-core analysis-process-regular analysis-process-virus 
do
    oc -n analysis-cicd create -f ./$i/pvc/build-shared-workspace.yaml
    oc -n analysis-cicd create -f ./$i/pvc/promote-shared-workspace.yaml
    oc -n analysis-cicd create -f ./$i/pvc/maven-local-repo.yaml
done



for i in analysis-gateway analysis-core analysis-process-regular analysis-process-virus 
do
    oc -n analysis-cicd create -f  ./$i/triggers/build-pipeline-trigger.yaml
    sed "s/.*443\/quayadmin\/.*/         value: $REGISTRY_URL\/quayadmin\/$i/g" ./$i/triggers/promote-pipeline-trigger.yaml > /tmp/promote-pipeline-trigger.yaml
    oc -n analysis-cicd create -f  /tmp/promote-pipeline-trigger.yaml
done




