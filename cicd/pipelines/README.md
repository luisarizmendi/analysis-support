# Tekton pipelines

These are the desciptors to create the Pipelines for the Analysis App that are included in the Helm Chart. They are prepared to use a namespace named "analysis-cicd".

If you want to deploy them manually you can follow the tasks below


**Create a namespaces**  

If you want it, you can deploy a new namespace to run the dev tests (remember to deploy the app in that project so the pipeline can modify the already created deployment in that namespace)

```
oc new-project analysis-test
```

Another to host the pipelines:

```
oc new-project analysis-cicd
```


**Give permitions between namespaces**  

In order to deploy from analysis-cicd to analysis-test

```
oc adm policy add-role-to-user admin system:serviceaccount:analysis-test:pipeline -n analysis-cicd
oc policy add-role-to-group system:image-puller system:serviceaccounts:analysis-test -n analysis-cicd
oc adm policy add-role-to-user admin system:serviceaccount:analysis-cicd:pipeline -n analysis-test
```


**POD updating the registry image needs to be privileged**  

You need to add the "privileged" SCC to the "pipeline" Service Account because the POD running podman will need access to its /var/lib/containers directory:

```
oc adm policy add-scc-to-user privileged -z pipeline -n  analysis-cicd
```


**Set your registry credentials**  

Create a secret with your credentials:

```
oc create secret docker-registry registry-auth-secret -n analysis-cicd --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> 
```


**Configure slack webhook**  

The pipeline sends a message to Slack. In order to make it work you need to get the [Webhook URL from Slack](https://api.slack.com/messaging/webhooks)

```
oc create secret generic -n analysis-cicd webhook-secret --from-literal=url=<your webhook> 
```

```
oc create -f event-notification/send-to-webhook-slack.yaml -n analysis-cicd
```


**Create CICD infra**  
If you you don't have Sonarqube and Nexus in your environment yet:

```
oc -n analysis-cicd create -f ../infra/sonarqube-template.yaml
oc -n analysis-cicd create -f ../infra/nexus-template.yaml

oc process -f ../infra/sonarqube-template.yaml | oc create -f -
oc process -f ../infra/nexus-template.yaml | oc create -f -
```


**Create the maven settings file**

```
oc create -n analysis-cicd -f ./common-functions/configmap/maven-settings.yaml
```


**Configure pvc to share content across tasks**
```
oc -n analysis-cicd create -f ./<microservice>/pvc/build-shared-workspace.yaml
oc -n analysis-cicd create -f ./<microservice>/pvc/maven-local-repo.yaml
```


**Configure custom Tasks**
```
oc -n  analysis-cicd create -f ./common-functions/tasks/sonarqube-scanner.yaml
oc -n  analysis-cicd create -f ./common-functions/tasks/maven-local-repo.yaml
```

**Configure push image to registry task**
```
oc -n  analysis-cicd create -f ./<microservice>/tektontasks/pushImageToRegistry.yaml
```

**Configure Resources**
```
oc -n analysis-cicd create -f  ./<microservice>/resources/git-pipeline-resource.yaml
oc -n analysis-cicd create -f  ./<microservice>/resources/image-pipeline-resource.yaml
```

**Create Pipeline**
```
oc -n analysis-cicd create -f  ./<microservice>/pipeline/build-pipeline.yaml
oc -n analysis-cicd create -f  ./<microservice>/pipeline/promote-pipeline.yaml
oc -n analysis-cicd create -f  ./<microservice>/pipeline/deploy-pipeline.yaml
```

