{
  kube = { pkgs, ... }:
  let
    apiserverKey = ./tls/apiserver/apiserver-key.pem;
    apiserverCsr = ./tls/apiserver/apiserver.csr;
    apiserverCert = ./tls/apiserver/apiserver.pem;
    caPem = ./tls/ca/ca.pem;
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
        kubelet = {
          tlsKeyFile = apiserverKey;
          tlsCertFile = apiserverCert;
        };
        apiserver = {
          publicAddress = "0.0.0.0";
          advertiseAddress = "192.168.1.8";
          tlsKeyFile = apiserverKey;
          tlsCertFile = apiserverCert;
          clientCaFile = caPem;
          serviceAccountKeyFile = apiserverKey;
          kubeletClientCaFile = caPem;
          kubeletClientKeyFile = apiserverKey;
          kubeletClientCertFile = apiserverCert;
        };
        controllerManager.enable = true;
        controllerManager.rootCaFile = caPem;
        controllerManager.serviceAccountKeyFile = apiserverKey;
      };

      networking.firewall.allowedTCPPorts = [ 80 443 ];
      networking.firewall.allowedTCPPortRanges = [{ from = 30000; to = 32767; }];
      networking.nameservers = ["8.8.8.8"];
    };
}
