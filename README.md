<div>

# myStock

**Gestão de estoque gratuita e offline para micro e pequenas empresas**

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![SQLite](https://img.shields.io/badge/SQLite-Local-003B57?logo=sqlite)
![License](https://img.shields.io/badge/Licença-MIT-green)
![Status](https://img.shields.io/badge/Status-Em%20desenvolvimento-yellow)

</div>

---

## Sobre o projeto

O **myStock** é um aplicativo mobile gratuito e de código aberto desenvolvido para auxiliar micro e pequenos empresários no controle de estoque e vendas. Funciona **100% offline**, sem necessidade de conexão com a internet ou assinatura de planos.

O aplicativo permite cadastrar produtos com seus respectivos lotes, monitorar datas de validade, registrar movimentações, realizar vendas e receber **notificações locais** automáticas sobre vencimentos próximos.

> Projeto desenvolvido como Trabalho de Conclusão de Curso (TCC) no curso Técnico em Desenvolvimento de Sistemas — IFRS Campus Canoas.

---

## Funcionalidades

### Estoque
- Cadastro de produtos com nome, descrição, código de barras, unidade e categoria
- Controle de **lotes** por produto (número do lote, quantidade, preço de custo, datas de fabricação, validade e entrada)
- Status automático dos lotes: `ATIVO`, `VENCIDO`, `ESGOTADO`
- Atualização automática de lotes vencidos ao abrir o app
- Busca em tempo real via SQLite (`SELECT ... LIKE`)

### Notificações offline
- Alertas locais configuráveis por proximidade de validade dos lotes
- Usuário define: dias de antecedência, horário e intervalo de repetição
- Reagendamento automático após qualquer operação de CRUD
- Tipos: `VALIDADE_PROXIMA`, `PRODUTO_VENCIDO`, `ESTOQUE_BAIXO`

### Favoritos
- Marcar produtos como favoritos para acesso rápido

### Vendas
- Registro de vendas com itens, lotes, preço unitário e subtotal
- Resumo de total vendido e quantidade de itens

---

##  Arquitetura

O projeto segue o padrão **MVVM** (Model-View-ViewModel) com separação por features.

```
lib/
├── core/
│   ├── database/
│   │   └── db.dart                  # DatabaseHelper (SQLite singleton)
│   ├── notifications/
│   │   ├── notification_config.dart
│   │   ├── notification_repository.dart
│   │   ├── notification_scheduler.dart
│   │   └── notification_service.dart
│   └── theme/
│       └── app_colors.dart
│
├── features/
│   ├── crud/
│   │   ├── models/
│   │   │   ├── categoria.dart
│   │   │   ├── produto.dart
│   │   │   ├── lote.dart
│   │   │   └── notificacao.dart
│   │   ├── repositories/
│   │   │   ├── categoria_repository.dart
│   │   │   ├── produto_repository.dart
│   │   │   ├── lote_repository.dart
│   │   │   └── notificacao_repository.dart
│   │   ├── viewmodels/
│   │   │   ├── home_viewmodel.dart
│   │   │   ├── insert_viewmodel.dart
│   │   │   ├── update_viewmodel.dart
│   │   │   ├── delete_viewmodel.dart
│   │   │   └── notification_viewmodel.dart
│   │   └── views/
│   │       ├── home_page.dart        # Shell global (IndexedStack + BottomNav)
│   │       ├── insert_page.dart
│   │       ├── update_page.dart
│   │       ├── delete_page.dart
│   │       └── notification_page.dart
│   │
│   ├── favorites/
│   │   ├── viewmodels/favorite_viewmodel.dart
│   │   └── views/favorites_page.dart
│   │
│   └── sales/
│       ├── viewmodels/sale_viewmodel.dart
│       └── views/sales_page.dart
│
└── main/
    └── main.dart
```

---

## Banco de dados

O banco local utiliza **SQLite** via `sqflite`, compatível com Android.

```
┌─────────────┐       ┌──────────────────┐       ┌──────────────────────┐
│  categorias │◄──────│     produtos     │◄──────│    lotes_produto     │
│─────────────│       │──────────────────│       │──────────────────────│
│ id          │       │ id               │       │ id                   │
│ nome        │       │ nome             │       │ produto_id (FK)      │
│ criado_em   │       │ descricao        │       │ numero_lote          │
└─────────────┘       │ codigo_barras    │       │ quantidade           │
                      │ categoria_id (FK)│       │ preco_custo          │
                      │ ativo            │       │ data_fabricacao      │
                      │ unidade          │       │ data_validade        │
                      │ criado_em        │       │ data_entrada         │
                      └──────────────────┘       │ status               │
                                                 └──────────────────────┘
                                                          │
                      ┌──────────────────┐               │
                      │movimentacoes_    │◄──────────────┘
                      │estoque           │
                      │──────────────────│       ┌──────────────────────┐
                      │ lote_id (FK)     │       │       vendas         │
                      │ tipo             │       │──────────────────────│
                      │ quantidade       │       │ id                   │
                      │ observacao       │       │ valor_total          │
                      └──────────────────┘       │ criado_em            │
                                                 └──────────────────────┘
                      ┌──────────────────┐                │
                      │  produtos_       │       ┌────────▼─────────────┐
                      │  favoritos       │       │     venda_itens      │
                      │──────────────────│       │──────────────────────│
                      │ produto_id (FK)  │       │ venda_id (FK)        │
                      └──────────────────┘       │ produto_id (FK)      │
                                                 │ lote_id (FK)         │
                      ┌──────────────────┐       │ quantidade           │
                      │  notificacoes    │       │ preco_unitario       │
                      │──────────────────│       │ subtotal             │
                      │ tipo             │       └──────────────────────┘
                      │ produto_id (FK)  │
                      │ lote_id (FK)     │
                      │ mensagem         │
                      │ visualizada      │
                      └──────────────────┘
```

---

##  Como executar

### Pré-requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `>=3.0.0`
- Android Studio ou VS Code com extensões Flutter/Dart
- Dispositivo Android ou emulador

### Instalação

```bash
# Clone o repositório
git clone https://github.com/imortal1903/myStock.git
cd mystock

# Instale as dependências
flutter pub get

# Execute o app
flutter run
```

### Configuração Android (obrigatório para notificações)

Adicione ao `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<application>
  <!-- Reagenda notificações após reboot -->
  <receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    android:exported="false">
    <intent-filter>
      <action android:name="android.intent.action.BOOT_COMPLETED"/>
      <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
      <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
  </receiver>

  <receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
    android:exported="false"/>
</application>
```

---

## Dependências principais

| Pacote                        | Versão  | Uso                            |
|-------------------------------|---------|--------------------------------|
| `provider`                    | ^6.1.2  | Gerenciamento de estado (MVVM) |
| `sqflite`                     | ^2.3.3  | Banco de dados SQLite          |
| `path_provider`               | ^2.1.3  | Diretório do banco de dados    |
| `flutter_local_notifications` | ^17.2.4 | Notificações locais offline    |
| `timezone`                    | ^0.9.4  | Agendamento com fuso horário   |
| `shared_preferences`          | ^2.3.2  | Configurações de notificação   |
| `uuid`                        | ^4.4.0  | Geração de IDs únicos          |
| `path`                        | ^1.9.0  | Manipulação de caminhos        |

---

## Telas

| Tela             | Descrição                                                   |
|------------------|-------------------------------------------------------------|
| **Home**         | Lista de produtos com estoque total e validade mais próxima |
| **Inserir**      | Cadastro de produto (aba 1) e primeiro lote (aba 2)         |
| **Editar**       | Seleção de produto -> editar dados ou gerenciar lotes       |
| **Remover**      | Remoção de produto completo ou lotes individuais            |
| **Notificações** | Configuração de alertas: dias antes, horário e intervalo    |
| **Favoritos**    | Produtos marcados como favoritos                            |
| **Vendas**       | Registro e resumo de vendas                                 |

---

## Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas alterações (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

---

## Autor

Desenvolvido por **Brayan** como Trabalho de Conclusão de Curso no **IFRS Campus Canoas**

---

<div>
  <sub>myStock — gestão de estoque simples, gratuita e offline.</sub>
</div>