# Spring Boot + Angular + MySQL — IDX Template

This is a reusable [Google Project IDX](https://idx.google.com/) template that scaffolds or bootstraps a full-stack environment with:

- ☕ Java Spring Boot (Maven)
- ⚙️ Angular CLI (custom version support)
- 🐬 MySQL (preconfigured with credentials)
- 🌐 Automatic proxy from Angular to backend (`/api`)
- 🧠 Smart setup via user inputs or GitHub cloning

---

## 🚀 Launch this template in Google IDX

You can open this template directly in Google IDX with one click:

👉 [**Launch in Google IDX**](https://idx.google.com/workspace/new?template_url=https://github.com/Theodagan/spring-angular-idx-template.git)

---

## 🛠️ What This Template Does

When you launch this in IDX:

- If you provide a GitHub repo URL, it will clone it
- If left blank, it will scaffold:
  - An Angular app in `frontend/`
  - A Spring Boot app in `backend/` via [start.spring.io](https://start.spring.io/)
- Sets up MySQL with default credentials:
  - `user=dev`
  - `password=password`
  - `database=dev_db`
- Injects those credentials into `application.properties`
- Automatically starts both frontend and backend
- Adds `.idx/` to `.gitignore`
- Sets up a proxy from Angular to Spring at `/api`

---

## 📥 Available Inputs

When launching this workspace, you can configure:

| Input ID              | Description                                  | Default |
|-----------------------|----------------------------------------------|---------|
| `github_url`          | GitHub repo to clone                         | *(blank)* |
| `java_version`        | Java version to install (e.g., 11, 17, 21)   | `11`    |
| `angular_cli_version` | Angular CLI version (e.g., 14, 15, latest)   | `14`    |
| `java_app_path`       | Relative path to backend app                 | `backend` |
| `angular_app_path`    | Relative path to frontend app                | `frontend` |

---

## 🧱 Project Structure After Scaffold

```plaintext
project-root/
├── backend/
│   └── src/main/java/com/example/demo
│   └── src/main/resources/application.properties
├── frontend/
│   └── src/app/app.component.ts
├── .idx/
│   └── dev.nix
│   └── proxy.conf.json
├── .gitignore
├── idx-template.nix
├── idx-template.json
├── dev.nix
