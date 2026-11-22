{ config, lib, ... }:
let
  namespace = "jenkins";
  jenkinsHome = "/var/lib/jenkins";
  clusterIP = "10.43.0.80";
  plugins = lib.filter (line: line != "") (lib.splitString "\n" (builtins.readFile ./plugins.txt));
  adminPassword = config.age.secrets.jenkins-admin-password;
  matchPassword = config.age.secrets.ios-build-match-password;
  webhookToken = config.age.secrets.jenkins-gitea-webhook-token;
  ascApiKey = config.age.secrets.appstore-connect-api-key;
  # modules/shared-secrets.nix, SLACK_WEBHOOK_URL=... env file
  slackWebhook = config.age.secrets.slack-webhook;
in
{
  age.secrets = {
    # /run/agenix/<file name>에 해당 암호화된 age 파일을 복호화해서 위치하게 만든다.
    jenkins-admin-password.file = ../../../../secrets/jenkins-admin-password.age;
    ios-build-match-password.file = ../../../../secrets/ios-build-match-password.age;
    jenkins-gitea-webhook-token.file = ../../../../secrets/jenkins-gitea-webhook-token.age;
    appstore-connect-api-key.file = ../../../../secrets/appstore-connect-api-key.age;
  };

  # jenkins가 실행되는 uid, gid로 hostpath mount 디렉터리를 바꿔서 파일 rw가 가능하도록 만들어야 함
  systemd.tmpfiles.rules = [ "d ${jenkinsHome} 0750 1000 1000 -" ];

  # agenix 값을 k8s 시크릿으로 만드는 설정
  systemd.services.jenkins-k8s-secrets = {
    description = "Create the Jenkins Kubernetes Secrets from agenix";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    partOf = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [
      adminPassword.file
      matchPassword.file
      webhookToken.file
      slackWebhook.file
      ascApiKey.file
    ];
    path = [ config.services.k3s.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "5min";
    };
    script = ''
      # wait API server
      until k3s kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 2; done

      apply() { k3s kubectl apply --server-side --force-conflicts -f -; }
      k3s kubectl create namespace ${namespace} --dry-run=client -o yaml | apply
      k3s kubectl -n ${namespace} create secret generic jenkins-admin \
        --from-literal=jenkins-admin-user=admin \
        --from-file=jenkins-admin-password=${adminPassword.path} \
        --dry-run=client -o yaml | apply
      k3s kubectl -n ${namespace} create secret generic jenkins-credentials \
        --from-file=match-password=${matchPassword.path} \
        --from-file=gitea-webhook-token=${webhookToken.path} \
        --from-file=slack-webhook-url=<(sed -n 's/^SLACK_WEBHOOK_URL=//p' ${slackWebhook.path}) \
        --from-file=appstore-connect-api-key=${ascApiKey.path} \
        --dry-run=client -o yaml | apply
    '';
  };

  services.k3s.autoDeployCharts.jenkins = {
    repo = "https://charts.jenkins.io";
    name = "jenkins";
    version = "5.13.1";
    hash = "sha256-iwk9OFjcd4C7F93HRDkJYoSPlcv21QpmGiMFt/2Bud0=";
    targetNamespace = namespace;
    createNamespace = true;

    values = {
      controller = {
        inherit clusterIP;
        image.pullPolicy = "IfNotPresent";
        resources = {
          requests = {
            cpu = "100m";
            memory = "512Mi";
          };
          limits = {
            cpu = "2000m";
            memory = "2Gi";
          };
        };
        # jcasc가 적용되기 전에 tcp agent port가 열리는것을 막기 위해 slaveAgentPort=-1 를 명시 (안해도 큰 상관은 없음)
        javaOpts = "-Xms256m -Xmx1g -Djenkins.model.Jenkins.slaveAgentPort=-1";
        admin = {
          createSecret = false;
          existingSecret = "jenkins-admin";
        };
        additionalExistingSecrets = [
          {
            name = "jenkins-credentials";
            keyName = "match-password";
          }
          {
            name = "jenkins-credentials";
            keyName = "gitea-webhook-token";
          }
          {
            name = "jenkins-credentials";
            keyName = "slack-webhook-url";
          }
          {
            name = "jenkins-credentials";
            keyName = "appstore-connect-api-key";
          }
        ];
        # jenkins agent는 websocket으로 접속하므로 agent listener는 불필요
        agentListenerEnabled = false;
        installPlugins = plugins;
        installLatestPlugins = false;
        installLatestSpecifiedPlugins = false;
        JCasC = {
          # 차트에서 기본적으로 제공하는 jcasc를 비활성화하고, jcasc.yaml을 대신 적용
          # 클로드 설명에 따르면, 기본 제공 jcasc에는 k8s 플러그인이 있어야 사용 가능한 k8s cloud 설정이 있다고 함.
          defaultConfig = false;
          configScripts.ios-build = builtins.readFile ./jcasc.yaml;
        };
      };
      agent.enabled = false;
      persistence.existingClaim = "jenkins-home";
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."jenkins.alicek106.net" = {
      # tailnet 대역에서만 접근 가능
      listen = [{ addr = config.homelab.tailnetIP; port = 80; }];
      locations."/" = {
        proxyPass = "http://${clusterIP}:8080";
        # jenkins worker는 웹소켓으로 접근하므로 true로 설정
        proxyWebsockets = true;
      };
    };
  };

  # hostpath pv, pvc 설정
  services.k3s.manifests.jenkins-storage.content = [
    {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = namespace;
    }
    {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata.name = "jenkins-home";
      spec = {
        capacity.storage = "20Gi";
        accessModes = [ "ReadWriteOnce" ];
        persistentVolumeReclaimPolicy = "Retain";
        # NOTE: 빈 문자열이면 k3s의 local-path-provisioner가 PV를 따로 만들지 않음
        storageClassName = "";
        hostPath = {
          path = jenkinsHome;
          type = "Directory";
        };
        claimRef = {
          inherit namespace;
          name = "jenkins-home";
        };
      };
    }
    {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "jenkins-home";
        inherit namespace;
      };
      spec = {
        accessModes = [ "ReadWriteOnce" ];
        storageClassName = "";
        volumeName = "jenkins-home";
        resources.requests.storage = "20Gi";
      };
    }
  ];
}
