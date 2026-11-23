<p align="center">
  <img src="bukele.gif" alt="Imagem do projeto AWS S3 Bukele" width="180">
</p>

# Carregador de arquivos compactados para AWS S3

[English](README.md) | [Español](README.ES.md) | [Português](README.PT.md)

Uma ferramenta de linha de comando multiplataforma para enviar arquivos compactados ao Amazon S3, com suporte a Bash no Linux e macOS e PowerShell no Windows. Ambas as implementações validam a entrada, verificam o perfil AWS selecionado, renovam a sessão do AWS IAM Identity Center (AWS SSO) quando necessário e enviam o arquivo sem extrair seu conteúdo.

## Recursos

- Suporta arquivos `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` e `.tar.xz`.
- Funciona no Linux e macOS com Bash e no Windows com PowerShell.
- Aceita configurações por opções de linha de comando ou variáveis de ambiente.
- Permite selecionar uma classe de armazenamento S3 opcional e usa `STANDARD` por padrão.
- Valida o arquivo, a configuração do bucket e a instalação da AWS CLI.
- Verifica a identidade AWS atual antes do upload.
- Inicia o fluxo de login do AWS SSO quando a sessão não está disponível ou expirou.
- Normaliza as barras iniciais e finais do prefixo de destino.
- Inclui testes de integração sem dependências e validações com ShellCheck e PSScriptAnalyzer.

> [!NOTE]
> O arquivo compactado é enviado como está. Seu conteúdo não é extraído.

## Estrutura do projeto

```text
.
├── .github/workflows/ci.yml  # Fluxo automatizado de lint e testes
├── bin/upload-to-s3.sh       # Aplicação de linha de comando em Bash
├── bin/upload-to-s3.ps1      # Aplicação de linha de comando em PowerShell
├── tests/                    # Testes de integração para Bash e PowerShell
├── .editorconfig             # Regras compartilhadas de formatação
├── .env.example              # Modelo de configuração
├── .gitattributes            # Finais de linha consistentes no Git
├── .gitignore                # Arquivos locais excluídos do Git
├── Makefile                  # Comandos de desenvolvimento e execução
├── README.md                 # Documentação em inglês
├── README.ES.md              # Documentação em espanhol
├── README.PT.md              # Documentação em português
└── LICENSE                   # Licença MIT
```

## Requisitos

### Execução

- Bash no Linux ou macOS, ou PowerShell 5.1 ou posterior no Windows.
- [AWS CLI v2](https://docs.aws.amazon.com/pt_br/cli/latest/userguide/getting-started-install.html) disponível no `PATH`.
- Um bucket S3 existente.
- Um perfil da AWS CLI com acesso ao destino.
- Permissão `s3:PutObject` para o prefixo S3 configurado.

Para um perfil com SSO, configure primeiro a AWS CLI:

```bash
aws configure sso --profile meu-perfil
```

### Desenvolvimento

- `make` para executar as tarefas do projeto.
- [ShellCheck](https://www.shellcheck.net/) para validar o Bash.
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) para validar o PowerShell localmente.

## Início rápido

Clone o repositório:

```bash
git clone https://github.com/r3xakead0/aws-s3-bukele.git
cd aws-s3-bukele
```

### Linux e macOS

Envie um arquivo compactado com Bash:

```bash
./bin/upload-to-s3.sh \
  --bucket arquivos-empresa \
  --profile producao \
  --prefix backups \
  /caminho/para/fotos-2026.zip
```

### Windows

Envie o mesmo arquivo com PowerShell:

```powershell
.\bin\upload-to-s3.ps1 `
  -Bucket arquivos-empresa `
  -Profile producao `
  -Prefix backups `
  -Archive C:\Backups\fotos-2026.zip
```

O objeto resultante é armazenado em:

```text
s3://arquivos-empresa/backups/fotos-2026.zip
```

Como nenhuma classe de armazenamento foi informada, o objeto usa `STANDARD`.

## Configuração

As opções de linha de comando têm prioridade sobre as variáveis de ambiente.

| Opção Bash / PowerShell | Variável de ambiente | Padrão | Finalidade |
| --- | --- | --- | --- |
| `--bucket`, `-b` / `-Bucket` | `S3_BUCKET` | Obrigatório | Bucket S3 de destino |
| `--profile`, `-p` / `-Profile` | `AWS_PROFILE` | `default` | Perfil da AWS CLI |
| `--prefix` / `-Prefix` | `S3_PREFIX` | `backups` | Prefixo de destino dentro do bucket |
| `--storage-class`, `-s` / `-StorageClass` | `S3_STORAGE_CLASS` | `STANDARD` | Classe de armazenamento do objeto enviado |

### Usando um arquivo de ambiente

Copie o modelo fornecido e atualize seus valores:

```bash
cp .env.example .env
```

A aplicação não carrega `.env` implicitamente. Exporte o arquivo no shell atual:

```bash
set -a
source .env
set +a
./bin/upload-to-s3.sh /caminho/para/fotos-2026.zip
```

Ou use o alvo do Make, que carrega `.env` quando o arquivo existe:

```bash
make upload FILE=/caminho/para/fotos-2026.zip
```

O arquivo `.env` é ignorado pelo Git para evitar que configurações locais sejam adicionadas por engano.

No PowerShell, defina a mesma configuração como variáveis de ambiente do processo:

```powershell
$env:S3_BUCKET = 'arquivos-empresa'
$env:AWS_PROFILE = 'producao'
$env:S3_PREFIX = 'backups'
$env:S3_STORAGE_CLASS = 'STANDARD'

.\bin\upload-to-s3.ps1 -Archive C:\Backups\fotos-2026.zip
```

### Classes de armazenamento

A classe de armazenamento é opcional. Quando `--storage-class` e `S3_STORAGE_CLASS` não são fornecidos, a aplicação envia explicitamente o objeto usando `STANDARD`.

Os valores aceitos são:

- `STANDARD`
- `REDUCED_REDUNDANCY`
- `STANDARD_IA`
- `ONEZONE_IA`
- `INTELLIGENT_TIERING`
- `GLACIER`
- `DEEP_ARCHIVE`
- `GLACIER_IR`

Por exemplo:

```bash
./bin/upload-to-s3.sh \
  --bucket arquivos-empresa \
  --storage-class STANDARD_IA \
  /caminho/para/fotos-2026.zip
```

O PowerShell usa o parâmetro equivalente `-StorageClass`:

```powershell
.\bin\upload-to-s3.ps1 `
  -Bucket arquivos-empresa `
  -StorageClass STANDARD_IA `
  -Archive C:\Backups\fotos-2026.zip
```

Escolha uma classe de acordo com o padrão de acesso, os requisitos de recuperação, o período mínimo de armazenamento e o custo do objeto. Consulte o [guia de classes de armazenamento do Amazon S3](https://docs.aws.amazon.com/pt_br/AmazonS3/latest/userguide/storage-class-intro.html) para obter mais detalhes.

## Referência da CLI

### Bash

```text
Usage: upload-to-s3.sh [options] <compressed-file>

Options:
  -b, --bucket NAME    Destination S3 bucket (or S3_BUCKET).
  -p, --profile NAME   AWS CLI profile (default: default).
      --prefix PATH    Destination prefix (default: backups).
  -s, --storage-class CLASS
                        S3 storage class (default: STANDARD).
  -h, --help           Show the help message.
```

Exiba a ajuda atual diretamente pelo executável:

```bash
./bin/upload-to-s3.sh --help
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

## Permissão S3 necessária

A identidade AWS selecionada precisa de `s3:PutObject` para o prefixo de destino. Substitua o bucket e o prefixo do exemplo antes de usar esta política de identidade:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::arquivos-empresa/backups/*"
    }
  ]
}
```

Revise e teste a política antes de associá-la a uma função ou conjunto de permissões.

## Como funciona

As duas aplicações:

1. Processam as opções de linha de comando e as variáveis de ambiente.
2. Validam o bucket, a classe de armazenamento, o arquivo e sua extensão.
3. Confirmam que a AWS CLI está disponível.
4. Executam `aws sts get-caller-identity` com o perfil selecionado.
5. Executam `aws sso login` e verificam novamente a identidade se a primeira validação falhar.
6. Constroem a URI de destino e enviam o arquivo com `aws s3 cp` e a classe selecionada.

O script Bash usa `set -Eeuo pipefail`; o script PowerShell usa modo estrito e erros terminantes. Falhas inesperadas interrompem ambas as implementações.

## Desenvolvimento

Execute os testes de integração com a AWS CLI simulada:

```bash
make test
```

Execute os testes PowerShell em um sistema com PowerShell 7:

```bash
make test-powershell
```

Também é possível executá-los diretamente pelo PowerShell:

```powershell
.\tests\upload-to-s3-test.ps1
```

Execute o PSScriptAnalyzer:

```powershell
Invoke-ScriptAnalyzer -Path .\bin\upload-to-s3.ps1 -Severity Warning,Error
```

Execute o ShellCheck:

```bash
make lint
```

Execute todas as verificações Bash:

```bash
make check
```

O GitHub Actions executa o lint e os testes Bash no Ubuntu e o lint e os testes PowerShell no Windows. Nenhum conjunto de testes se conecta à AWS.

## Solução de problemas

### `S3 bucket is required`

Informe `--bucket` ou defina `S3_BUCKET` antes de executar o comando.

### `File not found`

Verifique o caminho do arquivo. Coloque entre aspas os caminhos que contêm espaços:

```bash
./bin/upload-to-s3.sh --bucket arquivos-empresa "/caminho/para/Minhas Fotos.zip"
```

```powershell
.\bin\upload-to-s3.ps1 -Bucket arquivos-empresa -Archive 'C:\Backups\Minhas Fotos.zip'
```

### `Unsupported compressed file format`

Use `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2` ou `.tar.xz`.

### `Unsupported S3 storage class`

Use um dos valores listados em [Classes de armazenamento](#classes-de-armazenamento). Os valores diferenciam letras maiúsculas de minúsculas.

### Falha no login SSO

Confirme que o perfil selecionado está configurado para AWS SSO e teste-o diretamente:

```bash
aws sso login --profile meu-perfil
aws sts get-caller-identity --profile meu-perfil
```

### O upload é negado

Verifique o bucket, a conta AWS, o perfil selecionado, a permissão `s3:PutObject`, a política do bucket e os requisitos de criptografia.

## Limitações

- Um arquivo é enviado por execução.
- O objeto de destino usa o nome base do arquivo compactado.
- Um objeto existente com a mesma chave pode ser sobrescrito, a menos que o versionamento ou as políticas do bucket impeçam isso.
- A reautenticação automática pressupõe um perfil configurado para AWS SSO.

## Licença

Este projeto está disponível sob a [licença MIT](LICENSE).
