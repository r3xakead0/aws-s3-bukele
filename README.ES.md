<p align="center">
  <img src="bukele.gif" alt="Imagen del proyecto AWS S3 Bukele" width="180">
</p>

# Cargador de archivos comprimidos a AWS S3

[English](README.md) | [Español](README.ES.md)

Una utilidad de línea de comandos en Bash para subir archivos comprimidos a Amazon S3. Valida la entrada, comprueba el perfil de AWS seleccionado, renueva la sesión de AWS IAM Identity Center (AWS SSO) cuando es necesario y carga el archivo sin extraerlo.

## Características

- Admite archivos `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` y `.tar.xz`.
- Recibe la configuración mediante opciones de línea de comandos o variables de entorno.
- Permite elegir opcionalmente la clase de almacenamiento de S3 y utiliza `STANDARD` de forma predeterminada.
- Valida el archivo, la configuración del bucket y la instalación de AWS CLI.
- Comprueba la identidad actual de AWS antes de realizar la carga.
- Inicia el acceso con AWS SSO cuando la sesión no está disponible o ha caducado.
- Normaliza las barras iniciales y finales del prefijo de destino.
- Incluye pruebas de integración sin dependencias y validación automática con ShellCheck.

> [!NOTE]
> El archivo comprimido se sube tal como está. Su contenido no se extrae.

## Estructura del proyecto

```text
.
├── .github/workflows/ci.yml  # Flujo automático de lint y pruebas
├── bin/upload-to-s3          # Aplicación de línea de comandos
├── tests/                    # Pruebas de integración con AWS CLI simulado
├── .editorconfig             # Reglas de formato para editores
├── .env.example              # Plantilla de configuración
├── .gitattributes            # Finales de línea consistentes en Git
├── .gitignore                # Archivos locales excluidos de Git
├── Makefile                  # Comandos de desarrollo y ejecución
├── README.md                 # Documentación en inglés
├── README.ES.md              # Documentación en español
└── LICENSE                   # Licencia MIT
```

## Requisitos

### Ejecución

- Bash.
- [AWS CLI v2](https://docs.aws.amazon.com/es_es/cli/latest/userguide/getting-started-install.html) disponible en `PATH`.
- Un bucket de S3 existente.
- Un perfil de AWS CLI con acceso al destino.
- Permiso `s3:PutObject` para el prefijo de S3 configurado.

Para un perfil con SSO, configura primero AWS CLI:

```bash
aws configure sso --profile mi-perfil
```

### Desarrollo

- `make` para ejecutar las tareas del proyecto.
- [ShellCheck](https://www.shellcheck.net/) para ejecutar el linter.

## Inicio rápido

1. Clona el repositorio:

   ```bash
   git clone https://github.com/r3xakead0/aws-s3-bukele.git
   cd aws-s3-bukele
   ```

2. Sube un archivo indicando la configuración explícitamente:

   ```bash
   ./bin/upload-to-s3 \
     --bucket archivos-empresa \
     --profile produccion \
     --prefix respaldos \
     /ruta/a/fotos-2026.zip
   ```

El objeto resultante queda almacenado en:

```text
s3://archivos-empresa/respaldos/fotos-2026.zip
```

Como no se indicó una clase de almacenamiento, el objeto utiliza `STANDARD`.

## Configuración

Las opciones de línea de comandos tienen prioridad sobre las variables de entorno.

| Opción CLI | Variable de entorno | Valor predeterminado | Propósito |
| --- | --- | --- | --- |
| `--bucket`, `-b` | `S3_BUCKET` | Obligatorio | Bucket de S3 de destino |
| `--profile`, `-p` | `AWS_PROFILE` | `default` | Perfil de AWS CLI |
| `--prefix` | `S3_PREFIX` | `backups` | Prefijo de destino dentro del bucket |
| `--storage-class`, `-s` | `S3_STORAGE_CLASS` | `STANDARD` | Clase de almacenamiento del objeto cargado |

### Uso de un archivo de entorno

Copia la plantilla y actualiza sus valores:

```bash
cp .env.example .env
```

La aplicación no carga `.env` implícitamente. Puedes exportarlo en la terminal actual:

```bash
set -a
source .env
set +a
./bin/upload-to-s3 /ruta/a/fotos-2026.zip
```

También puedes usar el objetivo de Make, que carga `.env` cuando el archivo existe:

```bash
make upload FILE=/ruta/a/fotos-2026.zip
```

El archivo `.env` está ignorado por Git para evitar agregar por accidente la configuración local.

### Clases de almacenamiento

La clase de almacenamiento es opcional. Cuando no se proporciona `--storage-class` ni `S3_STORAGE_CLASS`, la aplicación carga explícitamente el objeto usando `STANDARD`.

Los valores admitidos son:

- `STANDARD`
- `REDUCED_REDUNDANCY`
- `STANDARD_IA`
- `ONEZONE_IA`
- `INTELLIGENT_TIERING`
- `GLACIER`
- `DEEP_ARCHIVE`
- `GLACIER_IR`

Por ejemplo:

```bash
./bin/upload-to-s3 \
  --bucket archivos-empresa \
  --storage-class STANDARD_IA \
  /ruta/a/fotos-2026.zip
```

Elige la clase según el patrón de acceso, los requisitos de recuperación, la duración mínima de almacenamiento y el costo del objeto. Consulta la [guía de clases de almacenamiento de Amazon S3](https://docs.aws.amazon.com/es_es/AmazonS3/latest/userguide/storage-class-intro.html) para obtener más información.

## Referencia de la CLI

```text
Usage: upload-to-s3 [options] <compressed-file>

Options:
  -b, --bucket NAME    Destination S3 bucket (or S3_BUCKET).
  -p, --profile NAME   AWS CLI profile (default: default).
      --prefix PATH    Destination prefix (default: backups).
  -s, --storage-class CLASS
                        S3 storage class (default: STANDARD).
  -h, --help           Show the help message.
```

Muestra la ayuda vigente directamente desde el ejecutable:

```bash
./bin/upload-to-s3 --help
```

## Permiso de S3 necesario

La identidad de AWS seleccionada necesita `s3:PutObject` para el prefijo de destino. Sustituye el bucket y el prefijo de ejemplo antes de usar esta política de identidad:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::archivos-empresa/respaldos/*"
    }
  ]
}
```

Revisa y prueba la política antes de asociarla a un rol o conjunto de permisos.

## Cómo funciona

La aplicación:

1. Procesa las opciones de línea de comandos y las variables de entorno.
2. Valida el bucket, la clase de almacenamiento, el archivo y su extensión.
3. Confirma que AWS CLI esté disponible.
4. Ejecuta `aws sts get-caller-identity` con el perfil seleccionado.
5. Ejecuta `aws sso login` y vuelve a comprobar la identidad si falla la primera validación.
6. Construye la URI de destino y sube el archivo con `aws s3 cp` y la clase seleccionada.

El script utiliza `set -Eeuo pipefail`, por lo que un fallo inesperado de comando, variable o tubería detiene la ejecución.

## Desarrollo

Ejecuta las pruebas de integración con AWS CLI simulado:

```bash
make test
```

Ejecuta ShellCheck:

```bash
make lint
```

Ejecuta todas las comprobaciones locales:

```bash
make check
```

Las mismas comprobaciones se ejecutan automáticamente para los `push` y `pull requests` mediante GitHub Actions. Las pruebas nunca se conectan a AWS.

## Solución de problemas

### `S3 bucket is required`

Indica `--bucket` o define `S3_BUCKET` antes de ejecutar el comando.

### `File not found`

Comprueba la ruta del archivo. Escribe entre comillas las rutas que contengan espacios:

```bash
./bin/upload-to-s3 --bucket archivos-empresa "/ruta/a/Mis Fotos.zip"
```

### `Unsupported compressed file format`

Utiliza `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` o `.tar.xz`.

### `Unsupported S3 storage class`

Utiliza uno de los valores de [Clases de almacenamiento](#clases-de-almacenamiento). Los valores distinguen entre mayúsculas y minúsculas.

### Falla el inicio de sesión con SSO

Confirma que el perfil seleccionado esté configurado para AWS SSO y pruébalo directamente:

```bash
aws sso login --profile mi-perfil
aws sts get-caller-identity --profile mi-perfil
```

### Se deniega la carga

Verifica el bucket, la cuenta de AWS, el perfil seleccionado, el permiso `s3:PutObject`, la política del bucket y los requisitos de cifrado.

## Limitaciones

- Se carga un archivo por ejecución.
- El objeto de destino utiliza el nombre base del archivo comprimido.
- Un objeto existente con la misma clave puede sobrescribirse, salvo que el versionado o las políticas del bucket lo impidan.
- La reautenticación automática presupone un perfil configurado para AWS SSO.

## Licencia

Este proyecto está disponible bajo la [licencia MIT](LICENSE).
