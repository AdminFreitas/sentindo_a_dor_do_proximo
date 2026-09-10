# Banco de Dados — Sentindo a Dor do Próximo

Banco de Dados: PostgreSQL. Justificativa em `ARQUITETURA.md`.

> ✅ **Schema definitivo (D01–D09) + Central de Atendimento omnichannel, Fase 1.** Todas as 9 decisões de negócio que bloqueavam o modelo original foram fechadas. Esta versão soma as tabelas de Central de Atendimento confirmadas em `ARQUITETURA.md`, seção 6, seguindo o faseamento ali recomendado: **Fase 1 = registro manual do canal de origem pela recepcionista, sem integração real de API ainda.** Chave primária continua `SERIAL` em todo o schema — decisão explícita de `ARQUITETURA.md`, não `UUID`.
>
> ⚠️ Ver seção 7 para duas pendências reais que este documento não resolve sozinho: sincronização com `REQUISITOS.md` (que ainda declara "sem canal de mensagens" como confirmado) e a origem da confirmação do requisito de omnichannel.

## 1. O que mudou nesta versão

| Mudança | Motivo |
|---|---|
| `pessoas`, `organizacoes`, `servicos`, `solicitacoes_servico`, `avaliacoes_elegibilidade`, `agenda_datas`, `agendamentos`, `fila_espera`, `atendimentos` | D01–D09 fechadas (sem mudança nesta rodada) |
| `niveis_escolaridade` (ordem comparável) | Corrige comparação de texto livre |
| `alocar_atendimento()` decide antes do `INSERT`, via `FOR UPDATE` | Fila de espera é fluxo normal, não exceção |
| Snapshot de pré-requisito em `solicitacoes_servico` | Preserva o que foi realmente checado, mesmo se o serviço/pessoa mudarem depois |
| `papeis` = `administrador`/`recepcionista` | RBAC simplificado — ver ressalva na seção 7 |
| **`canais`, `conversas`, `mensagens`, `solicitacoes` (NOVO)** | **Central de Atendimento omnichannel, Fase 1 — ver `ARQUITETURA.md`, seção 6, e `REGRAS_NEGOCIO.md`, seção 9** |
| `trg_atualizar_ultima_interacao_conversa`, `trg_registrar_conclusao_solicitacao`, `idx_solicitacoes_conversa` (NOVO) | Melhorias: dois campos que dependiam do Backend lembrar de atualizar (`conversas.ultima_interacao_em`, `solicitacoes.concluida_em`) passam a ser garantidos pelo banco; índice que faltava para a consulta mais óbvia de tela ("tickets desta conversa") |

## 2. DER — Entidades e relacionamentos

```text
usuarios (1) ──── (N) usuarios_papeis (N) ──── (1) papeis ['administrador'|'recepcionista']
usuarios (1) ──── (N) sessoes
usuarios (1) ──── (N) auditoria

niveis_escolaridade (1) ──── (N) pessoas.escolaridade_id
niveis_escolaridade (1) ──── (N) servicos.escolaridade_minima_id

pessoas (1) ──── (N) avaliacoes_elegibilidade
pessoas (1) ──── (N) correcoes_cadastrais
pessoas (1) ──── (N) solicitacoes_servico
pessoas (1) ──── (N) conversas            [pessoa_id NULL até identificação]

organizacoes (1) ──── (N) servicos

solicitacoes_servico (N) ──── (1) servicos
solicitacoes_servico (1) ──── (0..1) agendamentos
solicitacoes_servico (1) ──── (0..1) fila_espera

servicos (1) ──── (N) agenda_datas
agenda_datas (1) ──── (N) agendamentos

agendamentos (1) ──── (0..1) atendimentos

-- Central de Atendimento (Fase 1) --
canais (1) ──── (N) conversas
conversas (1) ──── (N) mensagens
conversas (1) ──── (N) solicitacoes
solicitacoes (0..1) ──── (1) solicitacoes_servico   [só quando tipo = 'agendamento']
```

> **Nomenclatura próxima, significado diferente:** `solicitacoes` (ticket de atendimento aberto numa conversa — pode ser "informação", "elegibilidade", "outro") não é o mesmo que `solicitacoes_servico` (pedido concreto de um serviço específico, com checagem de pré-requisito e snapshot). Uma `solicitacao` de tipo `agendamento` sempre aponta para uma `solicitacoes_servico`; as demais não. Nomes parecidos de propósito — mas vale ficar atento na hora de escrever query ou código, é um erro fácil de cometer sem perceber.

## 3. Extensão

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;
```

Mantida sem custo, mas nenhuma constraint depende dela hoje — o controle de capacidade é feito por transação (`alocar_atendimento()`), não por `EXCLUDE`.

## 4. DDL completa

### 4.1 Usuários, papéis, sessões, auditoria

```sql
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
```

### 4.2 Escolaridade comparável

```sql
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
```

### 4.3 Pessoas atendidas

```sql
CREATE TABLE pessoas (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    rg VARCHAR(20) NOT NULL,
    cpf CHAR(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    data_nascimento DATE NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    email VARCHAR(150),
    cep CHAR(8),
    logradouro VARCHAR(150),
    numero VARCHAR(10),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    uf CHAR(2),
    titulo_eleitor VARCHAR(12),
    titulo_secao VARCHAR(5),
    titulo_zona VARCHAR(5),
    escolaridade_id INTEGER REFERENCES niveis_escolaridade(id),
    possui_cnh BOOLEAN,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_pessoas_nome ON pessoas(nome);

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
```

### 4.4 Elegibilidade geral por pessoa

```sql
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
```

### 4.5 Organizações parceiras

```sql
CREATE TABLE organizacoes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    tipo_contato VARCHAR(100),
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);
```

### 4.6 Serviços

```sql
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
```

### 4.7 Solicitação de serviço — com snapshot de pré-requisito

```sql
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
```

### 4.8 Agenda

```sql
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
```

### 4.9 Atendimento

```sql
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
```

### 4.10 Central de Atendimento omnichannel — Fase 1 (NOVO)

> Fase 1, conforme `ARQUITETURA.md`, seção 6: estrutura pronta, **preenchimento manual pela recepcionista** — sem chamada real a API de WhatsApp/Instagram/Facebook/TikTok ainda. Isso já entrega organização e auditoria do contato; a integração automática fica para a Fase 2, um canal por vez.

```sql
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
-- MELHORIA: faltava índice por conversa_id, mas a consulta mais óbvia
-- da tela ("tickets desta conversa") filtra exatamente por essa coluna.

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
```

**Por que `identificador_externo` é `UNIQUE` mesmo sendo `NULL` na Fase 1:** Postgres permite múltiplos `NULL` numa coluna `UNIQUE` (cada `NULL` é considerado distinto), então isso não impede nenhuma inserção manual hoje. Quando a Fase 2 chegar e passar a preencher esse campo com o ID da mensagem vindo da API externa, o `UNIQUE` vira proteção real contra processar o mesmo webhook duas vezes (reentrega é comportamento normal de APIs como a da Meta).

**Por que a `CHECK` em `solicitacoes` exige `solicitacao_servico_id` quando `tipo = 'agendamento'`:** evita o estado inconsistente de uma solicitação "tipo agendamento" sem nenhum pedido de serviço de fato vinculado — a integridade é garantida no banco, não só na aplicação.

## 5. Usuário de aplicação — privilégios (`app_runtime`)

```sql
GRANT CONNECT ON DATABASE sentindo_a_dor_do_proximo TO app_runtime;
GRANT USAGE ON SCHEMA public TO app_runtime;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_runtime;

REVOKE INSERT, UPDATE, DELETE ON papeis FROM app_runtime;
GRANT DELETE ON usuarios_papeis TO app_runtime;
REVOKE DELETE ON usuarios, sessoes FROM app_runtime;
REVOKE UPDATE, DELETE ON auditoria FROM app_runtime;
REVOKE UPDATE, DELETE ON avaliacoes_elegibilidade FROM app_runtime;
REVOKE UPDATE, DELETE ON correcoes_cadastrais FROM app_runtime;

-- NOVO: mensagens é somente-inserção (log de conversa), mesmo princípio
-- de auditoria — uma mensagem recebida/enviada não deveria virar outra
-- coisa depois de registrada.
REVOKE UPDATE, DELETE ON mensagens FROM app_runtime;

REVOKE EXECUTE ON FUNCTION alocar_atendimento(INTEGER, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION alocar_atendimento(INTEGER, INTEGER) TO app_runtime;
```

## 6. Bateria de testes

| # | Teste | Resultado |
|---|---|---|
| 1–12 | CPF, imutabilidade, pré-requisito, capacidade/fila, atendimento (ver histórico do documento) | ✅ Todos passaram |
| 13 *(novo)* | Inserir `conversa` com `pessoa_id` NULL | Deve funcionar (contato ainda não identificado) |
| 14 *(novo)* | Inserir `solicitacao` com `tipo = 'agendamento'` e `solicitacao_servico_id` NULL | Deve falhar (`CHECK`) |
| 15 *(novo)* | Inserir duas `mensagens` com o mesmo `identificador_externo` não nulo | Segunda deve falhar (`UNIQUE`) |
| 16 *(novo)* | Tentar `UPDATE` em `mensagens` com `app_runtime` | Deve falhar (`REVOKE`) |
| 17 *(novo)* | Inserir `mensagem` numa `conversa` | `conversas.ultima_interacao_em` dessa conversa deve atualizar sozinho, sem `UPDATE` explícito da aplicação |
| 18 *(novo)* | Alterar `solicitacoes.status` para `'concluida'` | `concluida_em` deve ser preenchido automaticamente; alterar para outro status não deve tocar `concluida_em` |

**Ainda não testados:** `GRANT DELETE` em `usuarios_papeis` de fato remove; `REVOKE` em `avaliacoes_elegibilidade`/`correcoes_cadastrais` de fato bloqueia; `alocar_atendimento()` falha sem `EXECUTE`. Somam-se aos testes 13–18 antes de considerar o script 100% validado contra Postgres real.

## 7. Pendências reais (não resolvidas só por este documento existir)

1. **Migration do RBAC antigo no backend** — segue pendente, sem mudança nesta rodada.
2. **Redução do RBAC a 2 papéis é decisão técnica**, não resposta do instituto a um D0x — vale confirmação explícita antes de produção.
3. ✅ **Resolvido:** `REQUISITOS.md` foi atualizado numa rodada seguinte — não declara mais "sem canal de mensagens" e já reflete D01–D09 fechadas e o RBAC de 2 papéis.
4. **Quem confirmou o requisito de omnichannel, e quando** — ainda sem resposta rastreável (nem data, nem responsável, diferente do padrão usado para D01–D09). Se isso vier a virar um "D10" formal em `SDP_DECISOES_PENDENTES.md`, registrar aqui a referência.

## 8. Checklist antes de considerar isso pronto para dado real

1. Rodar os testes pendentes (seção 6), incluindo os 6 novos (13–18).
2. Migration do backend para o RBAC novo.
3. ~~Atualizar `REQUISITOS.md`~~ ✅ feito numa rodada seguinte. Resolver a pendência 4 acima (proveniência do requisito de omnichannel) continua em aberto.
4. ✅ **Resolvido:** `db/init/db_init.sql` foi atualizado com as tabelas da seção 4.10 e as duas melhorias (triggers de `ultima_interacao_em`/`concluida_em`, índice `idx_solicitacoes_conversa`).
5. T03–T07 continuam pendentes, sem relação com o schema.
6. Fase 2 (integração real de canal) só começa depois que a Fase 1 estiver rodando com dado real por pelo menos um ciclo de uso.