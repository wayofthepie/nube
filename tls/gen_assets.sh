#!/bin/bash
set -e
mkdir -p {ca,apiserver,admin}

# Cluster CA
pushd ca
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 10000 -out ca.pem -subj "/CN=kube.nube.com" -config ../openssl.cnf
popd

# Create apiserver keypair
pushd apiserver
openssl genrsa -out apiserver-key.pem 2048
openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config ../openssl.cnf
openssl x509 -req -in apiserver.csr -CA ../ca/ca.pem -CAkey ../ca/ca-key.pem \
  -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile ../openssl.cnf
popd

# Cluster admin keypair
pushd admin
openssl genrsa -out admin-key.pem 2048
openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in admin.csr -CA ../ca/ca.pem -CAkey ../ca/ca-key.pem -CAcreateserial -out admin.pem -days 365
popd
