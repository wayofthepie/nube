
let
  pkgs = (import <nixpkgs> {});
  assets = (import ./tls.nix { inherit pkgs; });
  kubeCommonConfig = with assets; {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    deployment.virtualbox.vcpu = 4;
    programs.bash.enableCompletion = true;

    services.flannel = {
      enable = true;
      network = "10.30.0.0/16";
      iface = "enp0s8";
      etcd = {
        endpoints = ["https://etcd1:2379" "https://etcd2:2379" "https://etcd3:2379"];
        keyFile = etcdClientKey;
        certFile = etcdClientCert;
        caFile = caPem;
      };
    };

    # vxlan
    networking.firewall.allowedUDPPorts = [ 8472 ];

    systemd.services.docker.after = ["flannel.service"];
    systemd.services.docker.serviceConfig.EnvironmentFile = "/run/flannel/subnet.env";
    virtualisation.docker.extraOptions = "--iptables=false --ip-masq=false --bip $FLANNEL_SUBNET";
    services.kubernetes = {
      proxy  = {
        enable = true;
        extraOpts = ''
          --masquerade-all
        '';
      };
      kubelet = {
        clusterDns = "192.168.56.101";
        tlsKeyFile = workerKey;
        tlsCertFile = workerCert;
      };
      verbose = true;
      etcd = {
        servers = ["https://etcd1:2379" "https://etcd2:2379" "https://etcd3:2379"];
        keyFile = etcdClientKey;
        certFile = etcdClientCert;
        caFile = caPem;
      };
      kubeconfig = {
        server = "https://192.168.56.101:443";
        caFile = caPem;
        certFile = adminCert;
        keyFile = adminKey;
      };
    };
    environment.systemPackages = with pkgs; [
      bind
      bridge-utils
      nmap
      tcpdump
      telnet
      utillinux
    ];
  };

  kubeMasterConfig = {pkgs, ...}: with assets; {
    require = [kubeCommonConfig];
    networking.interfaces.enp0s8.ip4 = [ { address = "192.168.56.101"; prefixLength = 24; } ];
    networking.firewall.allowedTCPPorts = [ 22 53 443 ];
    networking.firewall.allowedTCPPortRanges = [{ from = 30000; to = 32767; }];
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.dhcpcd.extraConfig = ''
      hostname ""
    '';
    environment.etc."resolv.conf".text = ''
      nameserver 8.8.8.8
    '';

    services.kubernetes = {
      roles = ["master"];
      #scheduler.leaderElect = true;
      #controllerManager.leaderElect = true;
      dns.enable = true;
      apiserver = {
        publicAddress = "0.0.0.0";
        advertiseAddress = "192.168.56.101";
        enable = true;
        tlsKeyFile = apiserverKey;
        tlsCertFile = apiserverCert;
        clientCaFile = caPem;
        serviceAccountKeyFile = caKey;
      };
      controllerManager.enable = true;
      controllerManager.rootCaFile = caPem;
      controllerManager.serviceAccountKeyFile = caKey;
    };
  };
  kubeWorkerConfig = with assets; {
    require = [kubeCommonConfig];
    boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;
    networking.firewall.allowedTCPPorts = [ 10250 ];
    environment.etc."resolv.conf".text = ''
      nameserver 8.8.8.8
    '';

    services.kubernetes = {
      roles = ["node"];
    };
  };
  etcdNodeConfig = with assets; {
    deployment.targetEnv = "virtualbox";
    deployment.virtualbox.headless = true;
    deployment.virtualbox.vcpu = 4;
    environment.etc."resolv.conf".text = ''
      nameserver 8.8.8.8
    '';
    services = {
     etcd = {
       enable = true;
       keyFile = etcdKey;
       certFile = etcdCert;
       trustedCaFile = caPem;
       peerClientCertAuth = true;
       listenClientUrls = ["https://0.0.0.0:2379"];
       listenPeerUrls = ["https://0.0.0.0:2380"];
     };
   };

   environment.variables = {
     ETCDCTL_CERT_FILE = "${etcdClientCert}";
     ETCDCTL_KEY_FILE = "${etcdClientKey}";
     ETCDCTL_CA_FILE = "${caPem}";
     ETCDCTL_PEERS = "https://127.0.0.1:2379";
   };

   networking.firewall.allowedTCPPorts = [ 2379 2380 ];
 };
in {
  etcd1 = {
    require = [etcdNodeConfig];
    services.etcd = {
      advertiseClientUrls = ["https://etcd1:2379"];
      initialCluster = ["etcd1=https://etcd1:2380" "etcd2=https://etcd2:2380" "etcd3=https://etcd3:2380"];
      initialAdvertisePeerUrls = ["https://etcd1:2380"];
    };
  };
  etcd2 = {
    require = [etcdNodeConfig];
    services.etcd = {
      advertiseClientUrls = ["https://etcd2:2379"];
      initialCluster = ["etcd1=https://etcd1:2380" "etcd2=https://etcd2:2380" "etcd3=https://etcd3:2380"];
      initialAdvertisePeerUrls = ["https://etcd2:2380"];
    };
  };
  etcd3 = {
    require = [etcdNodeConfig];
    services.etcd = {
      advertiseClientUrls = ["https://etcd3:2379"];
      initialCluster = ["etcd1=https://etcd1:2380" "etcd2=https://etcd2:2380" "etcd3=https://etcd3:2380"];
      initialAdvertisePeerUrls = ["https://etcd3:2380"];
    };
  };

  kubernetes = {
    require = [kubeMasterConfig];
  };

  kubeWorker1 = {
    require = [kubeWorkerConfig];
  };
}
