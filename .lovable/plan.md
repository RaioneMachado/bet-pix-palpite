# Bolão Brasil x Escócia

Plataforma de bolão online com pagamento PIX via Asaas. Sem cadastro de cliente — apenas apostas pagas. Painel admin oculto em `/admin`.

## Stack
- TanStack Start + Lovable Cloud (Supabase) + PostgreSQL
- Asaas API (PIX) via server functions
- Tailwind v4 + shadcn (design custom estilo bet, mais limpo)

## Páginas
- `/` — Landing: header com a imagem Brasil x Escócia, banner com data 24/06 19:00, countdown até 24/06 18:30, destaque "Ganhe até R$ 1.000", "Como funciona" (4 passos), formulário de aposta, modal de PIX (QR + copia-cola + status em tempo real), footer.
- `/regulamento` — Regulamento completo.
- `/auth` — Login admin (oculto, sem links).
- `/admin` — Dashboard protegido (role admin): totais, lista de apostas com busca/filtros, exportar CSV.

## Banco (migration)
- `bets`: id, name, whatsapp, score_brazil, score_scotland, value (default 20.00), payment_status (`pending|confirmed|expired|cancelled`), payment_id (asaas charge id), pix_qr_code, pix_copy_paste, pix_expires_at, paid_at, created_at, updated_at
- `user_roles` + enum `app_role` + `has_role()` SECURITY DEFINER (padrão Lovable)
- RLS: `bets` SELECT só admin, INSERT/UPDATE só via service_role (server functions). Sem acesso anônimo direto.

## Server functions (não-autenticadas, públicas controladas)
- `createBet({ name, whatsapp, score_brazil, score_scotland })` — valida horário (<24/06 18:30), insere bet com value=20.00 fixo, chama Asaas API criando customer + cobrança PIX R$20 com vencimento +30min, salva payment_id/qr/copy-paste, retorna dados do PIX. Nunca recebe valor do front.
- `getBetStatus({ betId })` — consulta status (com polling no front a cada 4s).
- `regeneratePix({ betId })` — se expirado/pendente, cria nova cobrança Asaas, marca antiga como `expired`, atualiza mesma row (sem duplicar bet).

## Server route público (webhook)
- `/api/public/asaas-webhook` — recebe POST do Asaas, valida token (header `asaas-access-token` vs `ASAAS_WEBHOOK_TOKEN`), busca cobrança pela API Asaas para confirmar valor=20.00 e status, atualiza bet → `confirmed` + `paid_at`. Idempotente (não confirma duas vezes).

## Server functions admin (requireSupabaseAuth + has_role admin)
- `listBets({ search, status, dateFrom, dateTo })`
- `getStats()` — totais
- `exportBetsCsv()`

## Secrets necessários
- `ASAAS_API_KEY` — chave produção/sandbox Asaas
- `ASAAS_WEBHOOK_TOKEN` — token de validação webhook
- `ASAAS_ENV` — `sandbox` ou `production` (define base URL)

## Admin inicial
Migration insere role `admin` para o usuário `raionemachado284@gmail.com` quando ele se cadastrar (trigger em `auth.users` que confere email e cria entry em `user_roles`). Usuário precisa se inscrever uma vez via `/auth` para criar a conta.

## Design
- Paleta: branco base, verde (#00A859 Brasil), amarelo (#FFCC29), azul (#0A3D91 Escócia).
- Tipografia: Sora (heading) + Inter (body).
- Cards arredondados 2xl, sombras suaves, gradientes verde→amarelo nos CTAs, bg azul-escuro no banner do jogo.
- Mobile-first, animações suaves (motion-safe transitions, fade/slide-in).
- Imagem anexada como hero central (Brasil x Escócia).

## Itens que precisam confirmação do usuário antes de prosseguir
1. **Asaas API Key** — preciso que você forneça via secret (vou pedir após o plano aprovado). Use sandbox primeiro?
2. **Webhook Asaas** — após deploy, você precisa configurar no painel Asaas a URL `https://<seu-dominio>/api/public/asaas-webhook` com o token que vamos gerar.
3. **Admin login**: o email `raionemachado284@gmail.com` precisará criar a senha acessando `/auth` (signup). Após signup, role admin é atribuída automaticamente.

Aprovar para eu começar?