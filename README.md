# AutoAudit — Sistema de Auditoría Automatizada

## 1. Descripción del proyecto

AutoAudit es un sistema de auditoría automatizada desarrollado con PostgreSQL, Python y Flask. Su objetivo es registrar los cambios realizados en las tablas de una base de datos, permitiendo identificar qué información fue insertada, modificada o eliminada.

El sistema cuenta con una interfaz web administrativa desde la cual se pueden seleccionar las tablas, columnas y operaciones que serán auditadas, así como activar o desactivar el monitoreo.

También incluye un módulo de reportes para consultar la bitácora, aplicar filtros y exportar los resultados a un archivo CSV.

## 2. Funcionalidades principales

- Inicio de sesión administrativo.
- Detección de tablas y columnas de la base de datos.
- Selección de columnas que serán auditadas.
- Configuración de operaciones INSERT, UPDATE y DELETE.
- Activación y desactivación de auditoría por tabla.
- Registro automático de cambios mediante triggers de PostgreSQL.
- Almacenamiento de valores anteriores y nuevos.
- Registro de fecha, usuario de base de datos, tabla y columna modificada.
- Consulta de bitácora desde una interfaz web.
- Filtros por tabla, operación, usuario y fechas.
- Exportación de reportes en formato CSV.

## 3. Tecnologías utilizadas

- PostgreSQL 18: gestión de la base de datos.
- PL/pgSQL: implementación del motor de auditoría.
- Python 3: programación del servidor.
- Flask: aplicación web.
- Psycopg2: conexión entre Python y PostgreSQL.
- HTML y CSS: interfaz gráfica.
- Python-dotenv: administración de variables de entorno.

## 4. Estructura del proyecto

```text
AutoAudit FINAL/
│
├── app.py
├── requirements.txt
├── README.md
├── .env.example
├── .gitignore
│
├── autoaudit_completo.sql
├── 03_datos_iniciales.sql
│
├── templates/
│   ├── login.html
│   ├── index.html
│   └── reportes.html
│
└── static/
    └── style.css
```

El proyecto también puede incluir el manual de usuario y la documentación técnica.

## 5. Requisitos de instalación

Para ejecutar AutoAudit se necesita:

- Windows con Python 3 instalado.
- PostgreSQL, preferiblemente versión 18.
- pgAdmin 4 o una herramienta equivalente.
- Acceso a una cuenta de PostgreSQL con permisos para crear tablas, funciones y triggers.
- Las dependencias indicadas en `requirements.txt`.

## 6. Instalación de la base de datos

### Paso 1. Crear la base de datos

Abrir pgAdmin 4 y crear una base de datos vacía con el nombre:

`autoaudit_completo`

### Paso 2. Restaurar la estructura

Utilizar el archivo `autoaudit_completo.sql` para restaurar la estructura de la base de datos.

Este archivo contiene las tablas, secuencias, relaciones, restricciones, función de auditoría y triggers.

Como el respaldo se generó únicamente con la estructura, no incluye registros de prueba ni configuraciones anteriores.

### Paso 3. Insertar los eventos iniciales

Una vez restaurada la estructura, abrir Query Tool en la nueva base de datos y ejecutar:

`03_datos_iniciales.sql`

Este script registra los eventos INSERT, UPDATE y DELETE, necesarios para configurar la auditoría desde la interfaz.

**Importante:** el respaldo de tipo Plain generado por pgAdmin puede contener instrucciones específicas de `psql`, por lo que se recomienda restaurarlo con `psql` en lugar de ejecutarlo directamente en Query Tool.

## 7. Configuración de la aplicación

Copiar el archivo `.env.example` y crear otro llamado `.env`.

En este archivo se deben configurar las variables de conexión:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=autoaudit_completo
DB_USER=postgres
DB_PASSWORD=CAMBIAR_POR_CONTRASEÑA_LOCAL

AUTOAUDIT_ADMIN_USER=admin
AUTOAUDIT_ADMIN_PASSWORD=CAMBIAR_POR_CONTRASEÑA_SEGURA
AUTOAUDIT_SECRET_KEY=CAMBIAR_POR_CLAVE_ALEATORIA_LARGA

PORT=5000
```

Las contraseñas deben reemplazarse por valores propios de cada instalación.

**Nunca compartir ni subir el archivo `.env` a GitHub.**

## 8. Instalación de dependencias

Abrir PowerShell o la terminal de Visual Studio Code dentro de la carpeta del proyecto.

Ejecutar:

```powershell
python -m pip install -r requirements.txt
```

## 9. Ejecución del sistema

Iniciar la aplicación mediante:

```powershell
python app.py
```

Abrir el navegador y acceder a:

http://127.0.0.1:5000

Ingresar con el usuario y contraseña administrativos definidos en `.env`.

## 10. Configuración de auditoría

Desde el panel administrativo:

1. Seleccionar una tabla de la base de datos.
2. Presionar «Cargar configuración».
3. Seleccionar las columnas que se desean monitorear.
4. Marcar las operaciones INSERT, UPDATE y/o DELETE.
5. Activar el interruptor de auditoría.
6. Presionar «Guardar cambios».

El motor de PostgreSQL utiliza esta configuración para determinar qué modificaciones deben registrarse.

Cuando la auditoría de una tabla está desactivada, sus operaciones no generan nuevos registros de auditoría.

## 11. Consulta de reportes

Ingresar al módulo «Bitácora y reportes».

Desde esta sección se pueden consultar los registros almacenados y aplicar filtros por:

- Tabla modificada.
- Tipo de operación.
- Usuario de base de datos.
- Fecha inicial.
- Fecha final.

La interfaz muestra hasta 1000 registros por consulta y permite exportar los resultados visibles en formato CSV.

## 12. Pruebas funcionales realizadas

Durante el desarrollo se verificaron las siguientes operaciones sobre la tabla `estudiantes`:

**INSERT:** se comprobó el registro de los valores insertados en las columnas seleccionadas.

**UPDATE:** se comprobó que la bitácora almacenara los valores anteriores y nuevos de las columnas modificadas.

**DELETE:** se comprobó que la eliminación generara registros con los valores anteriores.

**Desactivación:** se desactivó la auditoría y se realizó una inserción de prueba. La bitácora conservó los seis registros existentes, sin generar nuevos registros.

También se verificaron el inicio de sesión, los filtros de reportes y la exportación CSV.

## 13. Consideraciones técnicas

- La interfaz trabaja con las tablas de negocio del esquema `public`.
- Las tablas internas de auditoría se excluyen de la selección administrativa.
- Las operaciones seleccionadas desde la interfaz se aplican a todas las columnas elegidas en una misma configuración.
- El motor utiliza una función genérica de PostgreSQL y triggers asociados a las tablas de negocio.
- La auditoría registra el usuario de la conexión a PostgreSQL.
- El acceso web administrativo utiliza una cuenta configurada mediante variables de entorno.
- La aplicación está preparada para ejecución local y pruebas académicas.

## 14. Seguridad y limitaciones

- No publicar las contraseñas ni el archivo `.env`.
- No utilizar el servidor de desarrollo Flask como servidor de producción.
- No exponer directamente PostgreSQL a Internet.
- La aplicación no incluye administración de múltiples cuentas web.
- El respaldo SQL de estructura no conserva datos ni configuraciones previas.
- Para una instalación nueva es necesario ejecutar el script de eventos iniciales.

## 15. Conclusión

AutoAudit integra un motor de auditoría en PostgreSQL con una aplicación web de administración y consulta.

El sistema permite configurar qué cambios deben monitorearse, registrar automáticamente las operaciones realizadas y consultar la información almacenada mediante reportes, facilitando el seguimiento de modificaciones en una base de datos.