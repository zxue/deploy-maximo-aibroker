#!/bin/bash

oc apply -f mariadb/mariadb-ns.yml
oc apply -f mariadb/mariadb-pvc.yml
oc apply -f mariadb/mariadb-sa.yml
oc apply -f mariadb/mariadb-np.yml
oc apply -f mariadb/mariadb-secret.yml
oc apply -f mariadb/mariadb-deployment.yml
oc apply -f mariadb/mariadb-service.yml
