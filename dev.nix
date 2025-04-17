# dev.nix
{ pkgs, config, ... }:

let
  javaVersion = config.inputs.java_version or "11";
  angularCliVersion = config.inputs.angular_cli_version or "14";
  jdkPackage = builtins.getAttr ("openjdk" + javaVersion) pkgs;
in
{
  channel = "stable-24.05";

  packages = [
    jdkPackage
    pkgs.nodejs_20
    pkgs.mysql
    pkgs.maven
    pkgs.git
  ];

  env = {
    JAVA_HOME = "${jdkPackage.home}";
    MYSQL_USER = "dev";
    MYSQL_PASSWORD = "password";
    MYSQL_DATABASE = "dev_db";
    MYSQL_PORT = "3306";
  };

  services.mysql.enable = true;

  idx = {
    extensions = [
      "angular.ng-template"
      "vscjava.vscode-java-pack"
      "redhat.java"
    ];

    workspace = {
      onCreate = {
        angular-cli = "npm install -g @angular/cli@${angularCliVersion}";
        npm-install = ''
          if [ -f frontend/package.json ]; then
            cd frontend
            npm ci || npm install
          fi
        '';
        maven-build = ''
          if [ -f backend/pom.xml ]; then
            cd backend
            ./mvnw clean install || mvn clean install
          fi
        '';
      };

      onStart = {
        backend-run = ''
          if [ -f backend/pom.xml ]; then
            cd backend
            ./mvnw spring-boot:run || mvn spring-boot:run &
          fi
        '';
        frontend-run = ''
          if [ -f frontend/package.json ]; then
            cd frontend
            ng serve --proxy-config .idx/proxy.conf.json --port $PORT --host 0.0.0.0 --disable-host-check &
          fi
        '';
      };

      default.openFiles = [
        "frontend/src/app/app.component.ts"
        "backend/src/main/java/com/example/demo/DemoApplication.java"
        "backend/src/main/resources/application.properties"
      ];
    };

    previews = {
      enable = true;
      previews.web = {
        manager = "web";
        command = [
          "ng"
          "serve"
          "--proxy-config"
          ".idx/proxy.conf.json"
          "--port"
          "$PORT"
          "--host"
          "0.0.0.0"
          "--disable-host-check"
        ];
      };
    };
  };
}