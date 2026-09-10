# Segurança

> Estas regras são transversais a todo o sistema — não são um módulo à parte, são requisito de todo módulo que for construído. Nenhuma delas é opcional: o projeto lida com dados pessoais de pessoas em situação de vulnerabilidade e com decisões de elegibilidade que afetam diretamente o acesso delas a um recurso escasso.

## Regra fundamental

```text
Usuário
   ↓
Autenticação
   ↓
Autorização
   ↓
Validação
   ↓
Regra de negócio
   ↓
Banco de dados
```

**O Frontend nunca é a camada que garante segurança.** Se o Frontend esconder um menu de administração, isso não significa que o usuário não possa acessar a API diretamente. O Backend precisa negar com `403 Forbidden` independentemente do que o cliente enviar.

## As regras obrigatórias

1. **Nunca expor secrets** — variáveis de ambiente ou gerenciador de secrets; nunca no código ou no Frontend.
2. **Remover secrets do Git e impedir novos vazamentos** — `.gitignore`, secret scanning; secret exposto deve ser revogado e substituído, nunca apenas removido do commit seguinte.
3. **Hash seguro das senhas** — Argon2id ou bcrypt; nunca texto puro, nunca hash reversível como MD5.
4. **Autenticação no lado do servidor via sessão** — nunca confiar em dado de identidade enviado pelo Frontend. Sessão controlada pelo servidor conforme `ARQUITETURA.md` — não JWT stateless puro.
5. **Autorização baseada em papéis (RBAC)** — 2 papéis (`administrador`, `recepcionista`; ver `REGRAS_NEGOCIO.md`, seção 4), verificada em todo endpoint sensível.
6. **Princípio do menor privilégio** — conforme `REGRAS_NEGOCIO.md`, seção 1.1. Acesso técnico de infraestrutura/desenvolvimento nunca é um papel de login da aplicação.
7. **Row Level Security (RLS)** quando aplicável no banco — camada extra que impede acesso a registro fora do escopo do usuário mesmo se a checagem da aplicação falhar.
8. **Criptografia dos dados sensíveis em repouso** — especialmente decisão de elegibilidade e sua justificativa. Mecanismo exato ainda em aberto — ver T05 em `SDP_DECISOES_PENDENTES.md`.
9. **HTTPS obrigatório** em toda comunicação entre navegador e API — e entre plataforma externa e webhook, a partir da Fase 2 da Central de Atendimento.
10. **Cookies de sessão seguros** — atributos `HttpOnly`, `Secure`, `SameSite=Strict`, expiração controlada e revogação real no logout (ver tabela `sessoes`).
11. **Queries parametrizadas** — nunca concatenar SQL com dado vindo do usuário (proteção contra SQL Injection).
12. **Validação e sanitização de toda entrada** recebida pela API — tipo, tamanho, formato, valores permitidos, regra de negócio.
13. **Proteção contra Mass Assignment** — campos alteráveis definidos explicitamente por operação; uma recepcionista nunca consegue, por exemplo, enviar `papel=administrador` numa edição de cadastro.
14. **Rate Limiting** — limitar tentativas de login e endpoints sensíveis contra abuso.
15. **Proteção contra automação e bots** (CAPTCHA ou equivalente) em qualquer endpoint público com risco real de abuso.
    > ⚠️ **Atualização:** esta regra dizia que "hoje o sistema não tem endpoint público voltado à pessoa atendida" — isso deixou de ser verdade a partir da Fase 2 da Central de Atendimento (`ARQUITETURA.md`, seção 6), quando endpoints de webhook (`/webhooks/whatsapp` etc.) passam a ser alcançáveis pela internet. Para esses endpoints especificamente, a proteção não é CAPTCHA (não faz sentido para webhook automatizado) — é a **verificação de assinatura do provedor**, já descrita em `ARQUITETURA.md`, seção 2.1, como regra fixa obrigatória antes de processar qualquer payload.
16. **Restrição e validação de uploads** — tamanho, extensão, MIME type; nunca confiar apenas na extensão enviada. Aplica-se a qualquer anexo futuro (ex.: documento de comprovação para avaliação de elegibilidade).
17. **Headers de segurança** — `Content-Security-Policy`, `HSTS`, `X-Content-Type-Options` e políticas de framing/referrer configuradas corretamente.
18. **Auditoria e logs de segurança** — login, falhas de autenticação, alteração de permissões, **decisão de elegibilidade e sua alteração**, acesso e alteração de dados de pessoa atendida.
19. **Varredura de dependências (SCA)** — bibliotecas atualizadas, vulnerabilidades conhecidas monitoradas.
20. **Backup seguro e testado** — backup automatizado, protegido contra acesso indevido, com restauração testada periodicamente (metas de RPO/RTO ainda em aberto — ver T06 em `SDP_DECISOES_PENDENTES.md`). Backup que nunca foi restaurado em teste não deve ser considerado uma estratégia de recuperação confiável.

## Regra específica do domínio: decisão de elegibilidade é auditável por natureza

Diferente de um sistema comum, aqui a auditoria não é só uma boa prática de segurança — é o que permite ao instituto demonstrar, a doadores ou órgãos de fiscalização, que a alocação de um recurso gratuito e limitado seguiu critério, não favorecimento. Qualquer alteração de decisão de elegibilidade sem justificativa registrada deve ser tratada como falha grave, não só como falta de boa prática.

## Teste específico obrigatório: IDOR

**IDOR (Insecure Direct Object Reference)** é a falha em que um usuário autenticado consegue acessar dado de outro só trocando um ID na URL.

```text
Login como recepcionista sem relação com a pessoa 101
GET /api/pessoas/101 → 403 Forbidden (esperado)
```

Se retornar o dado em vez de erro, é uma falha crítica — trate como bloqueante para qualquer entrega, inclusive para apresentação ao cliente.

## Como este documento deve ser usado

- Cada regra desta lista deve ter pelo menos um teste automatizado ou manual documentado provando que ela está implementada.
- Uma funcionalidade nova que introduz um novo tipo de dado sensível (ex.: upload de documento de comprovação de vulnerabilidade) volta a este documento para reavaliar quais regras se aplicam antes de ir para produção.