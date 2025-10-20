# 🧩 Documentación del Proyecto de Microservicios con Redis y Python

## 📘 Descripción General

Este proyecto consiste en la ejecución e integración de un **sistema
distribuido basado en microservicios**, donde se emplea **Redis** como
sistema de mensajería y almacenamiento temporal, y **Python** como
lenguaje de procesamiento.

El proyecto fue clonado desde el repositorio `microservice-app-example`,
el cual incluye varios componentes que se comunican mediante **pub/sub**
de Redis.

------------------------------------------------------------------------

## ⚙️ Entorno de Trabajo

**Sistema base:** Ubuntu Server (en máquina virtual)\
**Lenguaje:** Python 3.x\
**Dependencias:** Redis, Flask, y librerías de Python.\
**Versión de Java:** OpenJDK 8 (según README del proyecto).

------------------------------------------------------------------------

## 🚀 Pasos Realizados

### 1. Clonación del Repositorio

``` bash
git clone https://github.com/GoogleCloudPlatform/microservice-app-example.git
cd microservice-app-example/log-message-processor
```

------------------------------------------------------------------------

### 2. Verificación del Entorno y Dependencias

Se validó que el proyecto utiliza **OpenJDK 8**, aunque el usuario posee
**Amazon Corretto 23 (compatible)**.\
Redis fue instalado y levantado en el entorno local:

``` bash
sudo apt install redis-server -y
sudo systemctl enable redis-server
sudo systemctl start redis-server
redis-cli ping
# Respuesta: PONG
```

------------------------------------------------------------------------

### 3. Ejecución del Servicio Python

El servicio principal `main.py` se ejecuta con las variables de entorno
necesarias:

``` bash
REDIS_HOST=127.0.0.1 REDIS_PORT=6379 REDIS_CHANNEL=log_channel python3 main.py
```

El script espera mensajes publicados en el canal `log_channel` de Redis
y los procesa.

------------------------------------------------------------------------

### 4. Mensaje de Prueba y Error Detectado

Durante la prueba, el sistema arrojó el siguiente error:

    message received after waiting for 148ms: 'int' object has no attribute 'decode'

Este error se debe a que Redis puede retornar valores en formato binario
o entero, según el tipo de dato enviado. Al intentar decodificar un
valor entero, se genera el error
`'int' object has no attribute 'decode'`.

------------------------------------------------------------------------

## 🧠 Análisis Técnico del Error

El error indica que la función que recibe los mensajes está intentando
ejecutar `message.decode('utf-8')`, pero el contenido recibido no es
texto sino un número entero.

### 🔧 Solución Propuesta

Modificar el bloque de lectura para validar el tipo de dato antes de
decodificarlo:

``` python
if isinstance(message['data'], bytes):
    decoded_message = message['data'].decode('utf-8')
else:
    decoded_message = str(message['data'])
```

------------------------------------------------------------------------

## 🧩 Flujo del Sistema

1.  **Redis** actúa como *broker* de mensajes.
2.  **Python** suscribe el proceso `log-message-processor` al canal
    `log_channel`.
3.  Cuando otro servicio publica un mensaje en Redis, este script lo
    recibe y lo procesa.
4.  Se mide el tiempo de espera entre publicaciones y recepciones
    (latencia).

------------------------------------------------------------------------

## 🧰 Tecnologías Utilizadas

  Tecnología               Descripción
  ------------------------ ----------------------------------------------------
  **Redis**                Sistema de mensajería y almacenamiento en memoria.
  **Python 3**             Lenguaje de programación para el microservicio.
  **Flask**                Framework opcional para la capa API.
  **OpenJDK 8**            Requisito base del proyecto.
  **Amazon Corretto 23**   Entorno compatible usado por el usuario.

------------------------------------------------------------------------

## 📈 Conclusiones

-   El entorno de ejecución fue correctamente preparado con Redis y
    Python.
-   La conexión y suscripción al canal Redis fue exitosa.
-   Se detectó un error menor en el manejo de tipos de datos (`int` vs
    `bytes`), solucionable mediante validación previa.
-   La estructura del proyecto sigue buenas prácticas de microservicios:
    modularidad, comunicación asíncrona y desacoplamiento.

------------------------------------------------------------------------

## 🗂️ Archivos Principales

  -----------------------------------------------------------------------
  Archivo                       Descripción
  ----------------------------- -----------------------------------------
  `main.py`                     Servicio principal que escucha mensajes
                                desde Redis.

  `README.md`                   Documentación original del repositorio.

  `requirements.txt`            Dependencias de Python necesarias para la
                                ejecución.

  `Dockerfile`                  Define la imagen para ejecutar el
                                microservicio.
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 📜 Comandos Clave

``` bash
# Iniciar Redis
sudo systemctl start redis-server

# Verificar estado
redis-cli ping

# Ejecutar el microservicio
REDIS_HOST=127.0.0.1 REDIS_PORT=6379 REDIS_CHANNEL=log_channel python3 main.py
```

------------------------------------------------------------------------

**Autor:** Samuel\
**Fecha:** 20 de octubre de 2025\
**Proyecto:** Laboratorio de Microservicios -- Redis y Python\
**Institución:** Ingeniería Telemática -- Universidad I2T
