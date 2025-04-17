{ inputs, ... }:

{
  install = ''
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

    if [ "${inputs.github_url}" != "" ] && [ "${inputs.github_url}" != "$DEFAULT_REPO" ]; then
      echo "🔧 Cloning repository from: ${inputs.github_url}"
      git clone ${inputs.github_url} ${inputs.project_name}
      cd ${inputs.project_name}

      # 📦 Install frontend dependencies if applicable
      if [ -f frontend/package.json ]; then
        echo "📦 Installing frontend dependencies..."
        cd frontend
        npm ci || npm install
        cd ..
      fi

      # ⚙️ Build backend if applicable
      if [ -f backend/pom.xml ]; then
        echo "⚙️ Building backend with Maven..."
        cd backend
        ./mvnw clean install || mvn clean install
        cd ..
      fi

    else
      echo "🆕 No GitHub URL provided, scaffolding new Angular + Spring Boot app..."

      mkdir -p ${inputs.project_name}
      cd ${inputs.project_name}

      # ▶️ Scaffold Angular
      mkdir -p frontend
      cd frontend
      npm install -g @angular/cli@${inputs.angular_cli_version}
      ng new . --skip-install --skip-git --defaults
      npm install
      cd ..

      # ▶️ Scaffold Spring Boot via start.spring.io
      mkdir -p backend
      cd backend
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
spring.datasource.url=jdbc:mysql://localhost:\${MYSQL_PORT}/\${MYSQL_DATABASE}
spring.datasource.username=\${MYSQL_USER}
spring.datasource.password=\${MYSQL_PASSWORD}
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

    echo "✅ Setup complete!"
  '';
}
