<div align="center">

# myStock

**Gestão de estoque e vendas gratuita para micro e pequenas empresas, que funciona offline**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![SQLite](https://img.shields.io/badge/SQLite-Local-003B57?logo=sqlite)
![Plataforma](https://img.shields.io/badge/Plataforma-Android-3DDC84?logo=android)
![Status](https://img.shields.io/badge/Status-Em%20desenvolvimento-yellow)

</div>

---

## Sobre o projeto

O **myStock** é um aplicativo mobile gratuito e de código aberto para auxiliar micro e pequenos empresários no controle de estoque e de vendas. Os dados ficam **no próprio aparelho** (SQLite) e todas as funções principais, incluindo as notificações, funcionam **sem internet** e sem assinatura de planos.

O app controla produtos e lotes com data de validade, registra vendas e perdas, estima por quanto tempo o estoque dura, sugere ações para produtos que precisam de atenção e gera relatórios em CSV ou PDF. Como recurso opcional, faz **backup no Google Drive** do próprio usuário (este é o único recurso que usa internet).

> Projeto desenvolvido como Trabalho de Conclusão de Curso (TCC) no curso Técnico em Desenvolvimento de Sistemas, no IFRS Campus Canoas.

---

## Funcionalidades

### Estoque
- Cadastro de produtos com nome, descrição, código de barras (digitado ou lido pela câmera), categoria, estoque mínimo e unidade (`un`, `cx`, `pct`, `kg`, `g`, `L`, `mL`)
- Quantidades **fracionadas** para unidades de peso e volume (ex.: 1,5 kg); unidades contáveis aceitam só números inteiros
- Controle de **lotes** por produto: número do lote, quantidade, preços de custo e de venda, datas de fabricação, validade e entrada
- Status dos lotes: `ATIVO`, `VENCIDO` , `ESGOTADO` e `DESATIVADO`, com atualização automática dos vencidos (a baixa é registrada como perda por vencimento)
- **Registro de perdas** por lote, com motivo (avaria, vencimento, roubo ou outro), separado das saídas por venda
- **Exclusão lógica** de produtos e de lotes: o item some das telas, mas o histórico de vendas e movimentações é preservado
- Busca por nome, descrição ou código de barras, com filtro por categoria
- Gestão de categorias

### Vendas
- Carrinho com seleção de lote, quantidade e preço editáveis
- Sugestão do **lote recomendado**, que pondera validade próxima e estoque baixo; o peso de cada fator é configurável
- Baixa de estoque e registro de movimentação na mesma transação
- **Registro de vendas** com código da venda, produtos, faturamento, lucro por produto e lucro total
- Busca por produto ou número da venda, e ordenação por mais recentes, mais antigas, maior faturamento ou maior lucro

### Análise e sugestões
- Dashboard com quantidade vendida, faturamento, perdas e para onde o estoque está indo, com comparação com o período anterior
- **Previsão de duração do estoque** por Média Móvel Simples: janela de 4 semanas, ampliada para 12 quando há poucas vendas recentes. Produtos com baixa movimentação não recebem previsão, para evitar projeções enganosas
- **Risco de vencimento** por produto: simula o consumo dos lotes pela ordem de validade e aponta quanto não deve ser vendido a tempo
- **Sugestões na Home**, em um único card: produtos com lote perto de vencer, com estoque abaixo do mínimo e com baixa saída

### Notificações locais
- Alertas de validade agendados no aparelho, configuráveis: dias de antecedência, horário e intervalo de repetição
- Notificações **agrupadas por produto**; tocar em uma delas abre direto a tela do produto
- Reagendamento automático após qualquer alteração em produtos ou lotes
- Central de notificações dentro do app

### Relatórios e exportação
- Exportação em **CSV** ou **PDF**, para salvar no aparelho ou compartilhar pela aba de compartilhamento do Android
- **Modelos prontos**: posição de estoque, validade e perdas, vendas por período, produtos mais e menos vendidos, reposição sugerida e movimentações de estoque
- Escolha livre do conteúdo: um checkbox para cada tabela e para cada informação dela, com período, janela de validade e cobertura de reposição configuráveis

### Backup em nuvem (opcional)
- Backup do banco de dados em uma pasta `myStock` no Google Drive do usuário (escopo restrito aos arquivos criados pelo app)
- Backup manual, restauração e **backup automático em segundo plano** (WorkManager), disparado também quando o app vai para segundo plano
- O envio é bloqueado, com aviso, quando não há conexão

### Configurações
- Tema claro, escuro ou do sistema
- Geração de dados de teste e restauração das configurações padrão

---

## Arquitetura

O projeto segue o padrão **MVVM** (Model-View-ViewModel), organizado por funcionalidade. Os ViewModels herdam de `BaseViewModel` (estado de carregamento/erro e `safeNotify`) e o estado é gerenciado com `provider`.

```
lib/
├── main.dart
├── core/
│   ├── backup/            # configuração, agendamento (WorkManager) e Google Drive
│   ├── database/          # db.dart (SQLite singleton) e gerador de dados de teste
│   ├── extensions/        # datas, quantidades e conversões numéricas
│   ├── notificacoes/      # serviço, agendador, repositório, config e navegação
│   ├── promocoes/         # serviço das sugestões da Home
│   ├── scanner/           # leitor de código de barras
│   ├── theme/             # paleta de cores e controle de tema
│   ├── validators/        # validadores de formulário
│   ├── viewmodels/        # BaseViewModel
│   └── widgets/           # componentes compartilhados (ex.: campo de busca)
│
└── features/
    ├── crud/              # produtos, lotes, categorias e notificações
    │   ├── models/        # produto, lote, categoria, movimentacao_estoque...
    │   ├── repositories/
    │   ├── viewmodels/    # home, insert, update, delete, detalhe do produto...
    │   └── views/         # home_page (shell), insert, update, delete, detalhe...
    │
    ├── venda/             # carrinho, vendas e registro de vendas
    │   ├── models/
    │   ├── repositories/
    │   ├── viewmodels/
    │   └── views/         # venda_page, configurações e registro de vendas
    │
    ├── analise/           # dashboard, previsão de estoque e risco de vencimento
    │   ├── services/      # previsao_estoque_service
    │   ├── viewmodels/
    │   └── views/
    │
    └── config/            # configurações, backup e exportação de relatórios
        ├── models/
        ├── repositories/
        ├── services/      # relatorio_service (CSV/PDF)
        ├── viewmodels/    # config, backup e exportar
        └── views/         # config_page e exportar_page
```

---

## Banco de dados

O banco local usa **SQLite** via `sqflite`.

## Como executar

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `>=3.0.0 <4.0.0`)
- Android Studio ou VS Code com as extensões Flutter/Dart
- Dispositivo Android ou emulador

### Instalação

```bash
# Clone o repositório
git clone https://github.com/imortal1903/myStock.git
cd myStock

# Instale as dependências
flutter pub get

# Execute o app
flutter run
```

### Configuração Android

O `AndroidManifest.xml` do projeto já traz a configuração. Os pontos principais são:

| Recurso | Necessário para |
|---|---|
| `POST_NOTIFICATIONS` | Exibir notificações (Android 13+); o app pede a permissão ao usuário |
| `SCHEDULE_EXACT_ALARM` | Agendar alertas de validade em horário exato |
| `RECEIVE_BOOT_COMPLETED` e receivers do `flutter_local_notifications` | Reagendar os alertas depois que o aparelho reinicia |
| `INTERNET` | Backup no Google Drive |
| `FOREGROUND_SERVICE` e `FOREGROUND_SERVICE_DATA_SYNC` | Backup automático em segundo plano |

Ao instalar uma versão nova sobre outra, confira se as notificações continuam permitidas nas configurações do Android.

### Backup no Google Drive (opcional)

O backup usa o Google Sign-In e precisa de credenciais próprias do projeto:

1. No [Google Cloud Console](https://console.cloud.google.com/), crie um projeto e ative a **Google Drive API**.
2. Configure a tela de consentimento OAuth.
3. Crie uma credencial **OAuth do tipo Android**, com o nome do pacote do app e o **SHA-1** da sua keystore (para debug, use `./gradlew signingReport` na pasta `android`).

Sem isso, o restante do app funciona normalmente; só o backup em nuvem fica indisponível.

---

## Dependências principais

| Pacote | Uso |
|---|---|
| `provider` | Gerenciamento de estado (MVVM) |
| `sqflite`, `path`, `path_provider` | Banco de dados SQLite local |
| `shared_preferences` | Preferências (tema, backup, lote recomendado) |
| `flutter_local_notifications`, `timezone`, `flutter_timezone` | Notificações locais agendadas |
| `mobile_scanner` | Leitura de código de barras |
| `workmanager` | Backup automático em segundo plano |
| `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth` | Backup no Google Drive |
| `csv`, `pdf` | Geração de relatórios |
| `file_picker`, `share_plus` | Salvar e compartilhar os relatórios |
| `uuid` | Geração de identificadores únicos |

As versões exatas estão no `pubspec.yaml`.

---

## Telas

| Tela | Descrição |
|---|---|
| **Home** | Lista de produtos com busca e filtro por categoria, atalhos de cadastro e o card de sugestões |
| **Detalhe do produto** | Estoque, preço médio, resumo e lista de lotes, com registro de perda por lote e acesso à análise |
| **Inserir** | Cadastro do produto (aba 1) e do primeiro lote (aba 2) |
| **Editar e Remover** | Edição de produtos e lotes e remoção lógica |
| **Vendas** | Busca de produtos, carrinho, lote recomendado e finalização |
| **Configurações de vendas** | Peso do lote recomendado e acesso ao registro de vendas |
| **Registro de vendas** | Histórico com faturamento e lucro, busca e ordenação |
| **Análise** | Indicadores do período e previsão de estoque por produto |
| **Notificações** | Central de alertas e configuração de dias, horário e intervalo |
| **Configurações** | Tema, backup em nuvem, exportação de relatórios e dados de teste |
| **Exportar relatório** | Escolha do modelo, das tabelas e das informações, do período e do formato |

---

## Limitações conhecidas

- **Lucro com custo atual.** O custo no momento da venda não é guardado, então o lucro e o valor perdido usam o preço de custo atual do lote.
- **Previsão sem sazonalidade.** A Média Móvel Simples não trata sazonalidade, que exigiria histórico de vários anos.
- **Somente Android.** As notificações exatas e o backup em segundo plano foram configurados e testados apenas para Android.

---

## Downloads

O **myStock** está disponível para Android em três versões, compiladas para diferentes arquiteturas de processadores. Acesse a página de releases para baixar o APK compatível com seu dispositivo.

### Versões para Android

| Arquitetura | Arquivo |
|---|---|
| ARM64-v8a (64 bits) | `app-arm64-v8a-release.apk` |
| Armeabi-v7a (32 bits) | `app-armeabi-v7a-release.apk` |
| x86_64 (64 bits) | `app-x86_64-release.apk` |

**[Baixar myStock para Android — Releases]https://github.com/imortal1903/myStock/releases/latest**

### Instalação

1. Acesse a página de releases.
2. Na seção **Assets**, baixe o APK correspondente à arquitetura do seu dispositivo.
3. Abra o arquivo baixado no Android.
4. Se solicitado, autorize a instalação de aplicativos dessa origem.

> **Nota:** a instalação é feita diretamente pelo arquivo APK. A compatibilidade depende da arquitetura do dispositivo e da versão do Android.

---

## Autor

Desenvolvido por **Brayan** como Trabalho de Conclusão de Curso no **IFRS Campus Canoas**.

---

<div align="center">
  <sub>myStock: gestão de estoque simples e gratuita, que funciona offline.</sub>
</div>