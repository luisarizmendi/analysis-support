# Tekton pipelines

These are the desciptors to create the Tekton Pipelines for the [Analysis App](https://github.com/luisarizmendi/analysis). "analysis-cicd".


## Pre-requisites

You need a copy of the App in analysis-test and analisys-prod namespaces and an analysis-cicd namespace where to create infra resources.


## Pipeline deployment

If you want to deploy just run

```
./deploy_pipelines.sh
```

Or perform the steps below:

### Prepare projects and permissions

**Create a namespaces**  

You need a namespace host the pipelines and CICD infra:

```
oc new-project analysis-cicd
```


**Give permitions between namespaces**  

In order to deploy from analysis-cicd to analysis-test

```
oc adm policy add-role-to-user admin system:serviceaccount:analysis-test:pipeline -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-test
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-test -n analysis-cicd
```

...and prod:

```
oc adm policy add-role-to-user admin system:serviceaccount:analysis-prod:pipeline -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-prod -n analysis-cicd
```

GITEA image make use of a supervisor process (s6) to configure and launch the several services ( ss, gitea, ...), and this supervisor need to be run under root so we need to permit it:

```
oc adm policy add-scc-to-user anyuid system:serviceaccount:analysis-cicd:gitea -n analysis-cicd
```

**POD updating the registry image needs to be privileged**  

You need to add the "privileged" SCC to the "pipeline" Service Account because the POD running podman will need access to its /var/lib/containers directory:

```
oc adm policy add-scc-to-user privileged -z pipeline -n  analysis-cicd
```



### Create CI/CD infrastructure 

If you you don't have Sonarqube and Nexus in your environment yet:

```
oc -n analysis-cicd create -f infra/sonarqube-template.yaml
oc -n analysis-cicd create -f infra/nexus-template.yaml
oc -n analysis-cicd create -f infra/gitea-template.yaml
oc -n analysis-cicd create -f infra/quay-standalone-template.yaml



oc process -f infra/quay-standalone-template.yaml  | oc create -f -
oc process -f infra/gitea-template.yaml | oc -n analysis-cicd create -f -
oc process -f infra/sonarqube-template.yaml | oc -n analysis-cicd create -f -
oc process -f infra/nexus-template.yaml | oc -n analysis-cicd create -f -


oc create -n analysis-cicd -f infra/gitea-init.yaml
```




### Create common objects



**Set your registry credentials**  

Create a secret with your credentials:

```
oc create secret docker-registry registry-auth-secret -n analysis-cicd --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> 
```

If you want to use the Quay registry deployed with the default credentials:
```
oc create secret docker-registry registry-auth-secret -n analysis-cicd --docker-server=myregistry-quay-app.analysis-cicd.svc:443 --docker-username=quayadmin --docker-password=password
```

To use this secret for pulling images for pods in the production namespace, you must add the secret to your service account. The name of the service account in this example should match the name of the service account the pod uses. The default service account is default.

Create the same secret in the production namespace and the set it up as pull secret:

```
oc create secret docker-registry registry-auth-secret -n analysis-prod --docker-server=myregistry-quay-app.analysis-cicd.svc:443 --docker-username=quayadmin --docker-password=password

oc secrets link default registry-auth-secret -n analysis-prod --for=pull
```





**Configure slack webhook**  

The pipeline sends a message to Slack. In order to make it work you need to get the [Webhook URL from Slack](https://api.slack.com/messaging/webhooks).

If you don't have a webhook and you don't plan to obtain it, just create the secret with a random Webhook string (like https://hooks.slack.com/services/TGVFASDFG)

```
oc create secret generic -n analysis-cicd webhook-secret --from-literal=url=<your webhook> 
```

```
oc create -f ./common-functions/tasks/send-to-webhook-slack.yaml -n analysis-cicd
```




**Create the maven settings file**

```
oc create -n analysis-cicd -f ./common-functions/configmap/maven-settings.yaml
```


**Configure custom Tasks**
```
oc -n  analysis-cicd create -f ./common-functions/tasks/sonarqube-scanner.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/maven-local-repo.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/pull-request-gitea.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/pushImageToRegistry.yaml
```


**Create Pipeline**
```
oc -n analysis-cicd create -f  ./common-functions/pipeline/analysis-build-pipeline.yaml
oc -n analysis-cicd create -f  ./common-functions/pipeline/analysis-promote-pipeline.yaml
```


### Create objects for each microservice




**Configure pvc to share content across tasks**
```
for i in analysis-gateway analysis-core analysis-process-regular analysis-process-virus 
do
    oc -n analysis-cicd create -f ./$i/pvc/build-shared-workspace.yaml
    oc -n analysis-cicd create -f ./$i/pvc/promote-shared-workspace.yaml
    oc -n analysis-cicd create -f ./$i/pvc/maven-local-repo.yaml
done
```


**Create Triggers**
```
for i in analysis-gateway analysis-core analysis-process-regular analysis-process-virus 
do
    oc -n analysis-cicd create -f  ./$i/triggers/build-pipeline-trigger.yaml
    oc -n analysis-cicd create -f  ./$i/triggers/promote-pipeline-trigger.yaml
done
```


