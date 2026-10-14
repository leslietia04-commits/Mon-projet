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
        matching: find.text('Prospects'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un prospect'));
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

  testWidgets('email fields provide @ and @gmail.com buttons', (tester) async {
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

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    final registrationEmail = find.widgetWithText(TextFormField, 'E-mail');
    await tester.enterText(registrationEmail, 'demo');
    await tester.tap(find.text('@gmail.com').last);
    expect(
      tester.widget<TextFormField>(registrationEmail).controller!.text,
      'demo@gmail.com',
    );
  });

  testWidgets('registration welcomes the user by their full name', (
    tester,
  ) async {
    await tester.pumpWidget(DigitalyxApp(store: _FakeStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('Inscription exposant'), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Prénom'), findsNothing);
    expect(find.text('Nom de famille'), findsNothing);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Entreprise'), findsOneWidget);
    expect(find.text('Poste'), findsOneWidget);
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    final confirmPasswordField = find.widgetWithText(
      TextFormField,
      'Confirmer le mot de passe',
    );
    final passwordField = find.widgetWithText(TextFormField, 'Mot de passe');
    final passwordTextField = find.descendant(
      of: passwordField,
      matching: find.byType(TextField),
    );
    final confirmPasswordTextField = find.descendant(
      of: confirmPasswordField,
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordTextField).obscureText, isTrue);
    expect(
      tester.widget<TextField>(confirmPasswordTextField).obscureText,
      isTrue,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), 'ada@example.com');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Analytical Engines',
    );
    await tester.enterText(find.byType(TextFormField).at(3), 'Ingénieure');
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro de téléphone'),
      '+33123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'MotDePasse123',
    );
    await tester.enterText(confirmPasswordField, 'MotDePasse123');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('WELCOME, ADA LOVELACE!'), findsOneWidget);
    final welcome = find.byType(WelcomePage);
    final gradientBackground = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: welcome,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).gradient
                      is LinearGradient,
            ),
          )
          .first,
    );
    final welcomeGradient =
        (gradientBackground.decoration as BoxDecoration).gradient!
            as LinearGradient;
    expect(welcomeGradient.colors, [
      Colors.white,
      const Color(0xFFF4F6FB),
      const Color(0xFFE6EEFC),
    ]);
    expect(
      find.descendant(of: welcome, matching: find.byType(CustomPaint)),
      findsNWidgets(2),
    );
    expect(
      find.text(
        'Bienvenue sur votre nouvelle plateforme exposant Digitalyx Exhibitor. Connectez-vous pour accéder à votre portail exclusif et gérer vos événements.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('COMMENCER'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
  });

  testWidgets('registration rejects a mismatched password confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(DigitalyxApp(store: _FakeStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'MotDePasse123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
      'Different123',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    expect(find.text('WELCOME, '), findsNothing);
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

  @override
  Future<List<EventItem>> getEvents() async => events;

  @override
  Future<List<LeadItem>> getLeads() async => leads;

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
