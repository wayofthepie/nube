#!/bin/bash

mkdir -p worker

CUR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_FQDN=$1
WORKER_IP=$2

# Worker keypairs
pushd worker
openssl genrsa -out ${WORKER_FQDN}-worker-key.pem 2048
WORKER_IP=${WORKER_IP} openssl req -new -key ${WORKER_FQDN}-worker-key.pem \
  -out ${WORKER_FQDN}-worker.csr \
  -subj "/CN=${WORKER_FQDN}" \
  -config ../worker-openssl.cnf
WORKER_IP=${WORKER_IP} openssl x509 -req -in ${WORKER_FQDN}-worker.csr \
  -CA ../ca/ca.pem \
  -CAkey ../ca/ca-key.pem \
  -CAcreateserial -out ${WORKER_FQDN}-worker.pem \
  -days 365 -extensions v3_req \
  -extfile ${CUR_DIR}/worker-openssl.cnf
popd

