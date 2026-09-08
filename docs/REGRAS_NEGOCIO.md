# Regras de Negócio — Sentindo a Dor do Próximo

> Este documento é normativo. Toda Pull Request que violar uma regra aqui descrita deve ser rejeitada na revisão de código, independentemente de quem escreveu. Para as regras de segurança transversais, ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 5.

## 1. Princípios fundamentais

### 1.1 Princípio do menor privilégio

Todo usuário, serviço e integração recebe **apenas** o acesso mínimo necessário para exercer sua função:

- **Acesso técnico de infraestrutura** (banco de dados, deploy, variáveis de ambiente/secrets) **não é um papel de negócio da aplicação** — não deve existir como valor de `usuarios.papel`, nem ser usado para autenticação de usuário final em produção. É controlado separadamente, fora do sistema, com contas de infraestrutura próprias (idealmente com MFA e acesso temporário/auditado).
- **Gestor**: acesso gerencial amplo, mas não irrestrito. Não altera dados protegidos por regra de imutabilidade (seção 1.2) nem contorna auditoria.
- **Demais papéis** (Funcionário, Avaliador, Auditor): acesso limitado estritamente ao escopo da própria função, detalhado na seção 3.

### 1.2 Dados de identificação — imutabilidade (🔧 proposta, condicional a D06)

O projeto de referência usado como base estrutural trava `cpf` e `nome` do paciente por regra de negócio própria daquele domínio. Aqui, **quais campos de identificação da pessoa atendida precisam da mesma proteção ainda depende da definição dos campos de cadastro (❓ D06)**. A recomendação de princípio, independente da lista final de campos, é:

> Uma vez que D06 definir os campos de identificação primária da pessoa (ex.: nome completo, documento, se coletado), qualquer alteração posterior desses campos específicos deve seguir um processo formal de **correção auditada** (novo registro com justificativa, vinculado ao original), nunca um `UPDATE` direto — garantido no nível do banco (trigger), não apenas na aplicação.

Este documento não define hoje quais campos entram nessa regra, porque isso seria assumir o resultado de D06 antes de o instituto responder.

### 1.3 Sobre dados financeiros

Este projeto **não envolve cobrança, pagamento ou monetização de serviço** (ver `REQUISITOS.md`, seção 7) — os serviços do instituto são gratuitos. Não existe, portanto, uma regra de "pagamentos append-only" nesta versão. Caso o instituto venha a registrar doações ou outro fluxo financeiro no futuro, recomenda-se aplicar o mesmo princípio de registro somente-inserção usado na auditoria (seção 4 de `BANCO_DADOS.md`) — mas isso é uma extensão futura, não parte do escopo atual.

## 2. Elegibilidade

Como os recursos do instituto são limitados e os serviços são gratuitos, o sistema precisa **apoiar, não substituir**, a decisão de quem recebe o serviço, de forma auditável — nunca baseada em impressão subjetiva não registrada ("parece precisar").

Estados conceituais:

```text
PENDENTE → EM_AVALIACAO → { ELEGIVEL | NAO_ELEGIVEL | NECESSITA_REVISAO }
```

Toda decisão relevante registra: responsável, data, critérios usados e justificativa quando aplicável.

**Regra explícita:** o sistema pode organizar dados, verificar critérios objetivos e sinalizar inconsistências — mas **não inventa critério de elegibilidade**. Os critérios são definidos formalmente pelo instituto. O modelo exato (elegibilidade geral vs. por serviço) é ❓ D01 e bloqueia o desenho definitivo desta parte do banco.

## 3. Controle de acesso (RBAC)

| Recurso | Administrador | Gestor | Funcionário | Avaliador¹ | Auditor |
|---|---|---|---|---|---|
| Cadastro de pessoas | Leitura | Leitura | Leitura/Escrita | Leitura | Leitura |
| Cadastro de funcionários/papéis | Leitura/Escrita | Leitura | — | — | — |
| Catálogo de serviços | Leitura/Escrita | Leitura | Leitura | Leitura | — |
| Solicitação de serviço | Leitura | Leitura | Leitura/Escrita | Leitura | Leitura |
| Avaliação de elegibilidade | Leitura | Leitura | Leitura² | Leitura/Escrita | Leitura |
| Agendamento | Leitura | Leitura | Leitura/Escrita | — | Leitura |
| Atendimento (registro) | Leitura | Leitura | Leitura/Escrita | — | Leitura |
| Auditoria/Logs | — | Leitura | — | — | Leitura |
| Configuração do sistema | Leitura/Escrita | — | — | — | — |

¹ Papel só existe se D05 confirmar que a avaliação de elegibilidade é função separada da operação normal do funcionário. Se não existir, suas permissões vão para "Funcionário".
² Se não existir papel de Avaliador separado, Funcionário também tem escrita em elegibilidade.

Célula em branco significa **sem acesso**, não acesso implícito. Qualquer exceção precisa ser adicionada explicitamente a esta tabela antes de ser implementada no código.

## 4. Atendimento e histórico

O atendimento registra que o serviço foi efetivamente realizado. **O que exatamente é registrado é ❓ D04** — pode variar por tipo de serviço (ex.: um curso registra frequência, uma consulta registra encaminhamento), e essa variação pode significar uma estrutura de atendimento com campos extensíveis por tipo de serviço, não uma tabela única rígida.

> Diferente do projeto de referência, este sistema **não assume, por padrão, que vai registrar dados clínicos/prontuário**. Isso só se aplica se um dos serviços oferecidos for da área da saúde — ainda não confirmado (ver `SDP_DOCUMENTACAO_PROJETO.md`, seção 1.4). Não modelar campos de histórico de saúde antes dessa confirmação.

Uma vez coletado qualquer dado de acompanhamento, ele deve ser **permanente e persistente**: não pode se perder se o funcionário/profissional responsável sair do instituto ou a pessoa passe a ser atendida por outro profissional — a informação pertence ao vínculo pessoa–serviço, não ao profissional individual. Alterações são sempre auditadas.

## 5. Confirmação e cancelamento de agendamento

Diferente do projeto de referência (onde o paciente podia confirmar diretamente), aqui **a pessoa atendida não acessa o sistema** — confirmação, cancelamento e reagendamento são sempre registrados pelo Funcionário em nome da pessoa. Isso faz parte do fluxo de agendamento desde a primeira sprint em que ele é construído (ver roadmap em `SDP_DOCUMENTACAO_PROJETO.md`, seção 8), não é funcionalidade de fase futura.

## 6. Como este documento deve ser usado

- Toda nova funcionalidade entra no backlog já referenciando qual regra desta lista ela precisa respeitar.
- Toda revisão de código (Pull Request) verifica: a regra foi seguida? Se não, o PR não é aprovado — mesmo que o código "funcione".
- Alterações neste documento exigem discussão em equipe e registro do motivo.
- Nenhuma seção marcada ❓ neste documento deve ser tratada como definitiva até a decisão correspondente em `SDP_DECISOES_PENDENTES.md` ser fechada.