
let
  apiserverKey = ./tls/apiserver/apiserver-key.pem;
  apiserverCsr = ./tls/apiserver/apiserver.csr;
  apiserverCert = ./tls/apiserver/apiserver.pem;
  pkgs = (import <nixpkgs> {});
  assets = (import ./tls.nix { inherit pkgs; });
in {
  kube = { pkgs, ... }:
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
          tlsKeyFile = assets.apiserverKey;
          tlsCertFile = assets.apiserverCert;
        };
        kubeconfig = {
          caFile = assets.caPem;
          certFile = assets.apiserverCert;
          keyFile = assets.apiserverKey;
        };
        apiserver = {
          enable = true;
          tlsKeyFile = assets.apiserverKey;
          tlsCertFile = assets.apiserverCert;
          clientCaFile = assets.caPem;
          serviceAccountKeyFile = assets.apiserverKey;
          kubeletClientCaFile = assets.caPem;
          kubeletClientKeyFile = assets.apiserverKey;
          kubeletClientCertFile = assets.apiserverCert;
        };
        controllerManager.enable = true;
        controllerManager.rootCaFile = assets.caPem;
        controllerManager.serviceAccountKeyFile = assets.apiserverKey;
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
