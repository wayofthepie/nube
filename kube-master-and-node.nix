{
  kube = { pkgs, ... }:
  let
    runWithOpenSSL = file: cmd: pkgs.runCommand file {
      buildInputs = [ pkgs.openssl ];
    } cmd;
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
    opensslCnf = pkgs.writeText "openssl.cnf" ''
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
    apiserverCnf = pkgs.writeText "apiserver-openssl.cnf" ''
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
      IP.1 = 10.10.10.1
    '';
    workerCnf = pkgs.writeText "worker-openssl.cnf" ''
      [req]
      req_extensions = v3_req
      distinguished_name = req_distinguished_name
      [req_distinguished_name]
      [ v3_req ]
      basicConstraints = CA:FALSE
      keyUsage = nonRepudiation, digitalSignature, keyEncipherment
      subjectAltName = @alt_names
      [alt_names]
      DNS.1 = kubeWorker1
      DNS.2 = kubeWorker2
    '';
    caKey = runWithOpenSSL "ca-key.pem" "openssl genrsa -out $out 2048";
    caPem = runWithOpenSSL "ca.pem" ''
      openssl req \
        -x509 -new -nodes -key ${caKey} \
        -days 10000 -out $out -subj "/CN=etcd-ca"
    '';
    etcdKey = runWithOpenSSL "etcd-key.pem" "openssl genrsa -out $out 2048";
    etcdCsr = runWithOpenSSL "etcd.csr" ''
      openssl req \
        -new -key ${etcdKey} \
        -out $out -subj "/CN=etcd" \
        -config ${opensslCnf}
    '';
    etcdCert = runWithOpenSSL "etcd.pem" ''
      openssl x509 \
        -req -in ${etcdCsr} \
        -CA ${caPem} -CAkey ${caKey} \
        -CAcreateserial -out $out \
        -days 365 -extensions v3_req \
        -extfile ${opensslCnf}
    '';

    etcdClientKey = runWithOpenSSL "etcd-client-key.pem"
      "openssl genrsa -out $out 2048";

    etcdClientCsr = runWithOpenSSL "etcd-client-key.pem" ''
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

    apiserverKey = runWithOpenSSL "apiserver-key.pem" "openssl genrsa -out $out 2048";

    apiserverCsr = runWithOpenSSL "apiserver.csr" ''
      openssl req \
        -new -key ${apiserverKey} \
        -out $out -subj "/CN=kube-apiserver" \
        -config ${apiserverCnf}
    '';

    apiserverCert = runWithOpenSSL "apiserver.pem" ''
      openssl x509 \
        -req -in ${apiserverCsr} \
        -CA ${caPem} -CAkey ${caKey} -CAcreateserial \
        -out $out -days 365 -extensions v3_req \
        -extfile ${apiserverCnf}
    '';

    workerKey = runWithOpenSSL "worker-key.pem" "openssl genrsa -out $out 2048";

    workerCsr = runWithOpenSSL "worker.csr" ''
      openssl req \
        -new -key ${workerKey} \
        -out $out -subj "/CN=kube-worker" \
        -config ${workerCnf}
    '';

    workerCert = runWithOpenSSL "worker.pem" ''
      openssl x509 \
        -req -in ${workerCsr} \
        -CA ${caPem} -CAkey ${caKey} -CAcreateserial \
        -out $out -days 365 -extensions v3_req \
        -extfile ${workerCnf}
    '';
  in
    {
      deployment.targetEnv = "virtualbox";
      deployment.virtualbox.headless = true;
      boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = true;
      environment.systemPackages = [
        pkgs.curl
        pkgs.git
        pkgs.vim
        pkgs.nmap
        pkgs.telnet
        pkgs.openssl
      ];
      services.kubernetes = {
        roles = ["master" "node"];
        apiserver = {
          publicAddress = "0.0.0.0";
          advertiseAddress = "192.168.1.8";
          tlsKeyFile = apiserverKey;
          tlsCertFile = apiserverCert;
          clientCaFile = caPem;
          serviceAccountKeyFile = apiserverKey;
          kubeletClientCaFile = caPem;
          kubeletClientKeyFile = workerKey;
          kubeletClientCertFile = workerCert;
        };
        controllerManager.enable = true;
        controllerManager.rootCaFile = caPem;
        controllerManager.serviceAccountKeyFile = apiserverKey;
      };

      networking.firewall.allowedTCPPortRanges = [{ from = 30000; to = 32767; }];
      networking.nameservers = ["8.8.8.8"];
    };
}
