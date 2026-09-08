-- ============================================================
-- Sentindo a Dor do Próximo — inicialização do banco (dev)
-- ============================================================
-- Este script roda automaticamente na primeira vez que o container do
-- Postgres sobe (Docker monta esta pasta em /docker-entrypoint-initdb.d,
-- ver ARQUITETURA.md, seção 7). Se você já subiu o banco antes e quer
-- rodar de novo, apague o volume db_data primeiro (docker compose down -v).
--
-- IMPORTANTE — leia antes de rodar:
-- Este script cria APENAS as tabelas que não dependem de nenhuma decisão
-- pendente do instituto (ver SDP_DECISOES_PENDENTES.md). As tabelas
-- `pessoas`, `organizacoes`, `servicos`, `elegibilidade`, `agendamentos`
-- e `atendimentos` ainda NÃO existem aqui de propósito — ver o bloco
-- comentado no final deste arquivo e BANCO_DADOS.md, seção 4.

CREATE EXTENSION IF NOT EXISTS btree_gist;
-- Usada futuramente pelo EXCLUDE constraint de `agendamentos` (impede
-- sobreposição de horário no próprio banco — ver BANCO_DADOS.md, seção 2).
-- Habilitada já agora porque não tem custo nem risco fazer isso antes de
-- a tabela existir.

-- ==========================================================
-- TABELAS
-- ==========================================================

CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE papeis (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(30) UNIQUE NOT NULL
        CHECK (nome IN ('administrador','gestor','funcionario','avaliador','auditor'))
);
-- Se D05 confirmar que "avaliador" não existe como função separada na
-- operação real do instituto, remover do CHECK e migrar as permissões
-- correspondentes para "funcionario" (ver REGRAS_NEGOCIO.md, seção 3).

CREATE TABLE usuarios_papeis (
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    papel_id INTEGER NOT NULL REFERENCES papeis(id),
    PRIMARY KEY (usuario_id, papel_id)
);
-- Um usuário pode acumular mais de um papel (ex.: Gestor + Avaliador) —
-- por isso é uma tabela de associação N:N, não uma coluna única em `usuarios`.

CREATE TABLE sessoes (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    token_hash VARCHAR(255) NOT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT now(),
    expira_em TIMESTAMP NOT NULL,
    revogado_em TIMESTAMP,
    ip VARCHAR(45)
);
-- Sessão controlada pelo servidor (ARQUITETURA.md, seção 6; T02 em
-- SDP_DECISOES_PENDENTES.md) — permite logout real e invalidação
-- imediata de todas as sessões de um usuário desativado.

CREATE TABLE auditoria (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    tabela VARCHAR(50) NOT NULL,
    registro_id INTEGER,
    acao VARCHAR(30) NOT NULL CHECK (acao IN (
        'CRIACAO','ALTERACAO','EXCLUSAO','LEITURA_SENSIVEL',
        'LOGIN','LOGIN_FALHOU','LOGOUT',
        'PERMISSAO_NEGADA','PAPEL_ALTERADO','USUARIO_DESATIVADO'
    )),
    dado_anterior JSONB,
    dado_novo JSONB,
    ip VARCHAR(45),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

-- ==========================================================
-- ÍNDICES
-- ==========================================================

CREATE INDEX idx_auditoria_tabela_registro ON auditoria(tabela, registro_id);
CREATE INDEX idx_sessoes_usuario ON sessoes(usuario_id);
-- usuarios.email já tem índice único automático pela constraint UNIQUE

-- ==========================================================
-- USUÁRIO DE APLICAÇÃO (permissões restritas — é este que o backend usa)
-- ==========================================================
-- CORREÇÃO em relação ao script de referência (projeto da clínica): lá,
-- o papel criado aqui tinha o MESMO nome do POSTGRES_USER definido no
-- docker-compose.yml — que é o dono/superusuário da conexão. Isso faz
-- qualquer REVOKE sobre esse mesmo usuário não valer nada na prática
-- (dono de objeto e superusuário ignoram REVOKE sobre si mesmos). Esse
-- é exatamente o risco descrito em SDP_DECISOES_PENDENTES.md, T04.
--
-- Aqui os dois papéis de banco são propositalmente diferentes:
--   - POSTGRES_USER no docker-compose.yml (db_owner) = dono/migração
--   - app_runtime (criado abaixo)                     = usuário do
--     Backend em tempo de execução, com privilégio restrito
--
-- Troque 'CHANGE_ME_LOCAL_DEV' pela MESMA senha que você colocou em
-- APP_DB_PASSWORD no seu .env, antes do primeiro "docker compose up".
-- Este arquivo não lê o .env automaticamente.

CREATE ROLE app_runtime WITH LOGIN PASSWORD 'CHANGE_ME_LOCAL_DEV';

GRANT CONNECT ON DATABASE sentindo_a_dor_do_proximo TO app_runtime;
GRANT USAGE ON SCHEMA public TO app_runtime;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_runtime;

-- Auditoria: somente consulta e inserção (append-only) — auditoria que
-- pode ser editada pela própria aplicação não serve como evidência.
REVOKE UPDATE, DELETE ON auditoria FROM app_runtime;

-- Papéis (catálogo): o Backend atribui/remove papel de um usuário via
-- usuarios_papeis, mas não deve poder redefinir o que cada papel "é" —
-- isso é mudança de schema/governança (migration), não ação da aplicação.
REVOKE INSERT, UPDATE, DELETE ON papeis FROM app_runtime;

-- Usuários e sessões: nenhum registro é apagado fisicamente — usuário
-- desativado vira `ativo = false` (a auditoria continua referenciando
-- o mesmo usuario_id), e sessão revogada vira `revogado_em` preenchido,
-- nunca some da tabela (fica como evidência de quando foi encerrada).
REVOKE DELETE ON usuarios, sessoes FROM app_runtime;

-- ==========================================================
-- AINDA NÃO CRIADO NESTE SCRIPT — DEPENDE DE DECISÃO DO INSTITUTO
-- ==========================================================
-- As tabelas abaixo NÃO existem ainda de propósito. Ver
-- SDP_DECISOES_PENDENTES.md e BANCO_DADOS.md, seção 4, para o motivo
-- de cada uma. Criá-las agora, com nomes de campo adivinhados, é
-- exatamente o risco que este projeto decidiu evitar: migração real
-- em produção depois, com dado de pessoa real dentro.
--
--   pessoas                   → bloqueada por D06 (campos de identificação/contato)
--   organizacoes               → bloqueada por D02 (existe mais de uma organização?)
--   servicos                   → bloqueada por D02 (FK organização?) e D03 (governança)
--   solicitacoes_servico        → bloqueada por D01 (modelo de elegibilidade)
--   avaliacoes_elegibilidade     → bloqueada por D01
--   agendamentos                 → bloqueada indiretamente (depende de servicos/pessoas)
--                                   e do modelo de disponibilidade (BANCO_DADOS.md, seção 2)
--   atendimentos                  → bloqueada por D04 (o que é registrado)
--
-- Quando essas decisões forem fechadas, a forma correta de adicioná-las
-- NÃO é editar este arquivo (ele só roda uma vez, na criação do volume)
-- — é uma migration nova via Alembic (ver ARQUITETURA.md, seção 4), para
-- que a evolução do schema fique registrada e replicável em qualquer
-- ambiente (dev, homologação, produção).
