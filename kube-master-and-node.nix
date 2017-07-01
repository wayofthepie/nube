{
  kube =
    {
      deployment.targetEnv = "virtualbox";
      services.kubernetes.roles = ["master" "node"];
    };
}
