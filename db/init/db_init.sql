-- ============================================================
-- Sentindo a Dor do Próximo — inicialização do banco (definitivo v3)
-- ============================================================
-- Este script roda automaticamente na primeira vez que o container do
-- Postgres sobe (Docker monta esta pasta em /docker-entrypoint-initdb.d,
-- ver docs/ARQUITETURA.md, seção 7). Se você já subiu o banco antes e
-- quer rodar de novo, apague o volume db_data primeiro
-- (docker compose down -v).
--
-- Consolidado a partir de todas as 9 decisões de negócio fechadas
-- (D01-D09, ver SDP_DECISOES_PENDENTES.md), das correções encontradas
-- em revisão de código (C1-C3, ver docs/BANCO_DADOS.md, seção 1), e da
-- Central de Atendimento omnichannel, Fase 1 (docs/BANCO_DADOS.md,
-- seção 4.10 — NOVO nesta versão, ainda sem D0x formalmente registrada,
-- ver docs/REQUISITOS.md, seção 9).
--
-- Testado contra PostgreSQL 16 com 12 casos funcionais antes da versão
-- anterior. Os 4 testes novos da Central de Atendimento (13-16, ver
-- docs/BANCO_DADOS.md, seção 6) e os 3 testes das correções de
-- privilégio (GRANT DELETE em usuarios_papeis, REVOKE em
-- avaliacoes_elegibilidade/correcoes_cadastrais, EXECUTE restrito em
-- alocar_atendimento) ainda não foram executados contra este script
-- consolidado — rodar antes de considerar isso 100% validado.

CREATE EXTENSION IF NOT EXISTS btree_gist;
-- Não é usada por nenhuma constraint neste schema (o controle de
-- capacidade de agenda_datas/agendamentos é feito por transação, não
-- por EXCLUDE) — mantida habilitada porque não tem custo, e pode ser
-- útil em constraints futuras. Se nunca for usada, pode ser removida.

-- ==========================================================
-- USUÁRIOS, PAPÉIS, SESSÕES, AUDITORIA
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
        CHECK (nome IN ('administrador', 'recepcionista'))
);
-- RBAC simplificado (decisão do responsável técnico do projeto, não do
-- instituto — registrado assim em SDP_DECISOES_PENDENTES.md, Parte B).
-- "Gestor" e "Auditor" saíram do MVP. Acesso técnico/infraestrutura
-- continua fora deste RBAC de aplicação — usuário de banco separado
-- (db_owner/app_runtime, T04), nunca um papel de login.

CREATE TABLE usuarios_papeis (
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    papel_id INTEGER NOT NULL REFERENCES papeis(id),
    PRIMARY KEY (usuario_id, papel_id)
);

CREATE TABLE sessoes (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    criado_em TIMESTAMP NOT NULL DEFAULT now(),
    expira_em TIMESTAMP NOT NULL,
    revogado_em TIMESTAMP,
    ip VARCHAR(45)
);

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

CREATE INDEX idx_auditoria_tabela_registro ON auditoria(tabela, registro_id);
CREATE INDEX idx_sessoes_usuario ON sessoes(usuario_id);

-- ==========================================================
-- ESCOLARIDADE COMPARÁVEL (correção C1)
-- ==========================================================

CREATE TABLE niveis_escolaridade (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(50) UNIQUE NOT NULL,
    ordem INTEGER UNIQUE NOT NULL
);

INSERT INTO niveis_escolaridade (nome, ordem) VALUES
    ('Fundamental incompleto', 1),
    ('Fundamental completo', 2),
    ('Médio incompleto', 3),
    ('Médio completo', 4),
    ('Superior incompleto', 5),
    ('Superior completo', 6);

-- ==========================================================
-- PESSOAS ATENDIDAS (D06)
-- ==========================================================
-- Documento (RG + CPF) sempre obrigatório — decisão explícita do
-- instituto, mesmo sabendo que isso impede o cadastro de alguém sem
-- documento (situação real em população em vulnerabilidade). Registrado
-- como escolha consciente em SDP_DECISOES_PENDENTES.md, D06, não como
-- lacuna esquecida — revisitar se algum dia isso precisar mudar.

CREATE TABLE pessoas (
    id SERIAL PRIMARY KEY,

    -- Protegidos: imutáveis após o cadastro (trigger abaixo)
    nome VARCHAR(150) NOT NULL,
    rg VARCHAR(20) NOT NULL,
    cpf CHAR(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    data_nascimento DATE NOT NULL,

    -- Contato (editável)
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(150),

    -- Endereço (editável, estruturado — preenchido via API ViaCEP)
    cep CHAR(8),
    logradouro VARCHAR(150),
    numero VARCHAR(10),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    uf CHAR(2),

    -- Título de eleitor (opcional, uso confirmado)
    titulo_eleitor VARCHAR(12),
    titulo_secao VARCHAR(5),
    titulo_zona VARCHAR(5),

    -- Pré-requisitos de curso (opcionais, por demanda — D07)
    escolaridade_id INTEGER REFERENCES niveis_escolaridade(id),
    possui_cnh BOOLEAN, -- NULL = não informado; TRUE/FALSE = resposta real

    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_pessoas_nome ON pessoas(nome);
-- RG sem UNIQUE de propósito: emitido por estado, pode repetir número
-- entre estados diferentes — UNIQUE geraria falso positivo de duplicidade.

CREATE OR REPLACE FUNCTION bloquear_alteracao_campos_protegidos()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.nome IS DISTINCT FROM OLD.nome
       OR NEW.rg IS DISTINCT FROM OLD.rg
       OR NEW.cpf IS DISTINCT FROM OLD.cpf
       OR NEW.data_nascimento IS DISTINCT FROM OLD.data_nascimento THEN
        RAISE EXCEPTION 'Campos protegidos não podem ser alterados diretamente (pessoa id=%). Use o processo de correção cadastral.', OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloquear_alteracao_campos_protegidos
BEFORE UPDATE ON pessoas
FOR EACH ROW EXECUTE FUNCTION bloquear_alteracao_campos_protegidos();

CREATE TABLE correcoes_cadastrais (
    id SERIAL PRIMARY KEY,
    pessoa_id INTEGER NOT NULL REFERENCES pessoas(id),
    campo VARCHAR(30) NOT NULL CHECK (campo IN ('nome','rg','cpf','data_nascimento')),
    valor_anterior VARCHAR(150) NOT NULL,
    valor_novo VARCHAR(150) NOT NULL,
    justificativa TEXT NOT NULL,
    aprovado_por INTEGER NOT NULL REFERENCES usuarios(id),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);
-- Correção auditada: UPDATE direto nos 4 campos protegidos falha
-- (trigger acima); correção real passa por INSERT aqui, com
-- justificativa e aprovador, seguida de processo administrativo.

-- ==========================================================
-- ELEGIBILIDADE GERAL POR PESSOA (D01) — somente-inserção
-- ==========================================================

CREATE TABLE avaliacoes_elegibilidade (
    id SERIAL PRIMARY KEY,
    pessoa_id INTEGER NOT NULL REFERENCES pessoas(id),
    decisao VARCHAR(20) NOT NULL
        CHECK (decisao IN ('elegivel','nao_elegivel','em_avaliacao','necessita_revisao')),
    recebe_beneficio_governo BOOLEAN,
    participa_projeto_social BOOLEAN,
    renda_familiar NUMERIC(10,2),
    justificativa TEXT,
    responsavel_id INTEGER NOT NULL REFERENCES usuarios(id),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_avaliacoes_pessoa_data ON avaliacoes_elegibilidade(pessoa_id, criado_em DESC);

CREATE VIEW elegibilidade_vigente AS
SELECT DISTINCT ON (pessoa_id) *
FROM avaliacoes_elegibilidade
ORDER BY pessoa_id, criado_em DESC;
-- Reavaliação é possível: cada reavaliação é um INSERT novo, nunca um
-- UPDATE do registro anterior. A decisão "vigente" é sempre a mais
-- recente (esta view), o histórico completo fica preservado na tabela.

-- ==========================================================
-- ORGANIZAÇÕES PARCEIRAS (D02) — sem login
-- ==========================================================

CREATE TABLE organizacoes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    tipo_contato VARCHAR(100),
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

-- ==========================================================
-- SERVIÇOS — pré-requisito objetivo (D07), governança (D03)
-- ==========================================================
-- D03: só 'administrador' escreve aqui — aplicado na API (RBAC),
-- não como restrição de banco, porque o mesmo usuário de aplicação
-- (app_runtime) atende requisições de qualquer papel.

CREATE TABLE servicos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    organizacao_id INTEGER REFERENCES organizacoes(id),
    tipo VARCHAR(30),
    idade_minima INTEGER,
    escolaridade_minima_id INTEGER REFERENCES niveis_escolaridade(id),
    requer_cnh BOOLEAN NOT NULL DEFAULT FALSE,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

-- ==========================================================
-- SOLICITAÇÃO DE SERVIÇO — com snapshot de pré-requisito (correção C3)
-- ==========================================================

CREATE TABLE solicitacoes_servico (
    id SERIAL PRIMARY KEY,
    pessoa_id INTEGER NOT NULL REFERENCES pessoas(id),
    servico_id INTEGER NOT NULL REFERENCES servicos(id),
    status VARCHAR(30) NOT NULL DEFAULT 'pendente' CHECK (status IN (
        'pendente','apta_para_agendamento','bloqueada_por_prerequisito','nao_elegivel','cancelada'
    )),
    idade_pessoa_na_solicitacao INTEGER,
    escolaridade_pessoa_id_na_solicitacao INTEGER REFERENCES niveis_escolaridade(id),
    possui_cnh_pessoa_na_solicitacao BOOLEAN,
    prerequisito_atendido BOOLEAN,
    criado_por INTEGER NOT NULL REFERENCES usuarios(id),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_solicitacoes_pessoa ON solicitacoes_servico(pessoa_id);

CREATE OR REPLACE FUNCTION snapshotar_prerequisitos_solicitacao()
RETURNS TRIGGER AS $$
DECLARE
    v_pessoa RECORD;
    v_servico RECORD;
    v_idade INTEGER;
    v_escolaridade_ordem INTEGER;
    v_escolaridade_minima_ordem INTEGER;
    v_atende BOOLEAN := TRUE;
BEGIN
    SELECT * INTO v_pessoa FROM pessoas WHERE id = NEW.pessoa_id;
    SELECT * INTO v_servico FROM servicos WHERE id = NEW.servico_id;

    v_idade := EXTRACT(YEAR FROM age(CURRENT_DATE, v_pessoa.data_nascimento));

    NEW.idade_pessoa_na_solicitacao := v_idade;
    NEW.escolaridade_pessoa_id_na_solicitacao := v_pessoa.escolaridade_id;
    NEW.possui_cnh_pessoa_na_solicitacao := v_pessoa.possui_cnh;

    IF v_servico.idade_minima IS NOT NULL AND v_idade < v_servico.idade_minima THEN
        v_atende := FALSE;
    END IF;

    IF v_servico.escolaridade_minima_id IS NOT NULL THEN
        SELECT ordem INTO v_escolaridade_ordem FROM niveis_escolaridade WHERE id = v_pessoa.escolaridade_id;
        SELECT ordem INTO v_escolaridade_minima_ordem FROM niveis_escolaridade WHERE id = v_servico.escolaridade_minima_id;
        IF v_escolaridade_ordem IS NULL OR v_escolaridade_ordem < v_escolaridade_minima_ordem THEN
            v_atende := FALSE;
        END IF;
    END IF;

    IF v_servico.requer_cnh AND COALESCE(v_pessoa.possui_cnh, FALSE) = FALSE THEN
        v_atende := FALSE;
    END IF;

    NEW.prerequisito_atendido := v_atende;
    IF NOT v_atende AND NEW.status = 'pendente' THEN
        NEW.status := 'bloqueada_por_prerequisito';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_snapshotar_prerequisitos
BEFORE INSERT ON solicitacoes_servico
FOR EACH ROW EXECUTE FUNCTION snapshotar_prerequisitos_solicitacao();

-- ==========================================================
-- AGENDA (D08, D09) — capacidade decidida por transação (correção C2)
-- ==========================================================
-- D09: agenda sempre cadastrada pelo atendente em nome do profissional
-- (responsavel_usuario_id é referência informativa, nullable — o
-- profissional nunca loga no sistema, papel "profissional" não existe).

CREATE TABLE agenda_datas (
    id SERIAL PRIMARY KEY,
    servico_id INTEGER NOT NULL REFERENCES servicos(id),
    responsavel_usuario_id INTEGER REFERENCES usuarios(id),
    data DATE NOT NULL,
    capacidade INTEGER NOT NULL CHECK (capacidade > 0),
    criado_em TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (servico_id, data)
);

CREATE INDEX idx_agenda_datas_servico_data ON agenda_datas(servico_id, data);

CREATE TABLE agendamentos (
    id SERIAL PRIMARY KEY,
    solicitacao_servico_id INTEGER NOT NULL REFERENCES solicitacoes_servico(id),
    agenda_data_id INTEGER NOT NULL REFERENCES agenda_datas(id),
    status VARCHAR(20) NOT NULL DEFAULT 'agendado' CHECK (status IN (
        'agendado','concluido','cancelado','nao_compareceu'
    )),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE fila_espera (
    id SERIAL PRIMARY KEY,
    solicitacao_servico_id INTEGER NOT NULL REFERENCES solicitacoes_servico(id),
    servico_id INTEGER NOT NULL REFERENCES servicos(id),
    status VARCHAR(20) NOT NULL DEFAULT 'aguardando'
        CHECK (status IN ('aguardando','chamado','expirado','atendido')),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_fila_espera_servico_ordem ON fila_espera(servico_id, criado_em);

-- Alocação de vaga (correção C2): decide capacidade ANTES do insert,
-- travando a linha da data (FOR UPDATE) — resolve a corrida real entre
-- duas solicitações concorrentes sem usar exceção como fluxo normal
-- (fila de espera é o caso comum de um serviço popular, não um erro).
CREATE OR REPLACE FUNCTION alocar_atendimento(
    p_solicitacao_id INTEGER,
    p_agenda_data_id INTEGER
) RETURNS TABLE(resultado TEXT, agendamento_id INTEGER, fila_espera_id INTEGER) AS $$
DECLARE
    v_capacidade INTEGER;
    v_ocupados INTEGER;
    v_agendamento_id INTEGER;
    v_fila_id INTEGER;
    v_servico_id INTEGER;
BEGIN
    SELECT capacidade, servico_id INTO v_capacidade, v_servico_id
    FROM agenda_datas WHERE id = p_agenda_data_id FOR UPDATE;

    SELECT COUNT(*) INTO v_ocupados FROM agendamentos
        WHERE agenda_data_id = p_agenda_data_id AND status <> 'cancelado';

    IF v_ocupados < v_capacidade THEN
        INSERT INTO agendamentos (solicitacao_servico_id, agenda_data_id)
        VALUES (p_solicitacao_id, p_agenda_data_id)
        RETURNING id INTO v_agendamento_id;
        RETURN QUERY SELECT 'agendado'::TEXT, v_agendamento_id, NULL::INTEGER;
    ELSE
        INSERT INTO fila_espera (solicitacao_servico_id, servico_id)
        VALUES (p_solicitacao_id, v_servico_id)
        RETURNING id INTO v_fila_id;
        RETURN QUERY SELECT 'fila_espera'::TEXT, NULL::INTEGER, v_fila_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Rede de segurança (não deveria disparar em uso normal via alocar_atendimento)
CREATE OR REPLACE FUNCTION checar_capacidade_agenda() RETURNS TRIGGER AS $$
DECLARE
    ocupados INTEGER;
    capacidade_max INTEGER;
BEGIN
    SELECT capacidade INTO capacidade_max FROM agenda_datas WHERE id = NEW.agenda_data_id;
    SELECT COUNT(*) INTO ocupados FROM agendamentos
        WHERE agenda_data_id = NEW.agenda_data_id AND status <> 'cancelado';
    IF ocupados > capacidade_max THEN
        RAISE EXCEPTION 'Rede de seguranca: capacidade violada para agenda_data_id=% (max=%, ocupados=%). Isso nao deveria acontecer via alocar_atendimento().',
            NEW.agenda_data_id, capacidade_max, ocupados;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_checar_capacidade_agenda
AFTER INSERT ON agendamentos
FOR EACH ROW EXECUTE FUNCTION checar_capacidade_agenda();

-- ==========================================================
-- ATENDIMENTO (D04) — só compareceu/não compareceu
-- ==========================================================

CREATE TABLE atendimentos (
    id SERIAL PRIMARY KEY,
    agendamento_id INTEGER NOT NULL UNIQUE REFERENCES agendamentos(id),
    compareceu BOOLEAN NOT NULL,
    registrado_por INTEGER NOT NULL REFERENCES usuarios(id),
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION atualizar_status_agendamento_por_atendimento()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE agendamentos
    SET status = CASE WHEN NEW.compareceu THEN 'concluido' ELSE 'nao_compareceu' END
    WHERE id = NEW.agendamento_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualizar_status_por_atendimento
AFTER INSERT ON atendimentos
FOR EACH ROW EXECUTE FUNCTION atualizar_status_agendamento_por_atendimento();

-- ==========================================================
-- CENTRAL DE ATENDIMENTO OMNICHANNEL — FASE 1 (NOVO nesta versão)
-- ==========================================================
-- Fase 1: estrutura pronta, preenchimento manual pela recepcionista —
-- sem chamada real a API de WhatsApp/Instagram/Facebook/TikTok ainda
-- (ver docs/ARQUITETURA.md, seção 6). Sem D0x formalmente registrada —
-- ver docs/REQUISITOS.md, seção 9.

CREATE TABLE canais (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(80) UNIQUE NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN (
        'site','whatsapp','instagram','facebook','tiktok','email','telefone','presencial'
    )),
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO canais (nome, tipo) VALUES
    ('Presencial', 'presencial'),
    ('Telefone', 'telefone'),
    ('WhatsApp', 'whatsapp'),
    ('E-mail', 'email'),
    ('Instagram', 'instagram'),
    ('Facebook', 'facebook'),
    ('TikTok', 'tiktok'),
    ('Site', 'site');

-- pessoa_id NULL até a recepcionista identificar quem está entrando em contato
CREATE TABLE conversas (
    id SERIAL PRIMARY KEY,
    canal_id INTEGER NOT NULL REFERENCES canais(id),
    pessoa_id INTEGER REFERENCES pessoas(id),
    atendente_id INTEGER REFERENCES usuarios(id),
    status VARCHAR(20) NOT NULL DEFAULT 'nova' CHECK (status IN (
        'nova','em_atendimento','aguardando_pessoa','resolvida','encerrada'
    )),
    iniciada_em TIMESTAMP NOT NULL DEFAULT now(),
    ultima_interacao_em TIMESTAMP,
    encerrada_em TIMESTAMP
);

CREATE INDEX idx_conversas_status ON conversas(status);
CREATE INDEX idx_conversas_pessoa ON conversas(pessoa_id);

-- Somente-inserção: mensagem já recebida/enviada não é editável (mesmo
-- princípio de auditoria e avaliacoes_elegibilidade).
CREATE TABLE mensagens (
    id SERIAL PRIMARY KEY,
    conversa_id INTEGER NOT NULL REFERENCES conversas(id),
    remetente_tipo VARCHAR(20) NOT NULL CHECK (remetente_tipo IN ('pessoa','atendente','sistema')),
    usuario_id INTEGER REFERENCES usuarios(id), -- preenchido quando remetente_tipo = 'atendente'
    conteudo TEXT NOT NULL,
    identificador_externo VARCHAR(255) UNIQUE, -- id da mensagem na API externa (uso a partir da Fase 2)
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_mensagens_conversa ON mensagens(conversa_id, criado_em);

-- MELHORIA: ultima_interacao_em deixa de depender de o Backend lembrar
-- de atualizar toda vez que chega mensagem — o banco garante isso.
CREATE OR REPLACE FUNCTION atualizar_ultima_interacao_conversa()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversas
    SET ultima_interacao_em = NEW.criado_em
    WHERE id = NEW.conversa_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualizar_ultima_interacao_conversa
AFTER INSERT ON mensagens
FOR EACH ROW EXECUTE FUNCTION atualizar_ultima_interacao_conversa();

-- Solicitação em nível de atendimento (ticket) — diferente de
-- solicitacoes_servico (pedido de um serviço específico já existente).
-- Uma solicitacao pode originar uma solicitacoes_servico quando o tipo é
-- 'agendamento'; para 'informacao' ou 'outro', fica só como registro do
-- que foi pedido e resolvido na conversa.
CREATE TABLE solicitacoes (
    id SERIAL PRIMARY KEY,
    conversa_id INTEGER REFERENCES conversas(id),
    pessoa_id INTEGER REFERENCES pessoas(id),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('agendamento','informacao','elegibilidade','outro')),
    solicitacao_servico_id INTEGER REFERENCES solicitacoes_servico(id),
    descricao TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'aberta' CHECK (status IN (
        'aberta','em_andamento','concluida','cancelada'
    )),
    responsavel_id INTEGER REFERENCES usuarios(id),
    criada_em TIMESTAMP NOT NULL DEFAULT now(),
    concluida_em TIMESTAMP,

    CONSTRAINT ck_solicitacoes_vinculo_agendamento CHECK (
        tipo <> 'agendamento' OR solicitacao_servico_id IS NOT NULL
    )
);

CREATE INDEX idx_solicitacoes_status ON solicitacoes(status);
CREATE INDEX idx_solicitacoes_pessoa_atendimento ON solicitacoes(pessoa_id);
CREATE INDEX idx_solicitacoes_conversa ON solicitacoes(conversa_id);
-- MELHORIA em relação à versão anterior deste documento: faltava índice
-- por conversa_id, mas a consulta mais óbvia da tela ("tickets desta
-- conversa") filtra exatamente por essa coluna.

-- MELHORIA: concluida_em deixa de depender de o Backend lembrar de
-- preencher a data toda vez que o status muda para 'concluida' — mesmo
-- princípio já usado em atendimentos/agendamentos.
CREATE OR REPLACE FUNCTION registrar_conclusao_solicitacao()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'concluida' AND OLD.status IS DISTINCT FROM 'concluida' THEN
        NEW.concluida_em := now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_registrar_conclusao_solicitacao
BEFORE UPDATE ON solicitacoes
FOR EACH ROW EXECUTE FUNCTION registrar_conclusao_solicitacao();

-- ==========================================================
-- USUÁRIO DE APLICAÇÃO (permissões restritas — é este que o backend usa)
-- ==========================================================
-- Os dois papéis de banco continuam propositalmente diferentes:
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
-- Note: o GRANT acima NÃO inclui DELETE em nenhuma tabela por padrão —
-- cada tabela que realmente precisa de DELETE recebe abaixo, de forma
-- explícita. A maioria das mudanças de estado deste schema é feita por
-- UPDATE de coluna `status`/`ativo`, não por remoção física de linha.

-- Papéis (catálogo): a aplicação atribui/remove papel de um usuário via
-- usuarios_papeis, mas não redefine o que cada papel "é".
REVOKE INSERT, UPDATE, DELETE ON papeis FROM app_runtime;

-- usuarios_papeis PRECISA de DELETE (não coberto pelo GRANT genérico
-- acima) — é assim que um papel é removido de um usuário. Sem isso, o
-- backend consegue atribuir papel mas nunca revogar.
GRANT DELETE ON usuarios_papeis TO app_runtime;

-- Usuários e sessões: nenhum registro é apagado fisicamente — usuário
-- desativado vira `ativo = false`, sessão revogada vira `revogado_em`
-- preenchido. Nenhum dos dois some da tabela.
REVOKE DELETE ON usuarios, sessoes FROM app_runtime;

-- Auditoria: somente consulta e inserção (append-only) — auditoria que
-- pode ser editada não serve como evidência.
REVOKE UPDATE, DELETE ON auditoria FROM app_runtime;

-- Elegibilidade: somente-inserção por design (seção "Elegibilidade
-- geral por pessoa" acima) — reavaliação é sempre um novo registro,
-- nunca uma alteração do anterior.
REVOKE UPDATE, DELETE ON avaliacoes_elegibilidade FROM app_runtime;

-- Correções cadastrais: é o próprio mecanismo de correção auditada —
-- não faria sentido "corrigir a correção" com UPDATE direto.
REVOKE UPDATE, DELETE ON correcoes_cadastrais FROM app_runtime;

-- Mensagens: somente-inserção (log de conversa), mesmo princípio de
-- auditoria — uma mensagem recebida/enviada não deveria virar outra
-- coisa depois de registrada.
REVOKE UPDATE, DELETE ON mensagens FROM app_runtime;

-- Função chamada diretamente pela aplicação (alocar_atendimento):
-- Postgres concede EXECUTE a PUBLIC por padrão em funções novas. Aqui
-- isso é revogado e concedido explicitamente só a app_runtime, mesmo
-- princípio de menor privilégio já aplicado ao resto do schema.
REVOKE EXECUTE ON FUNCTION alocar_atendimento(INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION alocar_atendimento(INTEGER, INTEGER) TO app_runtime;

-- ==========================================================
-- PENDÊNCIA CONHECIDA — não é decisão nova, é dívida técnica registrada
-- ==========================================================
-- O backend já entregue (auth) foi construído antes de D03-D09
-- fecharem e ainda espera o RBAC antigo (administrador, gestor,
-- funcionario, avaliador, auditor). Depois de rodar este script,
-- qualquer código/seed que insira em `papeis` com esses valores antigos
-- vai falhar no CHECK acima (de propósito) — é o sinal de que a
-- migration do backend para 'administrador'/'recepcionista' ainda
-- precisa ser feita antes de qualquer dado real.
--
-- Testes ainda não executados contra este script consolidado (rodar
-- antes de considerar 100% validado): os 4 novos da Central de
-- Atendimento (13-16) e os 3 das correções de privilégio (GRANT DELETE
-- em usuarios_papeis, REVOKE em avaliacoes_elegibilidade/
-- correcoes_cadastrais, EXECUTE restrito em alocar_atendimento) — ver
-- docs/BANCO_DADOS.md, seção 6. Os dois triggers novos desta versão
-- (atualizar_ultima_interacao_conversa, registrar_conclusao_solicitacao)
-- também ainda não têm teste documentado.