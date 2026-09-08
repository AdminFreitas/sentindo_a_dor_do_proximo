#!/bin/bash
set -e

# Rode este script DE DENTRO da pasta do projeto,
# que já deve conter: README.md, .gitignore, .env.example e a pasta docs/
# (e, se já movido conforme docs/ARQUITETURA.md, db/init/db_init.sql).
#
# Este script NÃO adiciona LICENSE: a licença deste projeto ainda não foi
# definida (ver README.md, seção "Licença"). Quando for decidida, crie o
# arquivo LICENSE e inclua-o na linha de "git add" abaixo.

echo "== Inicializando repositório git =="
git init
git branch -M main
git remote add origin https://github.com/AdminFreitas/sentindo_a_dor_do_proximo.git

echo "== Adicionando apenas os arquivos de documentação e configuração inicial =="
git add README.md .gitignore .env.example docs/
[ -d db/init ] && git add db/init/

echo "== Conferindo o que será enviado (NENHUM .env real deve aparecer aqui) =="
git status

echo "== Criando o commit =="
git commit -m "docs: adiciona documentacao inicial e schema parcial do banco (requisitos, arquitetura, regras de negocio, decisoes pendentes e tabelas nao bloqueadas)"

echo "== Enviando para o GitHub =="
git push -u origin main

echo "== Concluído. Confira em https://github.com/AdminFreitas/sentindo_a_dor_do_proximo =="