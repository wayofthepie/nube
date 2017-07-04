{ pkgs, ...}:
let
  runWithOpenSSL = file: cmd: pkgs.runCommand file {
    buildInputs = [ pkgs.openssl ];
  } cmd;

  masterIp = "10.10.10.1";

  # Openssl configurations
  masterOpenSslConf = pkgs.writeText "maser_openssl.cnf"  ''
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    subjectAltName = @alt_names
    [alt_names]
    DNS.1 = kubernetes
    IP.1 = ${masterIp}
  '';
  workerOpenSslConf = pkgs.writeText "worker_openssl.cnf" ''
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    subjectAltName = @alt_names
    [alt_names]
    IP.1 = $ENV::WORKER_FQDN
  '';
  apiserverOpenSslConf = pkgs.writeText "apiserver_openssl.cnf" ''
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    subjectAltName = @alt_names
    [alt_names]
    DNS.1 = kubernetes
    DNS.2 = kubernetes.default
    DNS.3 = kubernetes.default.svc
    DNS.4 = kubernetes.default.svc.cluster.local
    IP.1 = ${masterIp}
  '';
  etcdOpenSslConf = pkgs.writeText "etcd_openssl.cnf" ''
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth
    subjectAltName = @alt_names
    [alt_names]
    DNS.1 = etcd1
    DNS.2 = etcd2
    DNS.3 = etcd3
    IP.1 = 127.0.0.1
  '';
  clientOpensslCnf = pkgs.writeText "client-openssl.cnf" ''
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = digitalSignature, keyEncipherment
    extendedKeyUsage = clientAuth
  '';
in rec {
  # Pre-created assets
  caPem = ./tls/ca/ca.pem;
  caKey = ./tls/ca/ca-key.pem;

  # Etcd assets
  etcdKey = runWithOpenSSL "etcd-key.pem" "openssl genrsa -out $out 2048";
  etcdCsr = runWithOpenSSL "etcd.csr" ''
    openssl req \
      -new -key ${etcdKey} \
      -out $out -subj "/CN=etcd" \
      -config ${etcdOpenSslConf}
  '';
  etcdCert = runWithOpenSSL "etcd.pem" ''
    openssl x509 \
      -req -in ${etcdCsr} \
      -CA ${caPem} -CAkey ${caKey} \
      -CAcreateserial -out $out \
      -days 365 -extensions v3_req \
      -extfile ${etcdOpenSslConf}
  '';
  etcdClientKey = runWithOpenSSL "etcd-client-key.pem"
    "openssl genrsa -out $out 2048";
  etcdClientCsr = runWithOpenSSL "etcd-client.csr" ''
    openssl req \
      -new -key ${etcdClientKey} \
      -out $out -subj "/CN=etcd-client" \
      -config ${clientOpensslCnf}
  '';
  etcdClientCert = runWithOpenSSL "etcd-client.crt" ''
    openssl x509 \
      -req -in ${etcdClientCsr} \
      -CA ${caPem} -CAkey ${caKey} -CAcreateserial \
      -out $out -days 365 -extensions v3_req \
      -extfile ${clientOpensslCnf}
  '';

  # Apiserver assets
  apiserverKey = runWithOpenSSL "apiserver-key.pem"
    "openssl genrsa -out $out 2048";
  apiserverCsr = runWithOpenSSL "apiserver.csr" ''
    openssl req \
      -new -key ${apiserverKey} \
      -out $out -subj "/CN=kube-apiserver" \
      -config ${apiserverOpenSslConf}
  '';
  apiserverCert = runWithOpenSSL "apiserver.pem" ''
    openssl x509 \
      -req -in ${apiserverCsr} \
      -CA ${caPem} -CAkey ${caKey} -CAcreateserial \
      -out $out -days 365 -extensions v3_req \
      -extfile ${apiserverOpenSslConf}
  '';

  # Worker assets
  workerKey = runWithOpenSSL "worker-key.pem" "openssl genrsa -out $out 2048";
  workerCsr = runWithOpenSSL "worker.csr" ''
    openssl req \
      -new -key ${workerKey} \
      -out $out -subj "/CN=kube-worker" \
      -config ${workerOpenSslConf}
  '';
  workerCertGen = ipAddr: runWithOpenSSL "worker.pem" ''
    WORKER_IP=${ipAddr} openssl x509 \
      -req -in ${workerCsr} \
      -CA ${caPem} -CAkey ${caKey} -CAcreateserial \
      -out $out -days 365 -extensions v3_req \
      -extfile ${workerOpenSslConf}
  '';
}
