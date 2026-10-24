# Med+

Aplicativo multiplataforma para organizar medicamentos e receber lembretes locais, com foco em uma experiência simples e acessível.

## Requisitos de desenvolvimento

- Flutter SDK e Dart;
- Android SDK para compilar e executar no Android;
- macOS com Xcode para compilar e executar no iOS.

O identificador do aplicativo é `com.kaihp.medmais`; o nome exibido no dispositivo é `Med+`.

## Executar

```bash
flutter pub get
flutter run
```

## Validar

```bash
flutter analyze
flutter test
```

## Escopo do MVP

- Cadastro de medicamentos e horários recorrentes;
- Notificações locais com ações para registrar a tomada ou adiar por 15 minutos;
- Histórico de tomadas;
- Funcionamento offline.

O projeto está em fase inicial; funcionalidades do MVP ainda serão implementadas.

## Organização do código

- `features/*/domain/`: modelos e regras de negócio sem dependência de plugins.
- `features/*/data/`: contratos de repositório e implementações SQLite.
- `core/notifications/`: contrato independente para permissões, lembretes e ações das notificações.
- `features/*/presentation/`: telas e controladores de estado.
- `core/database/`: abertura do banco local, esquema e conversão de datas.

Os dados de medicamentos, horários e histórico são mantidos em SQLite no dispositivo. Os horários de ocorrência são armazenados como timestamps UTC em microssegundos para que consultas por intervalo e ordenação não dependam do fuso ou da precisão textual.

As telas devem depender dos contratos de repositório e notificação, nunca do SQLite ou dos plugins diretamente. Controladores de tela usam `ChangeNotifier` com dependências recebidas no construtor; widgets observam o estado com `ListenableBuilder`. Isso mantém a camada de apresentação testável sem adicionar uma dependência de gerenciamento de estado.

As ações das notificações recebem o ID da ocorrência e o tipo de ação. A camada que inicializa o serviço deve conectá-las ao histórico e ao agendamento do adiamento, inclusive quando o app não estiver aberto.

## Notificações locais

`FlutterLocalMedicationNotificationService` usa notificações locais, fuso horário do aparelho e agendamento Android exato, incluindo modo de economia de energia. O Android requer permissão de notificações e acesso especial para alarmes exatos; o iOS requer autorização para alertas e sons. O `NotificationPermissionGate` deve ser conectado à raiz da navegação do app com o serviço e o callback do histórico antes de habilitar as funcionalidades de medicamentos.

As ações executadas com o app fechado são guardadas localmente e entregues ao callback quando o serviço for inicializado na próxima vez. O callback do app deve atualizar o histórico e efetivar o adiamento. O sistema operacional controla a exibição dos botões; eles podem aparecer apenas ao expandir a notificação. O serviço agenda ocorrências individuais; a geração e reposição das próximas ocorrências recorrentes será feita pela camada de agendamento do app.
