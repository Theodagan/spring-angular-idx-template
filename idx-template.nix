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
      rm README.md
    fi

    for dir in ressources resources; do
      if [ -d "$dir" ]; then
        rm -rf "$dir"
      fi
    done

    if [ "${github_url}" != "" ] && [ "${github_url}" != "$DEFAULT_REPO" ]; then
      git clone ${github_url} "$out"
      cd "$out"

      mkdir -p $out/.idx
      echo "Bootstraping begin" >> $out/.idx/bootstrap.log

      # 📦 Install frontend dependencies if applicable
      if [ -f ${frontend_path}/package.json ]; then
        echo "📦 Installing frontend dependencies..." >> $out/.idx/bootstrap.log
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
        echo "⚙️ Building backend with Maven...">> $out/.idx/bootstrap.log
        cd ${backend_path}
        mvn clean install  || {
            echo ""
            echo "❌ Tests failed! Retrying without tests..." >> $out/.idx/bootstrap.log
            echo "⚠️ Backend app will try to boot but tests are skipped."
            echo ""
            mvn clean install -DskipTests 
          }
        cd ..
      fi

    else
      echo "🆕 No GitHub URL provided, scaffolding new Angular + Spring Boot app..." >> $out/.idx/bootstrap.log

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

      mvn clean install
      cd ..
    fi

    echo "📁 Updating .gitignore" >> $out/.idx/bootstrap.log
    cat <<EOF >> .gitignore
.idx/
EOF
    sort -u .gitignore -o .gitignore

    echo "🧪 Generating .idx/dev.nix with user-defined settings" >> $out/.idx/bootstrap.log
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
        install = "echo '🔥 install hook running' >&2 && cd  ${backend_path}  && echo '📦 installing backend' >&2 && mvn clean install -DskipTests || echo '⚠️ Backend build failed, skipping backend run' >&2 && SPRING_APPLICATION_JSON='{\"server\":{\"address\":\"0.0.0.0\"}}' mvn spring-boot:run & || echo '⚠️ Backend failed to start, continuing...' >&2 && cd ../ ${frontend_path}  && echo '📦 installing frontend' >&2 && npm install && echo '🚀 starting frontend' >&2 && npx ng serve --host 0.0.0.0 --port 4200 --disable-host-check & wait";
      };
      onStart = {
        runServer = "cd back && SPRING_APPLICATION_JSON='{\"server\":{\"address\":\"0.0.0.0\"}}' mvn spring-boot:run & sleep 5 && cd ../front && npx ng serve --host 0.0.0.0 --port 4200 --disable-host-check";      
      };
    };

  };
}
EOF

    echo "✅ Bootstrap complete " >> $out/.idx/bootstrap.log
  '';
}