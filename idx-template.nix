{ pkgs
, github_url ? ""
, frontend_path ? "frontend"
, backend_path ? "backend"
, java_version ? "17"
, angular_cli_version ? "14"
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
    pkgs.nodejs_18
    pkgs.mysql
    pkgs.maven
    jdkPackage
    pkgs.unzip
    pkgs.curl
  ];
 
  bootstrap = ''
    echo "🛠 Initializing workspace in $out..."

    DEFAULT_REPO=""

    # 🧹 Clean up README.md and internal template-only folders
    if [ -f README.md ]; then
      echo "🧹 Removing template README.md before continuing"
      rm README.md
    fi

    for dir in ressources resources; do
      if [ -d "$dir" ]; then
        echo "🧹 Removing /$dir folder (template-only)"
        rm -rf "$dir"
      fi
    done

    if [ "${github_url}" != "" ] && [ "${github_url}" != "$DEFAULT_REPO" ]; then
      echo "🔗 Cloning repository from: ${github_url}"
      git clone ${github_url} "$out"
      cd "$out"

      # 📦 Install frontend dependencies if applicable
      if [ -f ${frontend_path}/package.json ]; then
        echo "📦 Installing frontend dependencies..."
        cd ${frontend_path}
        if [ -f package-lock.json ]; then
          npm ci
        else
          npm install
        fi
        cd ..
      fi

      # ⚙️ Build backend if applicable
      if [ -f ${backend_path}/pom.xml ]; then
        echo "⚙️ Building backend with Maven..."
        cd ${backend_path}
        ./mvnw clean install || mvn clean install
        cd ..
      fi

    else
      echo "🆕 No GitHub URL provided, scaffolding new Angular + Spring Boot app..."

      mkdir -p "$out"
      cd "$out"

      # ▶️ Scaffold Angular
      mkdir -p ${frontend_path}
      cd ${frontend_path}
      npm install @angular/cli@${angular_cli_version}
      ng new ${frontend_path} --directory . --skip-install --skip-git --defaults
      npm install
      cd ..

      # ▶️ Scaffold Spring Boot via start.spring.io
      mkdir -p ${backend_path}
      cd ${backend_path}
      curl https://start.spring.io/starter.zip \
        -d dependencies=web,data-jpa,mysql \
        -d type=maven-project \
        -d language=java \
        -d bootVersion=3.2.4 \
        -d baseDir=. \
        -d packageName=com.example.demo \
        -d name=demo \
        -o starter.zip
      unzip starter.zip
      rm starter.zip

      echo "🔐 Injecting database credentials into Spring Boot application.properties"
      cat <<EOF > src/main/resources/application.properties
spring.datasource.url=jdbc:mysql://localhost:${mysql_port}/${mysql_database}
spring.datasource.username=${mysql_user}
spring.datasource.password=${mysql_password}
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
EOF

      ./mvnw clean install
      cd ..
    fi

    echo "📁 Updating .gitignore"
    cat <<EOF >> .gitignore
.idx/
dev.nix
idx-template.nix
idx-template.json
EOF
    sort -u .gitignore -o .gitignore

    echo "🌐 Creating Angular proxy config at .idx/proxy.conf.json"
    mkdir -p .idx
    cat <<EOF > .idx/proxy.conf.json
{
  "/api": {
    "target": "http://localhost:8080",
    "secure": false,
    "changeOrigin": true,
    "logLevel": "info"
  }
}
EOF

    echo "🧪 Generating .idx/dev.nix with user-defined settings"
    cat <<EOF > .idx/dev.nix
{ pkgs, config, ... }:

let
  jdkPackage = pkgs.${"openjdk" + java_version};
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
        angular-cli = "npm install @angular/cli@${angular_cli_version}";
        npm-install = ""
          if [ -f ${frontend_path}/package.json ]; then
            cd ${frontend_path}
            npm ci || npm install
          fi
        "";
        maven-build = ""
          if [ -f ${backend_path}/pom.xml ]; then
            cd ${backend_path}
            ./mvnw clean install || mvn clean install
          fi
        "";
      };

      onStart = {
        backend-run = ""
          if [ -f ${backend_path}/pom.xml ]; then
            cd ${backend_path}
            ./mvnw spring-boot:run || mvn spring-boot:run &
          fi
        "";
        frontend-run = ""
          if [ -f ${frontend_path}/package.json ]; then
            cd ${frontend_path}
            ng serve --proxy-config .idx/proxy.conf.json --port \$PORT --host 0.0.0.0 --disable-host-check &
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
          "\$PORT"
          "--host"
          "0.0.0.0"
          "--disable-host-check"
        ];
      };
    };
  };
}
EOF

    echo "✅ Bootstrap complete "
  '';
}