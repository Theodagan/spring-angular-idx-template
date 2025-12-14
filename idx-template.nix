{ pkgs
, github_url ? ""
, frontend_path ? "frontend"
, backend_path ? "backend"
, java_version ? "21"
, angular_cli_version ? "latest"
, spring_boot_version ? "3.2.4"
, mysql_user ? "dev"
, mysql_password ? "password"
, mysql_database ? "dev_db"
, mysql_port ? "3306"
}:

let
  jdkPackage = builtins.getAttr ("openjdk" + java_version) pkgs;
in
{
  packages = [
    pkgs.git
    pkgs.nodejs_22
    pkgs.mysql
    pkgs.maven
    jdkPackage
    pkgs.unzip
    pkgs.curl
    pkgs.spring-boot-cli 
  ];

  bootstrap = ''
    set -eu
    echo "🛠 Initializing workspace in $out..."
    DEFAULT_REPO=""

    FRONTEND="${frontend_path}"
    BACKEND="${backend_path}"

    # 🧹 Clean up README.md and template-only folders
    [ -f README.md ] && rm README.md
    for dir in ressources resources; do
      [ -d "$dir" ] && rm -rf "$dir"
    done

    if [ "${github_url}" != "" ] && [ "${github_url}" != "$DEFAULT_REPO" ]; then
      git clone ${github_url} "$out"
      cd "$out"
      rm -rf .git
      mkdir -p .idx
      echo "📦 Cloned from GitHub: ${github_url}" >> .idx/bootstrap.log

    else
      echo "🆕 No GitHub URL provided, scaffolding new Angular + Spring Boot app..."

      mkdir -p "$out"
      cd "$out"
      
      # 📝 Ensure log directory exists before writing
      mkdir -p .idx
      echo "📁 Scaffolding Angular + Spring Boot app..." >> .idx/bootstrap.log

      echo "📍 FRONTEND=$FRONTEND BACKEND=$BACKEND" 
      echo "📍VALUES:  FRONTEND=${frontend_path} BACKEND=${backend_path}"   
      
      # ▶️ Scaffold Angular
      mkdir -p "$FRONTEND"
      (
        cd "$FRONTEND"
        echo "📦 Creating Angular app in $FRONTEND..." >> ../.idx/bootstrap.log
        npx @angular/cli@${angular_cli_version} new app --directory . --skip-install --skip-git --defaults      )
      
      # ▶️ Scaffold Spring Boot
      mkdir -p "$BACKEND"
      echo "📦 Creating Spring Boot app using spring init..." >> .idx/bootstrap.log
      (
        cd "$BACKEND"
        spring init \
          --dependencies=web,data-jpa,mysql, security \
          --build=maven \
          --java-version=${java_version} \
          --package-name=com.example.demo \
          demo
      
        mv demo/* . && rm -rf demo
      )

      # ➕ Inject DB config
      cat <<EOF > "$BACKEND/src/main/resources/application.properties"
spring.datasource.url=jdbc:mysql://localhost:${mysql_port}/${mysql_database}?allowPublicKeyRetrieval=true
spring.datasource.username=${mysql_user}
spring.datasource.password=${mysql_password}
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
EOF

      # ➕ Crée le script .idx/init-db.sh
cat <<'EOF' > .idx/init-db.sh
#!/usr/bin/env bash

# Wait for MySQL to start
echo "⏳ Waiting for MySQL to be ready..."
until mysqladmin ping -h"127.0.0.1" --silent; do
  sleep 1
done

echo "✅ MySQL is up. Creating user and database..."

mysql -u root <<EOSQL
CREATE DATABASE IF NOT EXISTS ${mysql_database};
CREATE USER IF NOT EXISTS '${mysql_user}'@'localhost' IDENTIFIED BY '${mysql_password}';
GRANT ALL PRIVILEGES ON ${mysql_database}.* TO '${mysql_user}'@'localhost';
FLUSH PRIVILEGES;
EOSQL

echo "✅ Database and user setup completed."
EOF

      chmod +x .idx/init-db.sh
    fi

    # 📁 Update .gitignore safely
    [ -f .gitignore ] || touch .gitignore
    grep -qxF '.idx/' .gitignore || echo '.idx/' >> .gitignore
    sort -u .gitignore -o .gitignore

    # 🧪 Generate dev.nix
    echo "🔧 Generating .idx/dev.nix..." >> .idx/bootstrap.log
    mkdir -p .idx
    cat <<EOF > .idx/dev.nix
{ pkgs, ... }:
{
  channel = "stable-23.11";

  packages = [
    pkgs.openjdk${java_version}
    pkgs.nodejs_20
    pkgs.mysql
    pkgs.maven
    pkgs.git
    pkgs.nodePackages."@angular/cli"
  ];

  env = {
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
        install = "./.idx/init-db.sh && (cd ${backend_path}/ && mvn clean install -DskipTests) & cd ${frontend_path}/ && npm install";      
      };
      onStart = {
        runServer = "(cd ${backend_path}/ && mvn spring-boot:run) & cd ${frontend_path}/ && ng serve";      
      };
    };

    previews = {
      enable = true;
      previews.web = {
        manager = "web";
        command = [
          "sh"
          "-c"
          "cd ${frontend_path} && ng serve --port 4200 --host 0.0.0.0"
        ];
      };
    };

  };
}
EOF

    echo "✅ Bootstrap complete" >> .idx/bootstrap.log
  '';
}
