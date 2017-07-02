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
      deployment.virtualbox.vcpu = 4;
      boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
      boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = true;
      environment.systemPackages = with pkgs; [
        curl
        git
        vim
        nmap
        telnet
        openssl
        bind
      ];
      services.kubernetes = {
        roles = ["master" "node"];
        dns.enable = true;

        kubelet = {
          clusterDomain = "nube.com";
          enable = true;
          tlsKeyFile = apiserverKey;
          tlsCertFile = apiserverCert;
        };
        kubeconfig = {
          caFile = caPem;
          certFile = apiserverCert;
          keyFile = apiserverKey;
        };
        apiserver = {
          enable = true;
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
      virtualisation.docker.extraOptions = "--iptables=false --ip-masq=false";

      networking.firewall.allowedUDPPorts = [ 53 ];
      networking.firewall.allowedTCPPorts = [ 80 443 8080 ];
      networking.firewall.allowedTCPPortRanges = [{ from = 30000; to = 32767; }];
      networking.interfaces.enp0s8.ip4 = [ { address = "192.168.56.101"; prefixLength = 24; } ];
      networking.hostName = "kubernetes";
      environment.etc."resolv.conf".text = ''
        nameserver 8.8.8.8
      '';
      networking.extraHosts = ''
        192.168.56.101 kubernetes
      '';
    };
}
