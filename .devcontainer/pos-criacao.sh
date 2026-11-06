#!/usr/bin/env bash
# Executado uma única vez, quando o Codespace é criado.
set -e
if ! command -v openssl >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y openssl
fi
chmod +x scripts/*.sh
echo
echo "============================================================"
echo " Ambiente pronto: $(openssl version)"
echo " Leia a revisão teórica e siga o roteiro no README.md."
echo " O terminal já abre em trabalho/. A entrega é pelo Teams."
echo "============================================================"
