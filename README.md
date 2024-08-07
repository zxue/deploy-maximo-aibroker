# Deploy IBM Maximo AI Broker

Maximo Application Suite (MAS) version 9.0 introduces a new feature, AI Broker. It is the integration hub that facilitates communication between MAS and IBM watsonx AI systems or services. For more details, check [Maximo Manage AI overview](https://www.ibm.com/docs/en/mas-cd/maximo-manage/continuous-delivery?topic=watsonx-maximo-manage-ai-overview).

You can install after Mas Core or Mas Manage is deployed. This document outlines steps for deploying Maximo AI broker and some troubleshooting tips.

Check [Installing and deploying the AI broker](https://www.ibm.com/docs/en/mas-cd/maximo-manage/continuous-delivery?topic=setup-installing-deploying-ai-broker)

Check [Install AI Broker Application](https://ibm-mas.github.io/ansible-devops/playbooks/oneclick-aibroker/#prerequisites_3), including prerequisites.

For IBM internal only, check the [video on how to install AI broker](https://ibm.ent.box.com/file/1560875310399) and the [PowerPoint file](https://ibm.ent.box.com/file/1559413953086?s=2gevj2hurz48je3v6j9sm2kopg4xrur8&tc=collab-file-invite-treatment).

## Prepare your installation environment

You can use your local environment with python3 and other dependencies, or use the container. In the example, a local folder `masconfig` is used and mapped to in the container. 

Check that you have "oneclick_add_aibroker.yml` available in the folder, e.g. `/Users/xxx/masconfig/ansible-devops/ibm/mas_devops/playbooks`

```
cd masconfig
docker run -it --rm --pull always -v ${PWD}:/masconfig --name ibmmas quay.io/ibmmas/cli
```

## Create Minio storage

While you may be able to use IBM Cloud Object Storage and other S3 compatible storage systems, keep in mind that only two storage options, Minio or AWS S3 storage, have been tested at the time of this writing. Check more details on [how to install minio](https://min.io/docs/minio/kubernetes/openshift/operations/installation.html)

Ensure that you have downloaded the three yaml files, `kustomization.yml',`minio.yml`,`pvc.yml`, and save them to the minio folder. Navigate to the parent folder and run the command lines below to create the Minio storage. 

```
oc new-project minio
cd ..
oc apply -k minio
```

You can find the url from the networking routes, e.g. `https://minio-route-minio.apps.xxx.com`,  and login with the default credentials, with username `minio123` and password `minio123`

![Minio](media/minio.png)

## Create MariaDB and secret

MariaDB is required for AI Broker. Ensure that you have downloaded the yaml files in the repo, and save them to the mariadb folder. 

Open the mariadb network policy file, mariadb-np.yml, and update two values with the correct namespace, e.g. "kubernetes.io/metadata.name: mas-inst1-aibroker".

Navigate to the parent folder and run the command lines below to create a MariaDB database in its own namespace, `mariadb`.


```
# oc new-project mas-inst1-aibroker
cd ..
./mariadb/mariadb-deploy.sh
```

## Define environment variables

Depending on where you pull the container images, you will need define the following environment variables. Note that dev images are used currently so use the provided ARTIFACTORY credentials. 

```
# ARTIFACTORY credentials
export ARTIFACTORY_USERNAME="pmqcloud@us.ibm.com"
export ARTIFACTORY_TOKEN="cmVmdGtuOjAxOjE3MjQyNTg5ODg6UFI0UG5WQlJSS01NV3BVN0tvMFNYUkRkYkJW"
export MAS_ICR_CP="docker-na-public.artifactory.swg-devops.com/wiotp-docker-local"
export MAS_ICR_CPOPEN="docker-na-public.artifactory.swg-devops.com/wiotp-docker-local/cpopen"

#MAS
export MAS_INSTANCE_ID="inst1"
export MAS_ENTITLEMENT_USERNAME="xxx@ibm.com"
export MAS_ENTITLEMENT_KEY="xxx"

# MINIO
export STORAGE_ACCESSKEY="minio123"
export STORAGE_SECRETKEY="minio123"
export STORAGE_SSL="false"
export STORAGE_PROVIDER="minio"
export STORAGE_PORT="9000"
export STORAGE_HOST="minio-service.minio.svc.cluster.local"
export STORAGE_PIPELINES_BUCKET="km-pipelines"
export STORAGE_TENANTS_BUCKET="km-tenants"
export STORAGE_TEMPLATES_BUCKET="km-templates"

# WATSONX AI
export WATSONXAI_APIKEY="xxx"
export WATSONXAI_URL="https://us-south.ml.cloud.ibm.com"
export WATSONXAI_PROJECT_ID="xxx"
export MAS_AIBROKER_CHANNEL="9.0.x"

# database
export DB_HOST="mariadb-instance.mariadb.svc.cluster.local"
export DB_PORT="3306"
export DB_USER="mariadb"
export DB_DATABASE="kmpipeline"
export DB_SECRET_NAME="ds-pipeline-db-instance"
export DB_SECRET_VALUE="mariadb"
```

## Install AI broker

Run the command line to install Maximo AI broker

```
ansible-playbook playbooks/oneclick_add_aibroker.yml
```

## Troubleshoot issues

### Role `ibm.mas_devops.odh` is not found

You may run into the error that looks like this.

```
The error appears to be in '/Users/xxx/masconfig/ansible-devops/ibm/mas_devops/playbooks/oneclick_add_aibroker.yml': line 47, column 7, but may
be elsewhere in the file depending on the exact syntax problem.

The offending line appears to be:

  roles:
    - ibm.mas_devops.odh
      ^ here
```

It is likely that your ansible-galaxy collection for "ibm mas devops" is dated. Run the command lines below.

```
ansible-galaxy collection build 
ansible-galaxy collection install ibm-mas_devops-*.tar.gz --ignore-certs --force
```

### ServiceMesh CRD waiting but not finished

If you find the task `Wait until the ServiceMesh CRD is available` is not finished, it is likely that there is some issue with the service mesh operator.

```
TASK [ibm.mas_devops.odh : Wait until the ServiceMesh CRD is available] ********************************************************************************************
included: /opt/app-root/lib64/python3.9/site-packages/ansible_collections/ibm/mas_devops/common_tasks/wait_for_crd.yml for localhost
TASK [ibm.mas_devops.odh : wait_for_crd : Wait until the servicemeshcontrolplanes.maistra.io CRD is available] *****************************************************
FAILED - RETRYING: [localhost]: wait_for_crd : Wait until the servicemeshcontrolplanes.maistra.io CRD is available (60 retries left).
FAILED - RETRYING: [localhost]: wait_for_crd : Wait until the servicemeshcontrolplanes.maistra.io CRD is available (59 retries left).
```

You can delete the "openshift-pipelines-operator-rh" operator.

![Delete rh operator](media/openshift-pipelines-operator-rh.png)

### DSCInitialization error

The task `Create DSCInitialization instance` may fail due to internal server error.

```
TASK [ibm.mas_devops.odh : Create DSCInitialization instance] ******************************************************************************************************
fatal: [localhost]: FAILED! => changed=false 
  error: 500
  msg: 'DSCInitialization default-dsci: Failed to apply object: b''{"kind":"Status","apiVersion":"v1","metadata":{},"status":"Failure","message":"Internal error occurred: failed calling webhook \\"operator.opendatahub.io\\": failed to call webhook: Post \\"https://opendatahub-operator-controller-manager-service.openshift-operators.svc:443/validate-opendatahub-io-v1?timeout=10s\\": dial tcp 10.131.0.30:9443: connect: connection refused","reason":"InternalError","details":{"causes":[{"message":"failed calling webhook \\"operator.opendatahub.io\\": failed to call webhook: Post \\"https://opendatahub-operator-controller-manager-service.openshift-operators.svc:443/validate-opendatahub-io-v1?timeout=10s\\": dial tcp 10.131.0.30:9443: connect: connection refused"}]},"code":500}\n'''
  reason: Internal Server Error
  status: 500
```

Re-run the ai broker playbooks. If that does not help, check that you have configured Minio storage and MariaDB properly.

### Manual certificate management issue 

You may get an error like, 
```
Manual certificate management is enabled and the required TLS secret `inst1-public-aibroker-tls` has not been created in namespace ''mas-inst1-aibroker'''
```

When custom certificates are used for MAS, it is likely that manual certificate management is set to true in OpenShift. To resolve the issue, create a secret for `inst1-public-aibroker-tls` in OpenShift. You can check what certificates are used from the MAS admin portal, and copy the data and type values. Re-run the ai broker playbooks.

```
kind: Secret
apiVersion: v1
metadata:
  name: inst1-public-aibroker-tls
  namespace: mas-inst1-aibroker
...
data:
  ca.crt: xxx
  tls.crt: xxx
  tls.key: xxx
type: kubernetes.io/tls
```

## Acknowledgement

Many thanks to the product group, Kewei Yang, Eyal Cohen, Rafael Felipe Craveiro Teixeira and Roshi Dubey for sharing their knowledge and troubleshooting tips. Also, thanks to Janki Vora and Veera Solasa for their collaboration and feedback.
