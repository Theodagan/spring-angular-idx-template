{ inputs, ... }:

{
  install = ''
    DEFAULT_REPO=""

    if [ "${inputs.github_url}" != "" ] && [ "${inputs.github_url}" != "$DEFAULT_REPO" ]; then
      echo "🔧 Cloning repository from: ${inputs.github_url}"
      git clone ${inputs.github_url} project
      cd project
    else
      echo "🆕 No GitHub URL provided, scaffolding new Angular + Spring Boot app..."

      # Angular app scaffold
      mkdir -p frontend
      cd frontend
      npm install -g @angular/cli@${inputs.angular_cli_version}
      ng new . --skip-install --skip-git --defaults
      npm install
      cd ..

      # Spring Boot app scaffold
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

    echo "📁 Adding .idx/ to .gitignore"
    echo ".idx/" >> .gitignore
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