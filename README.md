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

MariaDB is required for AI Broker. Ensure that you have downloaded the two yaml files, `deployment.yml' and `service.yml`, and save them to the mariadb folder. Navigate to the parent folder and run the command lines below to MariaDB database.

```
oc new-project mas-inst1-aibroker
cd ..
oc apply -f mariadb/deployment.yaml -n mas-inst1-aibroker
oc apply -f mariadb/service.yaml -n mas-inst1-aibroker
```

Note that the database is created in a specific namespace based on the instance name for Mas Core. For example, if MAS instance is "inst1", then the namespace is "mas-inst1-aibroker".

To create a secret for the MariaDB database, import the yaml file below from the OpenShift console. Alternatively, create a yaml file and apply it.

```
apiVersion: v1
kind: Secret
metadata:
  name: ds-pipeline-db-instance
  namespace: mas-inst1-aibroker
type: Opaque
stringData:
  password: maria123
```

## Define environment variables

Depending on where you pull the container images, you will need define the following environment variables.

```
# ARTIFACTORY credentials
export ARTIFACTORY_USERNAME="xxx.com"
export ARTIFACTORY_TOKEN="xxx"

# IBM entitlement keys
export MAS_INSTANCE_ID="inst1" 
export MAS_ENTITLEMENT_KEY="xxx"
export IBM_ENTITLEMENT_USERNAME="xxx.com" 
export IBM_ENTITLEMENT_KEY="xxx"
export ICR_USERNAME="cp" 
export ICR_PASSWORD="<same as entitlement key>" 
export APP_DOMAIN="apps.xxx.com" 

#Storage info for Minio
export STORAGE_ACCESSKEY="minio123"
export STORAGE_SECRETKEY="minio123"
export STORAGE_HOST="http://minio-service.minio.svc.cluster.local"
export STORAGE_PORT="9000"
export STORAGE_REGION=""
export STORAGE_PROVIDER="minio"
export STORAGE_SSL="false"
export STORAGE_PIPELINES_BUCKET="km-pipelines"
export STORAGE_TENANTS_BUCKET="km-tenants"
export STORAGE_TEMPLATES_BUCKET="km-templates"
export TENANT_NAME="user"

# watsonx credentails

export WATSONXAI_APIKEY="xxx"
export WATSONXAI_URL="https://us-south.ml.cloud.ibm.com"
export WATSONXAI_PROJECT_ID="xxx"

# MariaDB info
export DB_HOST="mariadb-instance.mas-inst1-aibroker.svc.cluster.local"
export DB_PORT="3306"
export DB_USER="root"
export DB_DATABASE="mlpipelines"
export DB_SECRET_NAME="ds-pipeline-db-instance"
export DB_SECRET_VALUE="maria123"
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

![Delete rh operator](openshift-pipelines-operator-rh.png)

## Acknowledgement

Many thanks to the product group, Kewei Yang, Eyal Cohen,Rafael Felipe Craveiro Teixeira, for sharing their knowledge and providing troubleshooting tips.
