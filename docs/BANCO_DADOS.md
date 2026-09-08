# Banco de Dados — Sentindo a Dor do Próximo

Banco de Dados: PostgreSQL. Justificativa em `ARQUITETURA.md`.

> ⚠️ **Este documento não é o schema definitivo.** Ao contrário do projeto de referência (onde todas as entidades centrais já podiam ser definidas), aqui **quatro decisões do instituto ainda bloqueiam parte do modelo**: D01 (elegibilidade), D02 (organizações), D04 (o que é registrado no atendimento) e D06 (campos da pessoa atendida) — ver `SDP_DECISOES_PENDENTES.md`. Migrar isso para DDL completo antes de fechar essas decisões geraria retrabalho de banco já em produção, com dado de pessoa real dentro — o pior momento possível para redesenhar uma tabela central.

## 1. DER — Entidades e relacionamentos (conceitual)

```text
usuarios (1) ──── (N) usuarios_papeis (N) ──── (1) papeis
usuarios (1) ──── (N) sessoes
usuarios (1) ──── (N) auditoria

organizacoes (1) ──── (N) servicos            [entidade só existe se D02 confirmar parceiros]

pessoas (1) ──── (N) solicitacoes_servico     [campos de "pessoas" dependem de D06]
solicitacoes_servico (N) ──── (1) servicos
solicitacoes_servico (1) ──── (0..1) avaliacoes_elegibilidade   [modelo depende de D01]

solicitacoes_servico (1) ──── (0..1) agendamentos
agendamentos (1) ──── (0..1) atendimentos     [campos de "atendimentos" dependem de D04]
```

## 2. Extensão necessária (uso condicional)

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;
```

No projeto de referência, essa extensão viabiliza um `EXCLUDE constraint` que impede sobreposição de horário diretamente no banco. Aqui ela continua sendo o caminho recomendado **para serviços de agendamento individual** (um profissional, um horário). Para serviços por turma/vaga (ex.: um curso com número fixo de participantes), o mecanismo de controle de capacidade é diferente (contagem de inscrições vs. limite, não sobreposição de intervalo) — qual modelo se aplica a quais tipos de serviço ainda não foi confirmado e deve ser resolvido junto com D03/D04.

## 3. Tabelas seguras para rascunho agora

Estas independem de D01, D02, D04 e D06 — podem ser criadas com segurança já na Sprint 2:

```sql
-- Rascunho preliminar — sujeito a revisão, mas não depende de decisão pendente do instituto.

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
-- Se D05 confirmar que "avaliador" não existe como função separada, remover do CHECK
-- e migrar suas permissões para "funcionario" (ver REGRAS_NEGOCIO.md, seção 3).

CREATE TABLE usuarios_papeis (
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    papel_id INTEGER NOT NULL REFERENCES papeis(id),
    PRIMARY KEY (usuario_id, papel_id)
);

CREATE TABLE sessoes (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER NOT NULL REFERENCES usuarios(id),
    token_hash VARCHAR(255) NOT NULL,
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

-- O papel usado pela aplicação nunca recebe UPDATE/DELETE nesta tabela.
-- Auditoria que pode ser editada não serve como evidência.
REVOKE UPDATE, DELETE ON auditoria FROM app_runtime;

-- Papéis (catálogo): a aplicação atribui/remove papel de um usuário via
-- usuarios_papeis, mas não redefine o que cada papel "é" — isso é
-- mudança de schema/governança (migration), não ação da aplicação.
REVOKE INSERT, UPDATE, DELETE ON papeis FROM app_runtime;

-- Usuários e sessões: nenhum registro é apagado fisicamente — usuário
-- desativado vira `ativo = false`, sessão revogada vira `revogado_em`
-- preenchido. Nenhum dos dois some da tabela.
REVOKE DELETE ON usuarios, sessoes FROM app_runtime;
```

> Nota herdada do projeto de referência, ainda válida aqui: o `REVOKE` só protege de verdade se `app_runtime` for um usuário de banco **diferente** do usuário dono/migração. Ver `SDP_DECISOES_PENDENTES.md`, T04, e o script completo em `db_init.sql`, que já implementa essa separação (`db_owner` no `docker-compose.yml` vs. `app_runtime` criado dentro do script).

## 4. Tabelas que dependem de decisão pendente (não modelar ainda)

| Tabela (provisória) | Bloqueada por | O que muda quando a decisão fechar |
|---|---|---|
| `pessoas` | ❓ D06 | Campos exatos de identificação/contato; quais (se algum) entram na regra de imutabilidade (`REGRAS_NEGOCIO.md`, seção 1.2) |
| `organizacoes` | ❓ D02 | Se a tabela existe ou se "organização" vira um campo fixo único |
| `servicos` | ❓ D02, D03 | Se tem FK para `organizacoes`; quem tem escrita (Administrador só, ou nível intermediário) |
| `solicitacoes_servico` / `avaliacoes_elegibilidade` | ❓ D01 | Se elegibilidade liga à pessoa (geral) ou à solicitação (por serviço), ou modelo híbrido com regra de precedência |
| `agendamentos` | D01/D02/D03 (indireto) + modelo de disponibilidade (seção 2) | Estrutura de recurso (profissional+horário vs. turma+vaga) |
| `atendimentos` | ❓ D04 | Se é uma tabela única rígida ou com campos extensíveis por tipo de serviço; se inclui alguma camada de dado clínico (condicional, ver `REGRAS_NEGOCIO.md`, seção 4) |

Desenhar essas tabelas antes das respostas do instituto arrisca migração real em produção depois — o mesmo risco identificado no projeto de referência para as tabelas equivalentes de lá.

## 5. Padrão de imutabilidade e correção auditada (🔧 proposta, a aplicar quando D06 fechar)

O projeto de referência trava `cpf`/`nome` com um trigger específico. O padrão abaixo é o mesmo mecanismo, generalizado — a ser preenchido com os campos reais definidos por D06:

```sql
-- Modelo ilustrativo — os nomes de campo abaixo são placeholders,
-- não uma decisão sobre quais campos de "pessoas" serão protegidos.

CREATE OR REPLACE FUNCTION bloquear_alteracao_campo_protegido()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.<campo_protegido> <> OLD.<campo_protegido> THEN
        RAISE EXCEPTION 'Campo protegido não pode ser alterado diretamente (pessoa id=%)', OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bloquear_alteracao_campo_protegido
BEFORE UPDATE ON pessoas
FOR EACH ROW EXECUTE FUNCTION bloquear_alteracao_campo_protegido();
```

Correção de erro de digitação, quando essa regra existir: processo formal via tabela `correcoes_cadastrais` (justificativa, aprovação, vínculo ao registro original), nunca `UPDATE` direto — mesmo padrão do projeto de referência.

## 6. Índices

```sql
CREATE INDEX idx_auditoria_tabela_registro ON auditoria(tabela, registro_id);
CREATE INDEX idx_sessoes_usuario ON sessoes(usuario_id);
```

Índice de agendamento (equivalente a `idx_agendamentos_dentista_data` no projeto de referência) fica pendente até o modelo de disponibilidade (seção 2) e a estrutura de `agendamentos` (seção 4) estarem definidos.

## 7. Antes de seguir para o Backend — checklist possível hoje

Script executável correspondente às seções 3 e 6: `db_init.sql` (roda via `docker-entrypoint-initdb.d`, ver `ARQUITETURA.md`, seção 7).

Só é possível testar, nesta fase, o que não depende de decisão pendente:

1. Inserir usuário com e-mail duplicado → deve falhar (`UNIQUE`).
2. Marcar uma sessão como `revogado_em` preenchido → autenticação com esse token deve falhar.
3. Tentar `UPDATE`/`DELETE` em `auditoria` com o usuário de aplicação → deve falhar (permissão revogada).

Os testes equivalentes aos do projeto de referência para CPF/nome imutável, conflito de agendamento (`EXCLUDE`) e estouro de capacidade só podem ser escritos depois que D01, D02, D04 e D06 estiverem fechadas e o schema completo, definido.