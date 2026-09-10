# Arquitetura do Sistema — Sentindo a Dor do Próximo

> Versão 2 — evolui a arquitetura original com a Central de Atendimento omnichannel. `BANCO_DADOS.md` e `REGRAS_NEGOCIO.md` são evoluídos em documentos separados (já atualizados).

## 1. Visão geral

```text
                Site / WhatsApp / Instagram / Facebook / TikTok / E-mail / Telefone / Presencial
                                        ↓
                              Central de Atendimento
                            (recebe e organiza contato)
                                        ↓
Usuário (recepcionista/administrador)
        ↓
Frontend Web Responsivo
        ↓
Backend [Servidor] — FastAPI REST API
        ↓
PostgreSQL (Banco de Dados)
```

> **Isso não é IA/chatbot.** A exclusão de IA/agente autônomo continua válida — o sistema não responde ninguém sozinho. A Central de Atendimento apenas **recebe e organiza** mensagens vindas de canais externos, para que a recepcionista responda manualmente, com o mesmo controle de auditoria de qualquer outra ação.
>
> ⚠️ A origem da confirmação deste requisito (quem no instituto aprovou, quando) ainda não está registrada de forma rastreável — ver `REGRAS_NEGOCIO.md`, seção 9, e `BANCO_DADOS.md`, seção 7, item 4.

O Frontend continua nunca acessando o banco diretamente. Toda escrita ou leitura passa pelo Backend — único componente com credencial de banco.

## 2. Fluxo obrigatório de segurança

```text
Usuário
   ↓
Autenticação   (quem é você?)
   ↓
Autorização    (o que você pode fazer?)
   ↓
Validação      (o dado enviado é válido?)
   ↓
Regra de negócio  (isso é permitido nesse contexto?)
   ↓
Banco de dados
```

### 2.1 Caso especial: mensagens recebidas por canal externo (Fase 2)

Uma mensagem do WhatsApp/Instagram/Facebook/TikTok **não chega com login de usuário** — chega via *webhook* (ponto de entrada HTTP que a plataforma externa chama sozinha). Isso muda a primeira etapa do fluxo:

```text
Plataforma externa (Meta, WhatsApp Business, TikTok)
   ↓
Verificação de assinatura do webhook (HMAC/token do provedor — substitui "Autenticação")
   ↓
Validação do payload
   ↓
Regra de negócio (associar a uma pessoa/conversa existente ou criar nova)
   ↓
Banco de dados
```

**Regra fixa:** nenhum endpoint de webhook processa payload sem validar a assinatura fornecida pelo provedor (cada plataforma tem seu próprio mecanismo — ex.: Meta usa `X-Hub-Signature-256`). Sem essa verificação, qualquer um na internet poderia mandar payload forjado se descobrir a URL do endpoint. Ver `SEGURANCA.md`, regra 15, para a implicação disso em superfície de ataque pública.

## 3. Componentes

- **Frontend**: consome a API REST do Backend; SPA responsiva; nunca guarda token em `localStorage`/`sessionStorage`.
- **Backend**: Python + FastAPI, módulos por domínio (seção 5), incluindo o módulo `central_atendimento`.
- **Banco de dados**: PostgreSQL, nunca exposto publicamente.
- **Webhooks de canal** (a partir da Fase 2): endpoints HTTP públicos e específicos por provedor (`/webhooks/whatsapp`, `/webhooks/instagram` etc.), expostos via HTTPS, mas **sem acesso direto ao banco** — passam pela mesma camada de serviço que qualquer outra escrita.
- **Containerização**: Docker + Docker Compose orquestrando Backend e banco.

## 4. Estrutura de pastas

```text
sentindo_a_dor_do_proximo/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/
│   │   ├── db/
│   │   ├── modules/
│   │   │   ├── auth/
│   │   │   ├── usuarios/
│   │   │   ├── pessoas/
│   │   │   ├── servicos/
│   │   │   ├── elegibilidade/
│   │   │   ├── agendamentos/
│   │   │   ├── atendimentos/
│   │   │   ├── auditoria/
│   │   │   ├── central_atendimento/
│   │   │   │   ├── canais/
│   │   │   │   ├── conversas/
│   │   │   │   ├── mensagens/
│   │   │   │   ├── solicitacoes/
│   │   │   │   └── webhooks/            # verificação de assinatura por provedor
│   │   │   └── notificacoes/
│   │   └── shared/
│   ├── migrations/
│   ├── tests/
│   └── .env.example
├── db/
│   └── init/
├── frontend/
├── docs/
├── docker-compose.yml
├── .env.example
└── .gitignore
```

## 5. Padrão de camadas do backend

Sem mudança na regra de dependência: `router → service → repository → banco`. O `router` de webhook tem uma responsabilidade extra — verificar a assinatura **antes** de chamar o `service` — mas depois disso segue o mesmo caminho de qualquer escrita.

## 6. Decisões técnicas e justificativa

**RBAC continua com 2 papéis: `administrador` e `recepcionista`.**
A Central de Atendimento não exige papel novo — quem responde uma conversa de WhatsApp é a mesma recepcionista que já cadastra pessoa e agenda serviço. Nenhum profissional ou parceiro ganha login por causa disso (mantém D09 e D02 já fechadas).

**Chave primária: `SERIAL`, não `UUID`.**
Cada mensagem recebida já carrega um identificador próprio da plataforma de origem (`identificador_externo`) — isso resolve o problema que `UUID` resolveria (evitar colisão com IDs externos) sem trocar o tipo de chave primária de todo o banco. `SERIAL` continua mais simples de indexar e de ler em debug.

**Faseamento da integração — recomendação forte.**
Integrar de verdade com WhatsApp Business API, Meta Graph API (Instagram/Facebook) e TikTok API ao mesmo tempo é um projeto de infraestrutura por si só: cada uma exige cadastro de desenvolvedor aprovado, renovação periódica de token, e WhatsApp Business API tem custo por conversa em volume.

| Fase | O que entra | Por quê |
|---|---|---|
| **Fase 1 (MVP)** | Tabelas `canais`/`conversas`/`mensagens`/`solicitacoes` prontas; recepcionista registra manualmente de qual canal veio o contato | Entrega organização e auditoria imediatamente, sem depender de aprovação de terceiros |
| **Fase 2** | Integração real com um único canal (recomendado: WhatsApp) via webhook | Valida o fluxo com o menor risco antes de multiplicar por 4 plataformas |
| **Fase 3** | Instagram, Facebook, TikTok, conforme necessidade confirmada de uso real | Cada canal a mais tem o mesmo padrão de código, mas custo de manutenção próprio |

**Sem componente de IA.** Continua sem chatbot ou triagem automática.

## 7. Ambiente de desenvolvimento (Docker Compose)

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_ADMIN_USER}
      POSTGRES_PASSWORD: ${DB_ADMIN_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_ADMIN_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5

# O serviço "backend" entra no compose na Sprint 3. A partir da Fase 2
# (seção 6) ele passa a expor endpoints de webhook que precisam ser
# alcançáveis pela internet via HTTPS — responsabilidade da hospedagem
# (T03), não muda o princípio de que o BANCO continua em rede privada.

volumes:
  db_data:
```

Nenhuma senha ou chave vai no `docker-compose.yml`. Segredos de webhook (tokens de verificação de cada plataforma) seguem a mesma regra dos demais segredos: variável de ambiente, nunca no código, nunca versionados.