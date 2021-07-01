#!/bin/bash

oc new-project analysis-cicd



oc adm policy add-role-to-user admin system:serviceaccount:analysis-test:pipeline -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-test
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-test -n analysis-cicd



oc adm policy add-role-to-user admin system:serviceaccount:analysis-prod:pipeline -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-prod -n analysis-cicd


oc adm policy add-scc-to-user anyuid system:serviceaccount:analysis-cicd:gitea -n analysis-cicd

oc adm policy add-scc-to-user privileged -z pipeline -n  analysis-cicd





oc -n analysis-cicd create -f infra/sonarqube-template.yaml
oc -n analysis-cicd create -f infra/nexus-template.yaml
oc -n analysis-cicd create -f infra/gitea-template.yaml


oc process -f infra/gitea-template.yaml | oc -n analysis-cicd create -f -
oc process -f infra/sonarqube-template.yaml | oc -n analysis-cicd create -f -
oc process -f infra/nexus-template.yaml | oc -n analysis-cicd create -f -


oc create -n analysis-cicd -f infra/gitea-init.yaml






oc create secret docker-registry registry-auth-secret -n analysis-cicd --docker-server=myregistry --docker-username=analisys --docker-password=Passw0rd!



oc create secret generic -n analysis-cicd webhook-secret --from-literal=url=https://hooks.slack.com/services/TGVFASDFG


oc create -f ./common-functions/tasks/send-to-webhook-slack.yaml -n analysis-cicd


oc create -n analysis-cicd -f ./common-functions/configmap/maven-settings.yaml



oc -n  analysis-cicd create -f ./common-functions/tasks/sonarqube-scanner.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/maven-local-repo.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/pull-request-gitea.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/pushImageToRegistry.yaml



oc -n analysis-cicd create -f  ./common-functions/pipeline/analysis-build-pipeline.yaml
oc -n analysis-cicd create -f  ./common-functions/pipeline/analysis-promote-pipeline.yaml


for i in analysis-gateway analysis-core analysis-process-regular analysis-process-virus analysis-domain
do
    oc -n analysis-cicd create -f ./$i/pvc/build-shared-workspace.yaml
    oc -n analysis-cicd create -f ./$i/pvc/promote-shared-workspace.yaml
    oc -n analysis-cicd create -f ./$i/pvc/maven-local-repo.yaml
done



for i in analysis-gateway analysis-core analysis-process-regular analysis-process-virus analysis-domain
do
    oc -n analysis-cicd create -f  ./$i/triggers/build-pipeline-trigger.yaml
    oc -n analysis-cicd create -f  ./$i/triggers/promote-pipeline-trigger.yaml
done