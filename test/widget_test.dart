import 'package:digitalyx_exhibitor/data/local_store.dart';
import 'package:digitalyx_exhibitor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login page opens the dashboard in demo mode', (tester) async {
    await _enterDemoSession(tester);

    expect(find.text('LOGIN'), findsNothing);
    expect(find.text('Bonjour, exposant 👋'), findsOneWidget);
    expect(find.text('GreenTech Expo'), findsOneWidget);
    expect(find.text('Forfait Gratuit'), findsOneWidget);
    expect(
      find.text('Mode hors ligne · données enregistrées sur l’appareil'),
      findsOneWidget,
    );
  });

  testWidgets('captures and stores a qualified lead', (tester) async {
    final store = _FakeStore();
    await _enterDemoSession(tester, store: store);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Visiteurs'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un visiteur'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom complet *'),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail *'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Entreprise'),
      'Analytical Engines',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone *'),
      '+33123456789',
    );
    expect(find.text('Enregistrer et suivant'), findsOneWidget);
    await tester.tap(find.text('Enregistrer et suivant'));
    await tester.pumpAndSettle();

    expect(store.leads, hasLength(1));
    expect(store.leads.single.name, 'Ada Lovelace');
    expect(store.leads.single.email, 'ada@example.com');
    expect(store.leads.single.company, 'Analytical Engines');
  });

  testWidgets('searches the exhibitor directory locally', (tester) async {
    await _enterDemoSession(tester);

    await tester.tap(find.text('Annuaire').first);
    await tester.pumpAndSettle();
    expect(find.text('ÉcoNova Solutions'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Entreprise ou secteur'),
      'Mobilité',
    );
    await tester.pumpAndSettle();

    expect(find.text('Mobilité Verte'), findsOneWidget);
    expect(find.text('ÉcoNova Solutions'), findsNothing);
  });

  testWidgets('shows the branded login form before application pages', (
    tester,
  ) async {
    await tester.pumpWidget(DigitalyxApp(store: _FakeStore()));
    await tester.pumpAndSettle();

    expect(find.text('Digitalyx'), findsOneWidget);
    expect(find.text('Exhibitor'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Forfait Gratuit'), findsNothing);

    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();
    expect(find.text('Ce champ est obligatoire'), findsNWidgets(2));
  });

  testWidgets('login email field provides @ and @gmail.com buttons', (
    tester,
  ) async {
    await tester.pumpWidget(DigitalyxApp(store: _FakeStore()));
    await tester.pumpAndSettle();

    final loginEmail = find.widgetWithText(TextFormField, 'E-mail');
    await tester.enterText(loginEmail, 'demo');
    await tester.tap(find.byTooltip('Insérer @'));
    expect(tester.widget<TextFormField>(loginEmail).controller!.text, 'demo@');
    await tester.enterText(loginEmail, 'demo');
    await tester.tap(find.text('@gmail.com').first);
    expect(
      tester.widget<TextFormField>(loginEmail).controller!.text,
      'demo@gmail.com',
    );
  });

  testWidgets('registration submits trimmed data and returns to login', (
    tester,
  ) async {
    RegistrationData? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLogin: (_, _) async => false,
          onCreateAccount: (registration) async {
            submitted = registration;
            return const {'C_ID': '42'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('Inscription exposant'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom de l’entreprise ou du client'),
      '  Ada Lovelace  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      '  ada@example.com  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      ' +33123456789 ',
    );
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(submitted?.fullName, 'Ada Lovelace');
    expect(submitted?.email, 'ada@example.com');
    expect(submitted?.phone, '+33123456789');
    expect(find.text('WELCOME, ADA LOVELACE!'), findsOneWidget);

    await tester.tap(find.text('COMMENCER'));
    await tester.pumpAndSettle();
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(
      find.text(
        'Compte créé. Consultez votre e-mail pour recevoir le mot de passe temporaire.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('registration validates required fields, email, and phone', (
    tester,
  ) async {
    var createAccountCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          onLogin: (_, _) async => false,
          onCreateAccount: (_) async {
            createAccountCalled = true;
            return const {};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire'), findsNWidgets(2));
    expect(find.text('Champ obligatoire'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom de l’entreprise ou du client'),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'adresse-invalide',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '123',
    );
    await tester.ensureVisible(find.text('Continuer'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail invalide'), findsOneWidget);
    expect(find.text('Numéro de téléphone invalide'), findsOneWidget);
    expect(find.text('Inscription exposant'), findsOneWidget);
    expect(createAccountCalled, isFalse);
  });
}

Future<void> _enterDemoSession(
  WidgetTester tester, {
  ExhibitorStore? store,
}) async {
  await tester.pumpWidget(DigitalyxApp(store: store ?? _FakeStore()));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-mail'),
    'demo@digitalyx.test',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'demo-password',
  );
  await tester.tap(find.text('LOGIN'));
  await tester.pumpAndSettle();
}

class _FakeStore implements ExhibitorStore {
  final List<EventItem> events = [
    const EventItem(
      id: 1,
      name: 'GreenTech Expo',
      city: 'Paris',
      startDate: '2026-11-18',
      endDate: '2026-11-20',
      stand: 'B24',
    ),
  ];
  final List<LeadItem> leads = [];
  final List<AgentItem> agents = [];

  @override
  Future<List<EventItem>> getEvents() async => events;

  @override
  Future<List<LeadItem>> getLeads() async => leads;

  @override
  Future<List<AgentItem>> getAgents() async => agents;

  @override
  Future<AgentItem?> getAgentByEmail(String email) async {
    for (final agent in agents) {
      if (agent.email.toLowerCase() == email.toLowerCase()) return agent;
    }
    return null;
  }

  @override
  Future<void> addAgent({
    required String name,
    required String email,
    required String password,
    required int eventId,
  }) async {
    agents.add(
      AgentItem(
        id: agents.length + 1,
        name: name,
        email: email,
        password: password,
        eventId: eventId,
      ),
    );
  }

  @override
  Future<void> updateAgent({
    required int id,
    required String name,
    required String email,
    required String password,
    required int eventId,
  }) async {
    final index = agents.indexWhere((agent) => agent.id == id);
    if (index < 0) return;
    agents[index] = AgentItem(
      id: id,
      name: name,
      email: email,
      password: password,
      eventId: eventId,
    );
  }

  @override
  Future<void> deleteAgent(int id) async {
    agents.removeWhere((agent) => agent.id == id);
  }

  @override
  Future<EventItem> addEvent({
    required String name,
    required String city,
    required String startDate,
    required String endDate,
    required String stand,
  }) async {
    final event = EventItem(
      id: events.length + 1,
      name: name,
      city: city,
      startDate: startDate,
      endDate: endDate,
      stand: stand,
    );
    events.add(event);
    return event;
  }

  @override
  Future<void> updateStand(int eventId, String stand) async {}

  @override
  Future<void> updateProgramme(int eventId, String programme) async {
    final index = events.indexWhere((event) => event.id == eventId);
    if (index < 0) return;
    final event = events[index];
    events[index] = EventItem(
      id: event.id,
      name: event.name,
      city: event.city,
      startDate: event.startDate,
      endDate: event.endDate,
      stand: event.stand,
      programme: programme,
    );
  }

  @override
  Future<void> addLead(LeadDraft draft) async {
    leads.add(
      LeadItem(
        id: leads.length + 1,
        eventId: draft.eventId,
        name: draft.name,
        company: draft.company,
        position: draft.position,
        owner: draft.owner,
        email: draft.email,
        phone: draft.phone,
        priority: draft.priority,
        tags: draft.tags.join(','),
        note: draft.note,
        createdAt: DateTime.now().toIso8601String(),
        synced: false,
      ),
    );
  }
}
