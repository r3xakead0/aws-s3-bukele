<p align="center">
  <img src="bukele.gif" alt="Imagen del proyecto AWS S3 Bukele" width="180">
</p>

# Cargador de archivos comprimidos a AWS S3

[English](README.md) | [Español](README.ES.md)

Una pequeña utilidad en Bash que sube un archivo comprimido a una ubicación predefinida de Amazon S3. Antes de cargarlo, valida el archivo y AWS CLI, comprueba el perfil de AWS seleccionado e inicia sesión con AWS IAM Identity Center (AWS SSO) cuando la sesión actual no es válida.

## Características

- Valida que se haya indicado un archivo y que este exista.
- Acepta archivos `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` y `.tar.xz`.
- Comprueba que AWS CLI esté instalado.
- Utiliza un perfil de AWS CLI y un prefijo de S3 configurables.
- Comprueba la identidad actual de AWS antes de realizar la carga.
- Abre el flujo de inicio de sesión de AWS SSO cuando se necesita autenticación.
- Se detiene inmediatamente si falla un comando.

> [!NOTE]
> El archivo comprimido se sube tal como está. El script no extrae su contenido.

## Requisitos

- Bash.
- [AWS CLI](https://docs.aws.amazon.com/es_es/cli/latest/userguide/getting-started-install.html) instalado y disponible en `PATH`.
- Un perfil de AWS CLI configurado para la cuenta de destino. Se recomienda AWS CLI v2 para la [autenticación con AWS SSO](https://docs.aws.amazon.com/es_es/cli/latest/userguide/cli-configure-sso.html).
- Un bucket de S3 existente.
- Permiso para cargar objetos en la ubicación de S3 configurada.

Para configurar un perfil con SSO, ejecuta primero:

```bash
aws configure sso --profile mi-perfil
```

## Configuración

Edita los valores de configuración al comienzo de [`upload-to-s3.sh`](upload-to-s3.sh):

```bash
BUCKET="bucket-name"
AWS_PROFILE="default"
S3_PREFIX="backups"
```

| Variable | Propósito | Ejemplo |
| --- | --- | --- |
| `BUCKET` | Nombre del bucket de S3 de destino | `archivos-empresa` |
| `AWS_PROFILE` | Perfil de AWS CLI utilizado para la autenticación | `produccion` |
| `S3_PREFIX` | Ruta de destino dentro del bucket | `respaldos` |

La ubicación resultante sigue este patrón:

```text
s3://<BUCKET>/<S3_PREFIX>/<nombre-del-archivo>
```

Por ejemplo, `fotos-2026.zip`, con el bucket `archivos-empresa` y el prefijo `respaldos`, se sube a:

```text
s3://archivos-empresa/respaldos/fotos-2026.zip
```

## Uso

1. Clona el repositorio y entra en su directorio:

   ```bash
   git clone https://github.com/r3xakead0/aws-s3-bukele.git
   cd aws-s3-bukele
   ```

2. Actualiza los valores de configuración en `upload-to-s3.sh`.

3. Da permisos de ejecución al script:

   ```bash
   chmod +x upload-to-s3.sh
   ```

4. Sube un archivo comprimido:

   ```bash
   ./upload-to-s3.sh /ruta/a/fotos-2026.zip
   ```

Si la sesión de AWS configurada ha caducado, el script ejecuta `aws sso login` y espera a que termine la autenticación antes de continuar.

## Permiso de S3 necesario

La identidad de AWS utilizada por el perfil seleccionado necesita `s3:PutObject` para el prefijo de destino. Una política de identidad mínima puede ser la siguiente, después de sustituir el bucket y el prefijo de ejemplo:

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

El script realiza los siguientes pasos:

1. Comprueba que se haya indicado un archivo.
2. Comprueba que el archivo exista.
3. Comprueba que el comando `aws` esté disponible.
4. Rechaza extensiones de archivos no admitidas.
5. Ejecuta `aws sts get-caller-identity` con el perfil configurado.
6. Ejecuta `aws sso login` si falla la comprobación de identidad.
7. Sube el archivo con `aws s3 cp`.

Como el script utiliza `set -euo pipefail`, termina si falla un comando, se usa una variable no definida o falla una tubería de comandos.

## Solución de problemas

### `Error: File not found`

Comprueba la ruta del archivo. Las rutas con espacios deben escribirse entre comillas:

```bash
./upload-to-s3.sh "/ruta/a/Mis Fotos.zip"
```

### `Error: Unsupported compressed file format`

Utiliza una de las extensiones admitidas: `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` o `.tar.xz`.

### Falla el inicio de sesión con SSO

Confirma que `AWS_PROFILE` coincida con un perfil configurado para SSO en `~/.aws/config` y pruébalo directamente:

```bash
aws sso login --profile mi-perfil
aws sts get-caller-identity --profile mi-perfil
```

### Se deniega la carga

Verifica el nombre del bucket, la cuenta de AWS, el perfil seleccionado y el permiso `s3:PutObject` para el prefijo configurado. Comprueba también la política del bucket y cualquier requisito de cifrado.

## Limitaciones

- La configuración está almacenada en el script y no se recibe mediante opciones de línea de comandos.
- Solo se carga un archivo por ejecución.
- El nombre del objeto de destino es el nombre base del archivo comprimido.
- Un objeto existente con la misma clave de S3 puede sobrescribirse si el versionado o las políticas del bucket no lo impiden.
- La reautenticación automática presupone un perfil configurado para AWS SSO.

## Licencia

Este proyecto está disponible bajo la [licencia MIT](LICENSE).
