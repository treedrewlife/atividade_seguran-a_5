#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Conferência técnica local do laboratório "AC da turma".
#
# Uso (na raiz do repositório):   bash scripts/verificar.sh
#
# Confere os certificados gerados em trabalho/ e procura segredos no Git.
# As evidências da atividade são enviadas pelo Teams, não por este script.
# ---------------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.." || exit 2

T=trabalho
NOME=agenda.caisazul.test
ok=0
falhas=0

passou() { echo "  ✓ $1"; ok=$((ok + 1)); }
falhou() {
  echo "  ✗ $1"
  [ -n "${2:-}" ] && echo "      dica: $2"
  falhas=$((falhas + 1))
}
titulo() { echo; echo "▸ $1"; }
ext() { openssl x509 -in "$1" -noout -ext "$2" 2>/dev/null; }
campo() { openssl x509 -in "$1" -noout "-$2" 2>/dev/null | cut -d= -f2-; }

# ---------------------------------------------------------------- segredos
titulo "Segredos fora do Git"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  versionados=$(git ls-files | grep -Ei '\.(key|pfx|p12)$' || true)
  if [ -n "$versionados" ]; then
    falhou "há arquivos de segredo versionados: $(echo "$versionados" | tr '\n' ' ')" \
      "remova do Git com 'git rm --cached <arquivo>' e GERE NOVAS CHAVES: o histórico continua com as antigas."
  else
    passou "nenhum .key, .pfx ou .p12 versionado"
  fi
  com_chave=$(git grep -l -e 'PRIVATE KEY-----' -- . 2>/dev/null | grep -v '^scripts/verificar.sh$' || true)
  if [ -n "$com_chave" ]; then
    falhou "há chave privada dentro de: $(echo "$com_chave" | tr '\n' ' ')" "remova o arquivo do Git e gere novas chaves."
  else
    passou "nenhuma chave privada dentro dos arquivos versionados"
  fi
else
  echo "  (não é um repositório Git; verificação de segredos ignorada)"
fi

# ---------------------------------------------------------------- arquivos
titulo "Certificados e pedido em $T/"
faltando=0
for f in raiz.crt intermediaria.crt site.crt site.csr; do
  if [ -s "$T/$f" ]; then passou "$f encontrado"; else falhou "$f não encontrado" "conclua as etapas 1 a 4 do roteiro."; faltando=1; fi
done
if [ "$faltando" = 1 ]; then
  echo; echo "Resultado: $ok verificação(ões) ok, $falhas falha(s)."; exit 1
fi

# ---------------------------------------------------------------- raiz
titulo "AC raiz (raiz.crt)"
if [ "$(campo $T/raiz.crt subject)" = "$(campo $T/raiz.crt issuer)" ]; then
  passou "é autoassinada (titular = emissor)"
else
  falhou "titular e emissor deveriam ser iguais" "a raiz assina o próprio certificado (etapa 1)."
fi
if ext $T/raiz.crt basicConstraints | grep -q 'CA:TRUE'; then passou "pode assinar certificados (CA:TRUE)"; else falhou "falta CA:TRUE" "use -extfile ../config/raiz.ext."; fi
if openssl verify -no_check_time -CAfile $T/raiz.crt $T/raiz.crt >/dev/null 2>&1; then passou "assinatura própria confere"; else falhou "assinatura da raiz não confere"; fi

# ---------------------------------------------------------------- intermediária
titulo "AC intermediária (intermediaria.crt)"
if [ "$(campo $T/intermediaria.crt issuer)" = "$(campo $T/raiz.crt subject)" ]; then passou "emitida pela raiz"; else falhou "o emissor deveria ser a raiz"; fi
bc=$(ext $T/intermediaria.crt basicConstraints)
if echo "$bc" | grep -q 'CA:TRUE' && echo "$bc" | grep -q 'pathlen:0'; then passou "CA:TRUE com pathlen:0"; else falhou "esperado CA:TRUE, pathlen:0" "use -extfile ../config/intermediaria.ext."; fi
if openssl verify -no_check_time -CAfile $T/raiz.crt $T/intermediaria.crt >/dev/null 2>&1; then passou "assinatura da raiz confere"; else falhou "assinatura da raiz não confere"; fi

# ---------------------------------------------------------------- site
titulo "Certificado do site (site.crt)"
if [ "$(campo $T/site.crt issuer)" = "$(campo $T/intermediaria.crt subject)" ]; then passou "emitido pela intermediária"; else falhou "o emissor deveria ser a intermediária" "a etapa 4 usa -CA intermediaria.crt."; fi
if ext $T/site.crt basicConstraints | grep -q 'CA:FALSE'; then passou "não pode assinar certificados (CA:FALSE)"; else falhou "falta CA:FALSE" "use -extfile ../config/site.ext."; fi
if ext $T/site.crt subjectAltName | grep -q "DNS:$NOME"; then passou "vale para $NOME (subjectAltName)"; else falhou "subjectAltName sem DNS:$NOME"; fi
if ext $T/site.crt extendedKeyUsage | grep -q 'TLS Web Server Authentication'; then passou "uso estendido: autenticação de servidor"; else falhou "falta extendedKeyUsage=serverAuth"; fi
ini=$(date -d "$(campo $T/site.crt startdate)" +%s 2>/dev/null || echo 0)
fim=$(date -d "$(campo $T/site.crt enddate)" +%s 2>/dev/null || echo 0)
dias=$(((fim - ini) / 86400))
if [ "$dias" -ge 1 ] && [ "$dias" -le 8 ]; then passou "validade curta: $dias dia(s)"; else falhou "validade de $dias dia(s); o roteiro pede 7" "use -days 7 na etapa 4."; fi
if openssl verify -no_check_time -CAfile $T/raiz.crt -untrusted $T/intermediaria.crt $T/site.crt >/dev/null 2>&1; then
  passou "cadeia completa confere: site → intermediária → raiz"
else
  falhou "a cadeia não confere" "refaça a etapa 5 e leia a mensagem de erro."
fi

# ---------------------------------------------------------------- CSR
titulo "Pedido de certificado (site.csr)"
if openssl req -in $T/site.csr -noout -verify >/dev/null 2>&1; then passou "assinatura do CSR confere"; else falhou "CSR inválido"; fi
pk_csr=$(openssl req -in $T/site.csr -noout -pubkey 2>/dev/null | sha256sum | cut -c1-16)
pk_crt=$(openssl x509 -in $T/site.crt -noout -pubkey 2>/dev/null | sha256sum | cut -c1-16)
if [ "$pk_csr" = "$pk_crt" ]; then passou "a chave pública do certificado é a mesma do CSR"; else falhou "o certificado não foi emitido a partir deste CSR"; fi

echo
echo "Resultado: $ok verificação(ões) ok, $falhas falha(s)."
[ "$falhas" = 0 ] && echo "Conferência técnica concluída. Registre as evidências no Teams."
[ "$falhas" = 0 ]
