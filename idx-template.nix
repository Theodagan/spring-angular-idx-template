{ pkgs, project_name, java_version ? "17", angular_cli_version ? "14", mysql_user ? "dev", mysql_password ? "password", mysql_database ? "dev_db", mysql_port ? "3306", ... }:

{
  packages = [
    pkgs.nodejs
    pkgs.curl
    pkgs.jq
    pkgs.git
  ];

  bootstrap = ''
    mkdir -p "$out"

    echo "📁 Copie des fichiers de template vers le workspace..."
    cp -rf ${./.} "$out"
    chmod -R +w "$out"

    echo "🧹 Nettoyage des fichiers du template..."
    rm -rf "$out/.git" "$out/idx-template".{nix,json} "$out/README.md" "$out/ressources"

    echo "📝 Génération dynamique du fichier .idx/dev.nix..."
    mkdir -p "$out/.idx"
    cat <<EOF > "$out/.idx/dev.nix"
{ pkgs, config, ... }:

let
  javaVersion = "${java_version}";
  angularCliVersion = "${angular_cli_version}";
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
    JAVA_HOME = "\${jdkPackage.home}";
    MYSQL_USER = "${mysql_user}";
    MYSQL_PASSWORD = "${mysql_password}";
    MYSQL_DATABASE = "${mysql_database}";
    MYSQL_PORT = "${mysql_port}";
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
        angular-cli = "npm install -g @angular/cli@\${angularCliVersion}";
        npm-install = ""
          if [ -f frontend/package.json ]; then
            cd frontend
            npm ci || npm install
          fi
        "";
        maven-build = ""
          if [ -f backend/pom.xml ]; then
            cd backend
            ./mvnw clean install || mvn clean install
          fi
        "";
      };

      onStart = {
        backend-run = ""
          if [ -f backend/pom.xml ]; then
            cd backend
            ./mvnw spring-boot:run || mvn spring-boot:run &
          fi
        "";
        frontend-run = ""
          if [ -f frontend/package.json ]; then
            cd frontend
            ng serve --proxy-config .idx/proxy.conf.json --port $PORT --host 0.0.0.0 --disable-host-check &
          fi
        "";
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
EOF

    echo "✅ Template installé avec succès dans $out"
  '';
}