# Dockerizacion y kubernetes de microservicios 

![actividad](/arch-img/Microservices.png)


## Estructura del repositorio

```
├── 📁 arch-img
│   └── 🖼️ Microservices.png
├── 📁 auth-api
│   ├── ⚙️ .gitignore
│   ├── 📄 Gopkg.lock
│   ├── ⚙️ Gopkg.toml
│   ├── 📝 README.md
│   ├── 📄 go.mod
│   ├── 📄 go.sum
│   ├── 🐹 main.go
│   ├── 🐹 tracing.go
│   └── 🐹 user.go
├── 📁 doc          <---- Documentacion inicial ----->
│   └── 📝 README.md
├── 📁 dockerfiles  <--- Archivos del taller 1 ----- >
│   ├── ⚙️ docker-compose.yml
│   ├── 📄 dockerfile.authApi
│   ├── 📄 dockerfile.frontend
│   ├── 📄 dockerfile.log-message
│   ├── 📄 dockerfile.todoApi
│   └── 📄 dockerfile.userApi
├── 📁 frontend
│   ├── 📁 config
│   │   ├── 📄 dev.env.js
│   │   ├── 📄 index.js
│   │   └── 📄 prod.env.js
│   ├── 📁 src
│   │   ├── 📁 assets
│   │   │   └── 🖼️ logo.png
│   │   ├── 📁 components
│   │   │   ├── 📁 common
│   │   │   │   └── 📄 Spinner.vue
│   │   │   ├── 📄 App.vue
│   │   │   ├── 📄 AppNav.vue
│   │   │   ├── 📄 Login.vue
│   │   │   ├── 📄 TodoItem.vue
│   │   │   └── 📄 Todos.vue
│   │   ├── 📁 router
│   │   │   └── 📄 index.js
│   │   ├── 📁 store
│   │   │   ├── 📄 index.js
│   │   │   ├── 📄 mutations.js
│   │   │   ├── 📄 plugins.js
│   │   │   └── 📄 state.js
│   │   ├── 📄 auth.js
│   │   ├── 📄 main.js
│   │   └── 📄 zipkin.js
│   ├── 📁 static
│   │   └── ⚙️ .gitkeep
│   ├── ⚙️ .editorconfig
│   ├── ⚙️ .eslintignore
│   ├── 📄 .eslintrc.js
│   ├── ⚙️ .gitignore
│   ├── 📄 .postcssrc.js
│   ├── 📝 README.md
│   ├── 🌐 index.html
│   ├── ⚙️ package-lock.json
│   └── ⚙️ package.json
├── 📁 log-message-processor
│   ├── 📝 README.md
│   ├── 🐍 main.py
│   └── 📄 requirements.txt
├── 📁 todos-api
│   ├── ⚙️ .gitignore
│   ├── 📝 README.md
│   ├── ⚙️ package-lock.json
│   ├── ⚙️ package.json
│   ├── 📄 routes.js
│   ├── 📄 server.js
│   ├── 📄 todoController.js
│   └── 📄 todos-api
├── 📁 users-api
│   ├── 📁 .mvn
│   │   └── 📁 wrapper
│   │       ├── 📄 maven-wrapper.jar
│   │       └── 📄 maven-wrapper.properties
│   ├── 📁 src
│   │   ├── 📁 main
│   │   │   ├── 📁 java
│   │   │   │   └── 📁 com
│   │   │   │       └── 📁 elgris
│   │   │   │           └── 📁 usersapi
│   │   │   │               ├── 📁 api
│   │   │   │               │   └── ☕ UsersController.java
│   │   │   │               ├── 📁 configuration
│   │   │   │               │   └── ☕ SecurityConfiguration.java
│   │   │   │               ├── 📁 models
│   │   │   │               │   ├── ☕ User.java
│   │   │   │               │   └── ☕ UserRole.java
│   │   │   │               ├── 📁 repository
│   │   │   │               │   └── ☕ UserRepository.java
│   │   │   │               ├── 📁 security
│   │   │   │               │   ├── ☕ AccessUserFilter.java
│   │   │   │               │   └── ☕ JwtAuthenticationFilter.java
│   │   │   │               └── ☕ UsersApiApplication.java
│   │   │   └── 📁 resources
│   │   │       ├── 📄 application.properties
│   │   │       └── 📄 data.sql
│   │   └── 📁 test
│   │       └── 📁 java
│   │           └── 📁 com
│   │               └── 📁 elgris
│   │                   └── 📁 usersapi
│   │                       └── ☕ UsersApiApplicationTests.java
│   ├── ⚙️ .gitignore
│   ├── 📝 README.md
│   ├── 📄 mvnw
│   ├── 📄 mvnw.cmd
│   └── ⚙️ pom.xml
├── 📄 LICENSE
├── 📝 README.md
├── 📦 dockerfiles.zip
└── 📄 kubectl.sha256
```
## Resumen de la actividad
 > Taller 1 **Dokerizacion** 

 El laboratorio consiste en levantar todos los servicios del diagrama en docker garantizando que fuese funcional

 En este caso ya funciona si vamos al directorio de ````dockerfie```` tenemos los dockerfiles para crear cada servicio de manera manual siguiendo las indicaciones de la documentacion de dicho servicio.




 ```
├── ⚙️ docker-compose.yml
├── 📄 dockerfile.authApi
├── 📄 dockerfile.frontend
├── 📄 dockerfile.log-message
├── 📄 dockerfile.todoApi
└── 📄 dockerfile.userApi
```

 Una vez probado los dockerfiles  que fuesen funcionales, migramos a automatizar estos servicios con un docker-compose, donde con solo aplicar el comando ````docker compose up```` se levantarian y se configurarian segun las politicas que el manifiesto tenga

 > PD: Esto fue testeado en un entorno de codespace de github, para que se pueda ver bien la activad hay que configurar los port forwarding para que los contenedores puedan comunicarse con los puertos del pc.

  Es totalmente funcional en on-premise
  

 > Taller 2 **Kubernetes**

 Como dijo un filosofo muy famoso 
 <p align="center">"Aqui viene lo chido"</p>
<p align="center">  -Luisito comunica-</p>

En la clase de Plataformas 2 vimos temas de kubernetes importantes como 

 1. Arquitectura master node - worker node
 2. Despliegue con minikube
 3. kubeconfig, services and deployments
 4. Replicaset
 5. Networking
 6. configmaps and secrets
 7. Autoscaling
 8. network policies 
 
 Entonces como consiste la actividad? 
 
 