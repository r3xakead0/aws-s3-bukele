<p align="center">
  <img src="bukele.gif" alt="Imagen del proyecto AWS S3 Bukele" width="180">
</p>

# Cargador de archivos comprimidos a AWS S3

[English](README.md) | [Español](README.ES.md)

Una utilidad de línea de comandos multiplataforma para subir archivos comprimidos a Amazon S3, con Bash para Linux y macOS y PowerShell para Windows. Ambas implementaciones validan la entrada, comprueban el perfil de AWS seleccionado, renuevan la sesión de AWS IAM Identity Center (AWS SSO) cuando es necesario y cargan el archivo sin extraerlo.

## Características

- Admite archivos `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` y `.tar.xz`.
- Funciona en Linux y macOS con Bash y en Windows con PowerShell.
- Recibe la configuración mediante opciones de línea de comandos o variables de entorno.
- Permite elegir opcionalmente la clase de almacenamiento de S3 y utiliza `STANDARD` de forma predeterminada.
- Valida el archivo, la configuración del bucket y la instalación de AWS CLI.
- Comprueba la identidad actual de AWS antes de realizar la carga.
- Inicia el acceso con AWS SSO cuando la sesión no está disponible o ha caducado.
- Normaliza las barras iniciales y finales del prefijo de destino.
- Incluye pruebas de integración sin dependencias, validación con ShellCheck y validación con PSScriptAnalyzer.

> [!NOTE]
> El archivo comprimido se sube tal como está. Su contenido no se extrae.

## Estructura del proyecto

```text
.
├── .github/workflows/ci.yml  # Flujo automático de lint y pruebas
├── bin/upload-to-s3          # Aplicación de línea de comandos en Bash
├── bin/upload-to-s3.ps1      # Aplicación de línea de comandos en PowerShell
├── tests/                    # Pruebas de integración para Bash y PowerShell
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

- Bash en Linux o macOS, o PowerShell 5.1 o posterior en Windows.
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
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) para validar PowerShell localmente.

## Inicio rápido

Clona el repositorio:

```bash
git clone https://github.com/r3xakead0/aws-s3-bukele.git
cd aws-s3-bukele
```

### Linux y macOS

Sube un archivo con Bash:

```bash
./bin/upload-to-s3 \
  --bucket archivos-empresa \
  --profile produccion \
  --prefix respaldos \
  /ruta/a/fotos-2026.zip
```

### Windows

Sube el mismo archivo con PowerShell:

```powershell
.\bin\upload-to-s3.ps1 `
  -Bucket archivos-empresa `
  -Profile produccion `
  -Prefix respaldos `
  -Archive C:\Respaldos\fotos-2026.zip
```

El objeto resultante queda almacenado en:

```text
s3://archivos-empresa/respaldos/fotos-2026.zip
```

Como no se indicó una clase de almacenamiento, el objeto utiliza `STANDARD`.

## Configuración

Las opciones de línea de comandos tienen prioridad sobre las variables de entorno.

| Opción Bash / PowerShell | Variable de entorno | Valor predeterminado | Propósito |
| --- | --- | --- | --- |
| `--bucket`, `-b` / `-Bucket` | `S3_BUCKET` | Obligatorio | Bucket de S3 de destino |
| `--profile`, `-p` / `-Profile` | `AWS_PROFILE` | `default` | Perfil de AWS CLI |
| `--prefix` / `-Prefix` | `S3_PREFIX` | `backups` | Prefijo de destino dentro del bucket |
| `--storage-class`, `-s` / `-StorageClass` | `S3_STORAGE_CLASS` | `STANDARD` | Clase de almacenamiento del objeto cargado |

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

En PowerShell, define la misma configuración como variables de entorno del proceso:

```powershell
$env:S3_BUCKET = 'archivos-empresa'
$env:AWS_PROFILE = 'produccion'
$env:S3_PREFIX = 'respaldos'
$env:S3_STORAGE_CLASS = 'STANDARD'

.\bin\upload-to-s3.ps1 -Archive C:\Respaldos\fotos-2026.zip
```

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

PowerShell utiliza el parámetro equivalente `-StorageClass`:

```powershell
.\bin\upload-to-s3.ps1 `
  -Bucket archivos-empresa `
  -StorageClass STANDARD_IA `
  -Archive C:\Respaldos\fotos-2026.zip
```

Elige la clase según el patrón de acceso, los requisitos de recuperación, la duración mínima de almacenamiento y el costo del objeto. Consulta la [guía de clases de almacenamiento de Amazon S3](https://docs.aws.amazon.com/es_es/AmazonS3/latest/userguide/storage-class-intro.html) para obtener más información.

## Referencia de la CLI

### Bash

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

### PowerShell

```text
Usage: upload-to-s3.ps1 [options] -Archive <compressed-file>

Options:
  -Bucket NAME          Destination S3 bucket (or S3_BUCKET).
  -Profile NAME         AWS CLI profile (default: default).
  -Prefix PATH          Destination prefix (default: backups).
  -StorageClass CLASS   S3 storage class (default: STANDARD).
  -Archive FILE         Compressed file to upload.
  -Help                 Show the help message.
```

```powershell
.\bin\upload-to-s3.ps1 -Help
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

Ambas aplicaciones:

1. Procesan las opciones de línea de comandos y las variables de entorno.
2. Validan el bucket, la clase de almacenamiento, el archivo y su extensión.
3. Confirman que AWS CLI esté disponible.
4. Ejecutan `aws sts get-caller-identity` con el perfil seleccionado.
5. Ejecutan `aws sso login` y vuelven a comprobar la identidad si falla la primera validación.
6. Construyen la URI de destino y suben el archivo con `aws s3 cp` y la clase seleccionada.

El script Bash utiliza `set -Eeuo pipefail`; el script PowerShell utiliza modo estricto y errores terminantes. Los fallos inesperados detienen ambas implementaciones.

## Desarrollo

Ejecuta las pruebas de integración con AWS CLI simulado:

```bash
make test
```

Ejecuta las pruebas de PowerShell en un sistema con PowerShell 7:

```bash
make test-powershell
```

También puedes ejecutarlas directamente desde PowerShell:

```powershell
.\tests\upload-to-s3-powershell-test.ps1
```

Ejecuta PSScriptAnalyzer:

```powershell
Invoke-ScriptAnalyzer -Path .\bin\upload-to-s3.ps1 -Severity Warning,Error
```

Ejecuta ShellCheck:

```bash
make lint
```

Ejecuta todas las comprobaciones de Bash:

```bash
make check
```

GitHub Actions ejecuta el lint y las pruebas de Bash en Ubuntu, y el lint y las pruebas de PowerShell en Windows. Ninguna suite de pruebas se conecta a AWS.

## Solución de problemas

### `S3 bucket is required`

Indica `--bucket` o define `S3_BUCKET` antes de ejecutar el comando.

### `File not found`

Comprueba la ruta del archivo. Escribe entre comillas las rutas que contengan espacios:

```bash
./bin/upload-to-s3 --bucket archivos-empresa "/ruta/a/Mis Fotos.zip"
```

```powershell
.\bin\upload-to-s3.ps1 -Bucket archivos-empresa -Archive 'C:\Respaldos\Mis Fotos.zip'
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
