{
  kube = { pkgs, ... }:
  let
    runWithOpenSSL = file: cmd: pkgs.runCommand file {
      buildInputs = [ pkgs.openssl ];
    } cmd;
    caKey = runWithOpenSSL "ca-key.pem" "openssl genrsa -out $out 2048";
    rootCaFile =
      runWithOpenSSL "root-ca.pem" ''
        openssl req -x509 -new -nodes -key ${caKey} -out $out -days 365 \
          -subj "/CN=root-ca"
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
        controllerManager.enable = true;
        controllerManager.rootCaFile = rootCaFile;
      };

      networking.firewall.allowedTCPPortRanges = [{ from = 30000; to = 32767; }];
      networking.nameservers = ["8.8.8.8"];
    };
}
