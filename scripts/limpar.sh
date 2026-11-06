#!/usr/bin/env bash
# Apaga tudo o que foi gerado em trabalho/ para recomeçar o roteiro do zero.
# Mantém apenas trabalho/.gitignore.
set -eu
cd "$(dirname "$0")/../trabalho"
echo "Arquivos que serão apagados em trabalho/:"
find . -maxdepth 1 -type f ! -name .gitignore -printf '  %f\n'
read -r -p "Confirma? [s/N] " r
if [ "${r:-n}" = "s" ] || [ "${r:-n}" = "S" ]; then
  find . -maxdepth 1 -type f ! -name .gitignore -delete
  echo "Pronto: trabalho/ está limpo."
else
  echo "Nada foi apagado."
fi
