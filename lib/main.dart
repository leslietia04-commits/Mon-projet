import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:record/record.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'data/local_store.dart';
import 'data/digitalyx_api.dart';

void main() {
  // Sur le web, sqflite n'a pas de moteur natif : on passe par sqlite3 en WASM.
  if (kIsWeb) databaseFactory = databaseFactoryFfiWebNoWebWorker;
  runApp(DigitalyxApp(store: SqliteExhibitorStore(), api: DigitalyxApi()));
}

// Palette événementielle chaleureuse : violet profond et corail sur fond clair.
const _ink = Color(0xFF0F1E3D);
const _brand = Color(0xFF1F5FD1);
const _brandDeep = Color(0xFF123C8A);
const _brandBright = Color(0xFF3B82F6);
const _brandDark = Color(0xFF14336F);
const _brandTint = Color(0xFFE6EEFC);
const _brandTintStrong = Color(0xFFD3E0F7);
const _accent = Color(0xFFF27F69);
const _paper = Color(0xFFF8F7FB);
const _line = Color(0xFFE3E8F2);
const _muted = Color(0xFF68738C);
const _mutedSoft = Color(0xFF9AA4B8);

// Active ou désactive les appels d'authentification distants.
const _apiEnabled = true;

const _directory = [
  ExhibitorProfile(
    name: 'ÉcoNova Solutions',
    sector: 'Énergie renouvelable',
    stand: 'A12',
    description: 'Solutions solaires et gestion intelligente de l’énergie.',
    website: 'econova.example',
  ),
  ExhibitorProfile(
    name: 'Atelier Circulaire',
    sector: 'Économie circulaire',
    stand: 'C08',
    description: 'Réemploi de matériaux et conception responsable.',
    website: 'ateliercirculaire.example',
  ),
  ExhibitorProfile(
    name: 'Mobilité Verte',
    sector: 'Mobilité durable',
    stand: 'D31',
    description: 'Flottes électriques et solutions de mobilité bas carbone.',
    website: 'mobiliteverte.example',
  ),
  ExhibitorProfile(
    name: 'Bâtir Demain',
    sector: 'Construction durable',
    stand: 'B17',
    description: 'Matériaux biosourcés pour le bâtiment professionnel.',
    website: 'batirdemain.example',
  ),
];

class ExhibitorProfile {
  const ExhibitorProfile({
    required this.name,
    required this.sector,
    required this.stand,
    required this.description,
    required this.website,
  });

  final String name;
  final String sector;
  final String stand;
  final String description;
  final String website;
}

class DigitalyxApp extends StatefulWidget {
  const DigitalyxApp({super.key, required this.store, this.api});
  final ExhibitorStore store;
  final DigitalyxApi? api;

  @override
  State<DigitalyxApp> createState() => _DigitalyxAppState();
}

class _DigitalyxAppState extends State<DigitalyxApp> {
  int _tab = 0;
  bool _hasDemoSession = false;
  late final DigitalyxApi _api = widget.api ?? DigitalyxApi();
  String _username = '';
  String _accountName = '';
  AgentItem? _activeAgent;
  List<AgentItem> _agents = [];
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late Future<void> _loading;
  Timer? _splashTimer;
  bool _showSplash = true;
  List<EventItem> _events = [];
  List<LeadItem> _leads = [];

  @override
  void initState() {
    super.initState();
    _loading = _refresh();
    _splashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final values = await Future.wait([
      widget.store.getEvents(),
      widget.store.getLeads(),
      widget.store.getAgents(),
    ]);
    if (!mounted) return;
    setState(() {
      _events = values[0] as List<EventItem>;
      _leads = values[1] as List<LeadItem>;
      _agents = values[2] as List<AgentItem>;
    });
  }

  Future<void> _saveLead(LeadDraft draft) async {
    await widget.store.addLead(draft);
    await _refresh();
  }

  Future<List<LeadItem>> _saveLeadAndGetLeads(LeadDraft draft) async {
    await _saveLead(draft);
    return List<LeadItem>.of(_leads);
  }

  Future<bool> _login(String username, String password) async {
    final displayName = _apiEnabled
        ? (await _api.login(email: username, password: password)).displayName
        : username.trim().split('@').first;
    setState(() {
      _username = username;
      _accountName = displayName.isEmpty ? 'Exposant' : displayName;
      _activeAgent = null;
      _hasDemoSession = true;
      _tab = 0;
    });
    return true;
  }

  Future<Map<String, dynamic>> _registerAccount(
    RegistrationData registration,
  ) async {
    if (!_apiEnabled) return {'status': 'LOCAL_DEMO'};
    return _api.createAccount(
      name: registration.fullName,
      email: registration.email,
      contact: registration.phone,
    );
  }

  Future<void> _createAgent({
    required String name,
    required String email,
    required String password,
    required int eventId,
  }) async {
    await widget.store.addAgent(
      name: name,
      email: email,
      password: password,
      eventId: eventId,
    );
    await _refresh();
  }

  Future<void> _updateAgent({
    required int id,
    required String name,
    required String email,
    required String password,
    required int eventId,
  }) async {
    await widget.store.updateAgent(
      id: id,
      name: name,
      email: email,
      password: password,
      eventId: eventId,
    );
    await _refresh();
  }

  Future<void> _deleteAgent(int id) async {
    await widget.store.deleteAgent(id);
    await _refresh();
  }

  Future<void> _createEvent({
    required String name,
    required String city,
    required String startDate,
    required String endDate,
    required String stand,
  }) async {
    await widget.store.addEvent(
      name: name,
      city: city,
      startDate: startDate,
      endDate: endDate,
      stand: stand,
    );
    await _refresh();
  }

  Future<void> _joinEvent(EventItem event, String stand) async {
    await widget.store.updateStand(event.id, stand);
    await _refresh();
  }

  Future<void> _openNewEventForm(BuildContext context) async {
    final result = await showModalBottomSheet<_NewEventData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (_) => const _EventFormSheet(),
    );
    if (result == null || !mounted) return;

    EventItem? duplicate;
    for (final event in _events) {
      if (_normalize(event.name) == _normalize(result.name) &&
          _normalize(event.city) == _normalize(result.city) &&
          event.startDate == result.startDate &&
          event.endDate == result.endDate) {
        duplicate = event;
        break;
      }
    }

    if (duplicate != null) {
      await _joinEvent(duplicate, result.stand);
      if (mounted) setState(() => _tab = 3);
      _showMessage('Stand mis à jour sur cet appareil.');
      return;
    }

    await _createEvent(
      name: result.name,
      city: result.city,
      startDate: result.startDate,
      endDate: result.endDate,
      stand: result.stand,
    );
    if (mounted) {
      setState(() => _tab = 3);
      _showMessage('Événement créé localement.');
    }
  }

  Future<void> _updateEventProgramme(int eventId, String programme) async {
    await widget.store.updateProgramme(eventId, programme);
    await _refresh();
  }

  Future<void> _openVisitorsForPriority(String priority) async {
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => EventVisitorsPage(
          events: _events,
          leads: _leads,
          selectedEventId: null,
          initialPriority: priority,
          onSaveLead: _saveLeadAndGetLeads,
        ),
      ),
    );
  }

  Future<void> _openVisitorsForPosition(String positionCode) async {
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => EventVisitorsPage(
          events: _events,
          leads: _leads,
          selectedEventId: null,
          initialPositionFilter: _executivePositionFilter(positionCode),
          onSaveLead: _saveLeadAndGetLeads,
        ),
      ),
    );
  }

  Future<void> _openEventVisitors(EventItem event) async {
    await _navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => EventVisitorsPage(
          events: _events,
          leads: _leads,
          selectedEventId: event.id,
          onSaveLead: _saveLeadAndGetLeads,
        ),
      ),
    );
  }

  Future<void> _openCapture({bool scan = false}) async {
    if (_events.isEmpty) {
      _showMessage('Ajoute d’abord un événement pour enregistrer un visiteur.');
      setState(() => _tab = 3);
      return;
    }
    final saved = await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => CapturePage(
          event: _events.first,
          onSave: _saveLead,
          initialScan: scan,
        ),
      ),
    );
    if (saved == true && mounted) {
      _showMessage(
        'Visiteur enregistré sur cet appareil. Aucune donnée envoyée.',
      );
    }
  }

  void _showMessage(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'Digitalyx Exhibitor',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brand,
        ).copyWith(primary: _brand),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: _mutedSoft),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _brand, width: 1.5),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (_showSplash) return const SplashScreen();
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 44,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text('Impossible de charger les données locales.'),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _loading = _refresh()),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: _brand)),
            );
          }
          if (!_hasDemoSession) {
            return LoginPage(
              onLogin: _login,
              onCreateAccount: _registerAccount,
            );
          }
          if (_activeAgent case final agent?) return _buildAgentHome(agent);
          return _buildShell(context);
        },
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    final eventsPage = EventsPage(
      events: _events,
      leads: _leads,
      onSaveLead: _saveLeadAndGetLeads,
      onOpenEvent: _openEventVisitors,
    );
    final pages = [
      HomePage(
        events: _events,
        leads: _leads,
        userName: _accountName,
        onCapture: _openCapture,
        onEvents: () => setState(() => _tab = 3),
        onLeads: () => _openVisitorsForPriority('Tout'),
        onProfile: () => setState(() => _tab = 4),
        onChangePassword: () => _showChangePasswordDialog(
          context,
          _showMessage,
        ),
        onSaveProgramme: _updateEventProgramme,
        onPriority: _openVisitorsForPriority,
        onExecutivePosition: _openVisitorsForPosition,
        onOpenEvent: _openEventVisitors,
      ),
      LeadsPage(leads: _leads, events: _events, onCapture: _openCapture),
      const DirectoryPage(),
      eventsPage,
      ProfilePage(
        onMessage: _showMessage,
        username: _username,
        events: _events,
        agents: _agents,
        onCreateAgent: _createAgent,
        onUpdateAgent: _updateAgent,
        onDeleteAgent: _deleteAgent,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: pages),
      ),
      floatingActionButton: _tab == 0
          ? Builder(
              builder: (fabContext) => FloatingActionButton(
                tooltip: 'Ajouter un événement',
                onPressed: () => _openNewEventForm(fabContext),
                backgroundColor: _brandDark,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  Widget _buildAgentHome(AgentItem agent) {
    final event = _eventFor(_events, agent.eventId);
    final leads = _leads
        .where(
          (lead) =>
              lead.eventId == agent.eventId &&
              _normalize(lead.owner) == _normalize(agent.name),
        )
        .toList();
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace agent')),
        body: const Center(child: Text('L’événement associé est introuvable.')),
      );
    }
    return AgentHomePage(
      agent: agent,
      event: event,
      leads: leads,
      onCapture: () => _openAgentCapture(event, agent),
      onScan: () => _openAgentCapture(event, agent, scan: true),
      onLogout: () => setState(() {
        _hasDemoSession = false;
        _activeAgent = null;
      }),
    );
  }

  Future<void> _openAgentCapture(
    EventItem event,
    AgentItem agent, {
    bool scan = false,
  }) async {
    await _navigatorKey.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => CapturePage(
          event: event,
          initialOwner: agent.name,
          initialScan: scan,
          onSave: _saveLead,
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

String _networkErrorMessage(Object error, String action) {
  final details = error.toString();
  if (kIsWeb && details.toLowerCase().contains('failed to fetch')) {
    return 'Le navigateur bloque la requête (CORS). Le serveur Digitalyx doit autoriser OPTIONS et POST depuis l’adresse de cette application.';
  }
  return '$action : $details';
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onLogin,
    required this.onCreateAccount,
  });
  final Future<bool> Function(String username, String password) onLogin;
  final Future<Map<String, dynamic>> Function(RegistrationData registration)
  onCreateAccount;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final email = _username.text.trim();
    setState(() => _isLoggingIn = true);
    try {
      final success = await widget.onLogin(email, _password.text);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse ou mot de passe incorrect.')),
        );
      }
    } on DigitalyxApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le serveur met trop de temps à répondre.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(_networkErrorMessage(error, 'Erreur de connexion')),
          ),
        );
        debugPrint('Erreur connexion Digitalyx: $error');
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _LoginBackground(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 47,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      const _BrandMark(),
                      const SizedBox(height: 17),
                      Text(
                        'Digitalyx',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: _brand,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Exhibitor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 5.5,
                          color: _brand,
                        ),
                      ),
                      const SizedBox(height: 23),
                      _buildFormCard(),
                      const SizedBox(height: 13),
                      const Text(
                        'L’EXCELLENCE À CHAQUE RENCONTRE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 2.1,
                          color: _mutedSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Connexion à votre espace Digitalyx',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 10),
                      ),
                      const Spacer(),
                      const Text(
                        'Réalisé par INOVYX TECH',
                        style: TextStyle(
                          color: _mutedSoft,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildFormCard() => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Connectez-vous à votre espace exposant',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            if (!_apiEnabled) ...[
              const SizedBox(height: 10),
              const Text(
                'Mode local temporaire : toute adresse et tout mot de passe valides ouvrent la démo. Aucun appel à l’API.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _brand, fontSize: 11),
              ),
            ],
            const SizedBox(height: 17),
            _loginField(
              controller: _username,
              label: 'E-mail',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            _loginField(
              controller: _password,
              label: 'Mot de passe',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                color: _muted,
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                ),
                tooltip: _obscurePassword
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 30,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (value) =>
                        setState(() => _rememberMe = value ?? false),
                    activeColor: _brand,
                    checkColor: Colors.white,
                    side: const BorderSide(color: _mutedSoft),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: const Text(
                    'Se souvenir de moi',
                    style: TextStyle(color: _ink, fontSize: 11),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: _brand,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                  ),
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 53,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brandBright, _brand, _brandDeep],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _brand.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _isLoggingIn ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoggingIn
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SE CONNECTER',
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 2.4,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 17),
              child: Row(
                children: [
                  Expanded(child: Divider(color: _line)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'NOUVEAU CHEZ DIGITALYX ?',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.2,
                        color: _muted,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: _line)),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _createAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: BorderSide(color: _brand.withValues(alpha: 0.7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Créer un compte',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _loginField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    obscureText: obscureText,
    onFieldSubmitted: onSubmitted,
    autocorrect: keyboardType != TextInputType.emailAddress,
    enableSuggestions: keyboardType != TextInputType.emailAddress,
    style: const TextStyle(color: _ink, fontSize: 14),
    cursorColor: _brand,
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Ce champ est obligatoire'
        : null,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted, fontSize: 13),
      prefixIcon: Icon(icon, color: _brand, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _brand.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFC64F36)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFC64F36), width: 1.5),
      ),
    ),
  );

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié ?'),
        content: const Text(
          'La documentation API fournie ne décrit pas de route de réinitialisation. Contactez l’administrateur Digitalyx pour réinitialiser votre mot de passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAccount() async {
    final registration = await Navigator.of(context).push<RegistrationData>(
      MaterialPageRoute(builder: (_) => const RegistrationPage()),
    );
    if (registration != null && mounted) {
      try {
        await widget.onCreateAccount(registration);
        if (!mounted) return;
        _username.text = registration.email;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WelcomePage(fullName: registration.fullName),
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _apiEnabled
                  ? 'Compte créé. Consultez votre e-mail pour recevoir le mot de passe temporaire.'
                  : 'Inscription de démonstration terminée. Aucun compte n’a été créé sur le serveur.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } on DigitalyxApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      } on TimeoutException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le serveur met trop de temps à répondre.'),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 10),
              content: Text(
                _networkErrorMessage(error, 'Erreur de création du compte'),
              ),
            ),
          );
          debugPrint('Erreur création compte Digitalyx: $error');
        }
      }
    }
  }
}

Widget _gmailSuffix(TextEditingController controller) => TextButton(
  onPressed: () => _insertEmailText(controller, '@gmail.com'),
  style: TextButton.styleFrom(
    foregroundColor: _brand,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    minimumSize: const Size(0, 40),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
  child: const Text(
    '@gmail.com',
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
  ),
);

void _insertEmailText(TextEditingController controller, String insertedText) {
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : controller.text.length;
  final end = selection.isValid ? selection.end : start;
  final text = controller.text.replaceRange(start, end, insertedText);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: start + insertedText.length),
  );
}

class RegistrationData {
  const RegistrationData({
    required this.fullName,
    required this.email,
    required this.phone,
  });

  final String fullName;
  final String email;
  final String phone;
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      RegistrationData(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: _brand,
      title: const Text(
        'Créer un compte',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: Stack(
      children: [
        Positioned(
          top: -100,
          right: -120,
          child: _AmbientGlow(size: 270, color: _brand.withValues(alpha: 0.1)),
        ),
        SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              children: [
                const _BrandMark(),
                const SizedBox(height: 18),
                const Text(
                  'Inscription exposant',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _apiEnabled
                      ? 'Digitalyx enverra vos identifiants temporaires à cette adresse e-mail.'
                      : 'Mode local temporaire : cette inscription sert uniquement à prévisualiser le parcours.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _registrationField(
                  controller: _fullName,
                  label: 'Nom de l’entreprise ou du client',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _email,
                  label: 'E-mail',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: _emailValidator,
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _phone,
                  label: 'Numéro de téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _phoneValidator,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 53,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_brandBright, _brand, _brandDeep],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Continuer',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _apiEnabled
                      ? 'Après création, consultez votre e-mail. Le mot de passe temporaire devra être changé à la première connexion.'
                      : 'Aucun e-mail ne sera envoyé tant que le mode local est activé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _registrationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffix,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    obscureText: obscureText,
    autocorrect: keyboardType != TextInputType.emailAddress,
    enableSuggestions: keyboardType != TextInputType.emailAddress,
    validator: validator ?? _requiredValidator,
    style: const TextStyle(color: _ink, fontSize: 14),
    cursorColor: _brand,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted, fontSize: 13),
      prefixIcon: Icon(icon, color: _brand, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _brand.withValues(alpha: 0.42)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFC64F36)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFC64F36), width: 1.4),
      ),
    ),
  );
}

String? _requiredValidator(String? value) =>
    value == null || value.trim().isEmpty ? 'Ce champ est obligatoire' : null;

String? _phoneValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Ce champ est obligatoire';
  }
  if (value.replaceAll(RegExp(r'\D'), '').length < 7) {
    return 'Numéro de téléphone invalide';
  }
  return null;
}

String? _passwordValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Ce champ est obligatoire';
  }
  if (value.length < 8) {
    return 'Le mot de passe doit contenir au moins 8 caractères';
  }
  return null;
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.fullName});
  final String fullName;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _LoginBackground(),
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _BrandSparkles())),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(25, 30, 25, 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _BrandMark(),
                const SizedBox(height: 18),
                const Text(
                  'Digitalyx',
                  style: TextStyle(
                    color: _brand,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Text(
                  'Exhibitor',
                  style: TextStyle(
                    color: _brand,
                    fontSize: 17,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 5.2,
                  ),
                ),
                const Spacer(),
                Text(
                  'WELCOME, ${fullName.trim().toUpperCase()}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _brand,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Bienvenue sur votre nouvelle plateforme exposant Digitalyx Exhibitor. Connectez-vous pour accéder à votre portail exclusif et gérer vos événements.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 16,
                    height: 1.7,
                    letterSpacing: 0.15,
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_brandBright, _brand, _brandDeep],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _brand.withValues(alpha: 0.3),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'COMMENCER',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Votre espace exposant vous attend',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, _paper, _brandTint],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      Positioned(
        top: -115,
        right: -105,
        child: _AmbientGlow(size: 330, color: _brand.withValues(alpha: 0.12)),
      ),
      Positioned(
        bottom: -155,
        left: -110,
        child: _AmbientGlow(
          size: 350,
          color: _brandBright.withValues(alpha: 0.12),
        ),
      ),
    ],
  );
}

class _BrandSparkles extends CustomPainter {
  const _BrandSparkles();

  @override
  void paint(Canvas canvas, Size size) {
    const points = [
      Offset(0.12, 0.16),
      Offset(0.82, 0.12),
      Offset(0.91, 0.29),
      Offset(0.24, 0.39),
      Offset(0.72, 0.52),
      Offset(0.09, 0.69),
      Offset(0.87, 0.82),
      Offset(0.38, 0.91),
    ];
    for (var index = 0; index < points.length; index++) {
      final point = Offset(
        points[index].dx * size.width,
        points[index].dy * size.height,
      );
      final radius = index.isEven ? 2.1 : 1.2;
      final glow = Paint()
        ..color = _brand.withValues(alpha: index.isEven ? 0.85 : 0.58)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(point, radius * 2.2, glow);
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = _brand.withValues(alpha: 0.92),
      );

      if (index.isEven) {
        final flare = Paint()
          ..color = _brand.withValues(alpha: 0.58)
          ..strokeWidth = 0.7;
        canvas.drawLine(point.translate(-5, 0), point.translate(5, 0), flare);
        canvas.drawLine(point.translate(0, -5), point.translate(0, 5), flare);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrandSparkles oldDelegate) => false;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 78,
    height: 78,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_brandBright, _brandDeep],
      ),
      boxShadow: [
        BoxShadow(
          color: _brand.withValues(alpha: 0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: const Center(
      child: Text(
        'D',
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 48,
          fontWeight: FontWeight.w700,
          height: 1,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(
          color: color,
          blurRadius: size * 0.48,
          spreadRadius: size * 0.18,
        ),
      ],
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _brandDark,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brandDark, _brandDeep, _brand],
              stops: [0, 0.58, 1],
            ),
          ),
        ),
        Positioned(
          top: -145,
          right: -115,
          child: _AmbientGlow(
            size: 330,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -120,
          child: _AmbientGlow(
            size: 360,
            color: _accent.withValues(alpha: 0.15),
          ),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: _entrance,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1).animate(_entrance),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: _BrandMark(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Digitalyx',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'EXHIBITOR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      width: 44,
                      height: 3,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Réalisé par INOVYX TECH',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.events,
    required this.leads,
    required this.userName,
    required this.onCapture,
    required this.onEvents,
    required this.onLeads,
    required this.onProfile,
    required this.onChangePassword,
    required this.onSaveProgramme,
    required this.onPriority,
    required this.onExecutivePosition,
    required this.onOpenEvent,
  });

  final List<EventItem> events;
  final List<LeadItem> leads;
  final String userName;
  final VoidCallback onCapture;
  final VoidCallback onEvents;
  final VoidCallback onLeads;
  final VoidCallback onProfile;
  final VoidCallback onChangePassword;
  final Future<void> Function(int eventId, String programme) onSaveProgramme;
  final ValueChanged<String> onPriority;
  final ValueChanged<String> onExecutivePosition;
  final ValueChanged<EventItem> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final hot = leads.where((lead) => lead.priority == 'Chaud').length;
    final event = events.isEmpty ? null : events.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIGITALYX',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                      color: _brand,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Hello $userName 👋',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(28),
              child: const CircleAvatar(
                backgroundColor: _brandTint,
                child: Icon(Icons.person_outline, color: _brand),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: _brandTint,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 17, color: _brand),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Mode hors ligne · données enregistrées sur l’appareil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: _brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onChangePassword,
          icon: const Icon(Icons.lock_reset_outlined),
          label: const Text('Modifier mon mot de passe'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _brand,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EC),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFF4D5CF)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFE46C3C),
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Forfait Gratuit',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Découvrir Pro',
                  style: TextStyle(
                    color: _brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.chevron_right, color: _brand, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (event != null)
          _EventHero(
            event: event,
            leadCount: leads.where((lead) => lead.eventId == event.id).length,
            onCapture: onCapture,
            onLeads: onLeads,
            onSaveProgramme: onSaveProgramme,
            onOpenEvent: () => onOpenEvent(event),
          )
        else
          _EmptyEventCard(onTap: onEvents),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                value: '${leads.length}',
                title: 'Visiteurs',
                icon: Icons.people_alt_outlined,
                tint: const Color(0xFFE8F2F5),
                onTap: onLeads,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                value: '${events.length}',
                title: '\u00C9v\u00E9nements',
                icon: Icons.event_available_outlined,
                tint: const Color(0xFFFFF0DB),
                onTap: onEvents,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _LeadBreakdown(leads: leads, onSelectPriority: onPriority),
        const SizedBox(height: 12),
        _PositionBreakdown(leads: leads, onSelectPosition: onExecutivePosition),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Derniers événements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            TextButton(onPressed: onEvents, child: const Text('Tout voir')),
          ],
        ),
        if (events.isEmpty)
          const _EmptyHint(
            icon: Icons.event_outlined,
            text: 'Aucun evenement enregistre pour le moment.',
          )
        else
          ...events
              .take(3)
              .map(
                (event) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _line),
                  ),
                  child: ListTile(
                    minVerticalPadding: 12,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    onTap: onEvents,
                    leading: const CircleAvatar(
                      backgroundColor: _brandTint,
                      child: Icon(Icons.event_outlined, color: _brand),
                    ),
                    title: Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    subtitle: Text(
                      '${event.city} - ${_shortDate(event.startDate)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right, color: _muted),
                  ),
                ),
              ),
      ],
    );
  }
}

class _LeadBreakdown extends StatelessWidget {
  const _LeadBreakdown({required this.leads, required this.onSelectPriority});
  final List<LeadItem> leads;
  final ValueChanged<String> onSelectPriority;

  @override
  Widget build(BuildContext context) {
    final hot = leads.where((lead) => lead.priority == 'Chaud').length;
    final warm = leads.where((lead) => lead.priority == 'Tiède').length;
    final info = leads.where((lead) => lead.priority == 'Info').length;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onSelectPriority('Chaud'),
              borderRadius: BorderRadius.circular(12),
              child: _StatValue(
                value: '$hot',
                label: 'Chaud',
                color: const Color(0xFFC64F36),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onSelectPriority('Tiède'),
              borderRadius: BorderRadius.circular(12),
              child: _StatValue(
                value: '$warm',
                label: 'Tiède',
                color: const Color(0xFFB77A1B),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => onSelectPriority('Info'),
              borderRadius: BorderRadius.circular(12),
              child: _StatValue(
                value: '$info',
                label: 'Info',
                color: const Color(0xFF517B99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionBreakdown extends StatelessWidget {
  const _PositionBreakdown({
    required this.leads,
    required this.onSelectPosition,
  });
  final List<LeadItem> leads;
  final ValueChanged<String> onSelectPosition;

  @override
  Widget build(BuildContext context) {
    int countFor(String code, List<String> titles) => leads
        .where((lead) => _matchesExecutivePosition(lead, code, titles))
        .length;

    Widget positionCard(String code, List<String> titles) => Expanded(
      child: InkWell(
        onTap: () => onSelectPosition(code),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: _StatValue(
            value: '${countFor(code, titles)}',
            label: code,
            color: _brand,
          ),
        ),
      ),
    );

    return Row(
      children: [
        positionCard('DM', const [
          'directeur marketing',
          'directrice marketing',
        ]),
        const SizedBox(width: 8),
        positionCard('DG', const ['directeur general', 'directrice generale']),
        const SizedBox(width: 8),
        positionCard('DC', const [
          'directeur commercial',
          'directrice commerciale',
        ]),
      ],
    );
  }
}

String _normalizeExecutivePosition(String value) => value
    .toLowerCase()
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('ë', 'e')
    .replaceAll('à', 'a')
    .replaceAll('â', 'a')
    .replaceAll('î', 'i')
    .replaceAll('ï', 'i')
    .replaceAll('ô', 'o')
    .replaceAll('ù', 'u')
    .replaceAll('û', 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _positionFilterDm = '@DM';
const _positionFilterDg = '@DG';
const _positionFilterDc = '@DC';

String _executivePositionFilter(String code) => switch (code) {
  'DM' => _positionFilterDm,
  'DG' => _positionFilterDg,
  'DC' => _positionFilterDc,
  _ => code,
};

String _executivePositionFilterLabel(String filter) => switch (filter) {
  _positionFilterDm => 'Direction marketing (DM)',
  _positionFilterDg => 'Direction générale (DG)',
  _positionFilterDc => 'Direction commerciale (DC)',
  _ => filter,
};

bool _matchesExecutivePosition(
  LeadItem lead,
  String code,
  List<String> titles,
) {
  final position = _normalizeExecutivePosition(lead.position);
  final codeMatch = RegExp('\\b${code.toLowerCase()}\\b').hasMatch(position);
  return codeMatch || titles.any(position.contains);
}

bool _matchesPositionFilter(LeadItem lead, String filter) {
  if (filter == _positionFilterDm) {
    return _matchesExecutivePosition(lead, 'DM', const [
      'directeur marketing',
      'directrice marketing',
    ]);
  }
  if (filter == _positionFilterDg) {
    return _matchesExecutivePosition(lead, 'DG', const [
      'directeur general',
      'directrice generale',
    ]);
  }
  if (filter == _positionFilterDc) {
    return _matchesExecutivePosition(lead, 'DC', const [
      'directeur commercial',
      'directrice commerciale',
    ]);
  }
  return lead.position.trim() == filter;
}

class _StatValue extends StatelessWidget {
  const _StatValue({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
    ],
  );
}

class _EventHero extends StatelessWidget {
  const _EventHero({
    required this.event,
    required this.leadCount,
    required this.onCapture,
    required this.onLeads,
    required this.onSaveProgramme,
    required this.onOpenEvent,
  });
  final EventItem event;
  final int leadCount;
  final VoidCallback onCapture;
  final VoidCallback onLeads;
  final Future<void> Function(int eventId, String programme) onSaveProgramme;
  final VoidCallback onOpenEvent;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onOpenEvent,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [_brandDeep, _brandBright],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_available, color: _accent, size: 17),
                const SizedBox(width: 7),
                Text(
                  event.isLocal ? 'MON ÉVÉNEMENT' : 'ÉVÉNEMENT',
                  style: const TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1.3,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.cloud_off, color: Colors.white70, size: 15),
                const SizedBox(width: 5),
                const Text(
                  'local',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              event.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(event.city, style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 13),
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  'Stand ${event.stand.isEmpty ? '—' : event.stand}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 15,
                  color: _accent,
                ),
                const SizedBox(width: 7),
                Text(
                  '${_shortDate(event.startDate)} — ${_shortDate(event.endDate)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  builder: (_) => _EventGuideSheet(
                    event: event,
                    leadCount: leadCount,
                    onCapture: onCapture,
                    onLeads: onLeads,
                    onSaveProgramme: onSaveProgramme,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.menu_book_outlined, size: 17),
                label: const Text('Ouvrir le guide du salon'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EventGuideSheet extends StatelessWidget {
  const _EventGuideSheet({
    required this.event,
    required this.leadCount,
    required this.onCapture,
    required this.onLeads,
    required this.onSaveProgramme,
  });

  final EventItem event;
  final int leadCount;
  final VoidCallback onCapture;
  final VoidCallback onLeads;
  final Future<void> Function(int eventId, String programme) onSaveProgramme;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GUIDE DE L’ÉVÉNEMENT',
            style: TextStyle(
              color: _brand,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            event.name,
            style: const TextStyle(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _GuideInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Dates',
            value:
                '${_shortDate(event.startDate)} — ${_shortDate(event.endDate)}',
          ),
          const SizedBox(height: 13),
          _GuideInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Ville',
            value: event.city,
          ),
          const SizedBox(height: 13),
          _GuideInfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Votre stand',
            value: event.stand.isEmpty ? 'À préciser' : event.stand,
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Programme du salon',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editProgramme(context),
                icon: Icon(
                  event.programme.isEmpty
                      ? Icons.add_rounded
                      : Icons.edit_outlined,
                  size: 16,
                ),
                label: Text(event.programme.isEmpty ? 'Ajouter' : 'Modifier'),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF4D5CF)),
            ),
            child: Text(
              event.programme.isEmpty
                  ? 'Ajoutez les rendez-vous, conférences ou temps forts à retenir.'
                  : event.programme,
              style: TextStyle(
                color: event.programme.isEmpty ? _muted : _ink,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _brandTint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: _brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vos contacts',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$leadCount visiteur${leadCount == 1 ? '' : 's'} enregistré${leadCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onCapture();
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scanner ou ajouter un contact'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onLeads();
              },
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Consulter mes visiteurs'),
            ),
          ),
          const Center(
            child: Text(
              'Vos données restent enregistrées sur cet appareil.',
              style: TextStyle(color: _mutedSoft, fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editProgramme(BuildContext context) async {
    final controller = TextEditingController(text: event.programme);
    final programme = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Programme du salon'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText:
                'Ex. 10 h — ouverture du stand\n14 h — démonstration produit',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (programme == null || !context.mounted) return;
    await onSaveProgramme(event.id, programme);
    if (context.mounted) Navigator.pop(context);
  }
}

class _GuideInfoRow extends StatelessWidget {
  const _GuideInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _brandTint,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _brand, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EmptyEventCard extends StatelessWidget {
  const _EmptyEventCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.event_available, color: _brand),
      title: const Text('Aucun événement sélectionné'),
      subtitle: const Text('Rejoignez ou créez un salon localement.'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.title,
    required this.icon,
    required this.tint,
    required this.onTap,
  });
  final String value;
  final String title;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: _brand),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _brand, size: 20),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class LeadsPage extends StatelessWidget {
  const LeadsPage({
    super.key,
    required this.leads,
    required this.events,
    required this.onCapture,
  });
  final List<LeadItem> leads;
  final List<EventItem> events;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Visiteurs',
        subtitle:
            '${leads.length} contact${leads.length == 1 ? '' : 's'} enregistré${leads.length == 1 ? '' : 's'}',
        action: IconButton.filledTonal(
          onPressed: onCapture,
          icon: const Icon(Icons.person_add_alt_1),
        ),
      ),
      if (leads.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: OutlinedButton.icon(
            onPressed: () => _copyLeadCsv(context, leads, events),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Copier l’export CSV'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              foregroundColor: _brand,
            ),
          ),
        ),
      Expanded(
        child: leads.isEmpty
            ? _EmptyHint(
                icon: Icons.person_search_outlined,
                text:
                    'Aucun visiteur pour le moment. Ajoutez votre premier contact.',
                action: FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter un visiteur'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  _LocalNotice(
                    count: leads.where((lead) => !lead.synced).length,
                  ),
                  const SizedBox(height: 12),
                  for (final lead in leads)
                    LeadCard(
                      lead: lead,
                      event: _eventFor(events, lead.eventId),
                    ),
                ],
              ),
      ),
    ],
  );
}

Future<void> _copyLeadCsv(
  BuildContext context,
  List<LeadItem> leads,
  List<EventItem> events,
) async {
  try {
    final rows = <List<String>>[
      [
        'Nom',
        'Entreprise',
        'Poste',
        'E-mail',
        'Téléphone',
        'Statut',
        'Notes',
        'Tags',
        'Commercial',
        'Événement',
        'Date',
      ],
      for (final lead in leads)
        [
          lead.name,
          lead.company,
          lead.position,
          lead.email,
          lead.phone,
          lead.priority,
          lead.note,
          lead.tags,
          lead.owner,
          _eventFor(events, lead.eventId)?.name ?? '',
          lead.createdAt,
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(';')).join('\r\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      _message(context, 'CSV copié. Collez-le dans Excel ou votre CRM.');
    }
  } catch (error) {
    if (context.mounted) {
      _message(context, 'Échec de la copie CSV : $error');
    }
  }
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final _search = TextEditingController();
  String? _sector;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectors = _directory.map((company) => company.sector).toSet().toList()
      ..sort();
    final query = _search.text.trim().toLowerCase();
    final matches = _directory.where((company) {
      final textMatch =
          query.isEmpty ||
          company.name.toLowerCase().contains(query) ||
          company.sector.toLowerCase().contains(query);
      return textMatch && (_sector == null || company.sector == _sector);
    }).toList();
    return Column(
      children: [
        const _PageHeader(
          title: 'Annuaire B2B',
          subtitle: 'Découvrez les exposants du salon',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Entreprise ou secteur',
            ),
          ),
        ),
        SizedBox(
          height: 45,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('Tous les secteurs'),
                selected: _sector == null,
                onSelected: (_) => setState(() => _sector = null),
              ),
              const SizedBox(width: 7),
              for (final sector in sectors) ...[
                ChoiceChip(
                  label: Text(sector),
                  selected: _sector == sector,
                  onSelected: (_) => setState(() => _sector = sector),
                ),
                const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: _PrototypeNote(
            text:
                'Profils de démonstration uniquement. L’annuaire officiel, privé par événement, nécessite une connexion serveur.',
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const _EmptyHint(
                  icon: Icons.search_off,
                  text: 'Aucune entreprise ne correspond à votre recherche.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _ExhibitorCard(
                    profile: matches[index],
                    onTap: () => _showCompany(context, matches[index]),
                  ),
                ),
        ),
      ],
    );
  }

  void _showCompany(BuildContext context, ExhibitorProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            _Tag(text: profile.sector),
            const SizedBox(height: 13),
            Text(profile.description, style: const TextStyle(color: _muted)),
            const SizedBox(height: 12),
            Text(
              'Stand ${profile.stand}  ·  ${profile.website}',
              style: const TextStyle(
                color: _brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExhibitorCard extends StatelessWidget {
  const _ExhibitorCard({required this.profile, required this.onTap});
  final ExhibitorProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: _line),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: _brandTint,
        child: Text(
          profile.name.substring(0, 1),
          style: const TextStyle(color: _brand, fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(
        profile.name,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${profile.sector} · Stand ${profile.stand}',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

class LeadCard extends StatelessWidget {
  const LeadCard({super.key, required this.lead, this.event});
  final LeadItem lead;
  final EventItem? event;

  @override
  Widget build(BuildContext context) {
    final color = switch (lead.priority) {
      'Chaud' => const Color(0xFFC64F36),
      'Tiède' => const Color(0xFFB77A1B),
      _ => const Color(0xFF517B99),
    };
    final initials = lead.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: _brandTint,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      [
                        if (lead.position.isNotEmpty) lead.position,
                        lead.company.isEmpty
                            ? (lead.email.isEmpty ? lead.phone : lead.email)
                            : lead.company,
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lead.priority,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (lead.tags.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: lead.tags
                  .split(',')
                  .where((tag) => tag.isNotEmpty)
                  .map((tag) => _Tag(text: tag))
                  .toList(),
            ),
          ],
          if (lead.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              lead.note,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
          if (lead.voiceNote case final voiceNote?) ...[
            const SizedBox(height: 8),
            VoiceNotePlayer(audio: voiceNote),
          ],
          if (event != null) ...[
            const SizedBox(height: 10),
            Text(
              '${event!.name} · ${_shortDateTime(lead.createdAt)}',
              style: const TextStyle(fontSize: 10, color: _mutedSoft),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            'Contact : ${lead.owner}',
            style: const TextStyle(fontSize: 10, color: _mutedSoft),
          ),
        ],
      ),
    );
  }
}

class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.audio});

  final Uint8List audio;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completionSubscription;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void didUpdateWidget(covariant VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.audio, widget.audio)) {
      unawaited(_player.stop());
      _playing = false;
    }
  }

  @override
  void dispose() {
    _completionSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    try {
      await _player.play(
        BytesSource(_voiceNoteWav(widget.audio), mimeType: 'audio/wav'),
      );
      if (mounted) setState(() => _playing = true);
    } catch (error) {
      if (mounted) {
        _message(context, 'Lecture de la note vocale impossible : $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _togglePlayback,
    icon: Icon(
      _playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
    ),
    label: Text(_playing ? 'Arrêter la note vocale' : 'Écouter la note vocale'),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );
}

Uint8List _voiceNoteWav(Uint8List pcm) {
  const sampleRate = 16000;
  const channels = 1;
  const bitsPerSample = 16;
  final bytesPerSecond = sampleRate * channels * bitsPerSample ~/ 8;
  final wav = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(wav);
  wav.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, 36 + pcm.length, Endian.little);
  wav.setRange(8, 12, ascii.encode('WAVE'));
  wav.setRange(12, 16, ascii.encode('fmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, bytesPerSecond, Endian.little);
  header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  wav.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(44, wav.length, pcm);
  return wav;
}

class EventsPage extends StatelessWidget {
  const EventsPage({
    super.key,
    required this.events,
    required this.leads,
    required this.onSaveLead,
    required this.onOpenEvent,
  });

  final List<EventItem> events;
  final List<LeadItem> leads;
  final Future<List<LeadItem>> Function(LeadDraft draft) onSaveLead;
  final ValueChanged<EventItem> onOpenEvent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _PageHeader(
        title: 'Événements',
        subtitle: 'Événements enregistrés et visiteurs capturés',
      ),
      Expanded(
        child: events.isEmpty
            ? const _EmptyHint(
                icon: Icons.event_note_outlined,
                text: 'Aucun événement enregistré pour le moment.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  for (final event in events)
                    _EventSummaryCard(
                      event: event,
                      leads: leads
                          .where((lead) => lead.eventId == event.id)
                          .toList(),
                      onTap: () => onOpenEvent(event),
                    ),
                ],
              ),
      ),
    ],
  );
}

class EventVisitorsPage extends StatefulWidget {
  const EventVisitorsPage({
    super.key,
    required this.events,
    required this.leads,
    required this.selectedEventId,
    this.initialPriority = 'Tout',
    this.initialPositionFilter,
    required this.onSaveLead,
  });

  final List<EventItem> events;
  final List<LeadItem> leads;
  final int? selectedEventId;
  final String initialPriority;
  final String? initialPositionFilter;
  final Future<List<LeadItem>> Function(LeadDraft draft) onSaveLead;

  @override
  State<EventVisitorsPage> createState() => _EventVisitorsPageState();
}

class _EventVisitorsPageState extends State<EventVisitorsPage> {
  static const _allPositions = 'Toutes les fonctions';

  late int? _selectedEventId = widget.selectedEventId;
  late List<LeadItem> _leads = List<LeadItem>.of(widget.leads);
  late String _selectedPriority = widget.initialPriority;
  late String _selectedPosition = widget.initialPositionFilter ?? _allPositions;
  String _query = '';

  Future<void> _addVisitor() async {
    EventItem? event = _selectedEventId == null
        ? null
        : _eventFor(widget.events, _selectedEventId!);
    if (event == null && widget.events.length == 1) {
      event = widget.events.first;
    } else if (event == null && widget.events.isNotEmpty) {
      event = await showModalBottomSheet<EventItem>(
        context: context,
        backgroundColor: _paper,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Choisir un événement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              for (final item in widget.events)
                ListTile(
                  leading: const Icon(Icons.event_outlined, color: _brand),
                  title: Text(item.name),
                  subtitle: Text(item.city),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      );
    }
    if (event == null || !mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CapturePage(
          event: event!,
          onSave: (draft) async {
            final updatedLeads = await widget.onSaveLead(draft);
            if (mounted) setState(() => _leads = updatedLeads);
          },
          initialScan: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availablePositions =
        _leads
            .where(
              (lead) =>
                  (_selectedEventId == null ||
                      lead.eventId == _selectedEventId) &&
                  lead.position.trim().isNotEmpty,
            )
            .map((lead) => lead.position.trim())
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final visibleLeads = _leads.where((lead) {
      final matchesEvent =
          _selectedEventId == null || lead.eventId == _selectedEventId;
      final matchesPriority =
          _selectedPriority == 'Tout' || lead.priority == _selectedPriority;
      final matchesPosition =
          _selectedPosition == _allPositions ||
          _matchesPositionFilter(lead, _selectedPosition);
      final query = _normalize(_query);
      final matchesQuery =
          query.isEmpty ||
          _normalize(
            '${lead.name} ${lead.company} ${lead.email} ${lead.phone} ${lead.position}',
          ).contains(query);
      return matchesEvent && matchesPriority && matchesPosition && matchesQuery;
    }).toList();
    final selectedEvent = _eventFor(widget.events, _selectedEventId ?? -1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedEvent?.name ??
              (_selectedPriority != 'Tout'
                  ? 'Visiteurs $_selectedPriority'
                  : _selectedPosition == _allPositions
                  ? 'Tous les visiteurs'
                  : 'Visiteurs · ${_executivePositionFilterLabel(_selectedPosition)}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVisitor,
        tooltip: 'Ajouter un visiteur',
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un visiteur',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<int?>(
                    value: _selectedEventId,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Icons.arrow_drop_down),
                    hint: Text(_selectedEventId == null ? 'Tout' : 'Événement'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tout'),
                      ),
                      for (final event in widget.events)
                        DropdownMenuItem<int?>(
                          value: event.id,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              event.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedEventId = value;
                      _selectedPosition = _allPositions;
                    }),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final priority in ['Tout', 'Chaud', 'Tiède', 'Info'])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(priority),
                      selected: _selectedPriority == priority,
                      onSelected: (_) =>
                          setState(() => _selectedPriority = priority),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.work_outline, size: 18, color: _muted),
                const SizedBox(width: 7),
                const Text('Poste', style: TextStyle(color: _muted)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value:
                        availablePositions.contains(_selectedPosition) ||
                            const {
                              _positionFilterDm,
                              _positionFilterDg,
                              _positionFilterDc,
                            }.contains(_selectedPosition)
                        ? _selectedPosition
                        : _allPositions,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(
                        value: _allPositions,
                        child: Text(_allPositions),
                      ),
                      for (final filter in const [
                        _positionFilterDm,
                        _positionFilterDg,
                        _positionFilterDc,
                      ])
                        DropdownMenuItem(
                          value: filter,
                          child: Text(_executivePositionFilterLabel(filter)),
                        ),
                      for (final position in availablePositions)
                        DropdownMenuItem(
                          value: position,
                          child: Text(
                            position,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _selectedPosition = value ?? _allPositions,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${visibleLeads.length} visiteur${visibleLeads.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: visibleLeads.isEmpty
                ? const _EmptyHint(
                    icon: Icons.person_search_outlined,
                    text: 'Aucun visiteur ne correspond à ces filtres.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    itemCount: visibleLeads.length,
                    itemBuilder: (context, index) {
                      final lead = visibleLeads[index];
                      return LeadCard(
                        lead: lead,
                        event: _eventFor(widget.events, lead.eventId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.event,
    required this.leads,
    required this.onTap,
  });

  final EventItem event;
  final List<LeadItem> leads;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hot = leads.where((lead) => lead.priority == 'Chaud').length;
    final warm = leads.where((lead) => lead.priority == 'Tiède').length;
    final info = leads.where((lead) => lead.priority == 'Info').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _brandTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.event_available, color: _brand),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _ink,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _mutedSoft),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  '${event.city} · ${_shortDate(event.startDate)} — ${_shortDate(event.endDate)}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stand ${event.stand.isEmpty ? 'à définir' : event.stand}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _EventCountBadge(
                        label: 'Visiteurs',
                        count: leads.length,
                        color: _brand,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _EventCountBadge(
                        label: 'Chaud',
                        count: hot,
                        color: const Color(0xFFC64F36),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _EventCountBadge(
                        label: 'Tiède',
                        count: warm,
                        color: const Color(0xFFB77A1B),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _EventCountBadge(
                        label: 'Info',
                        count: info,
                        color: const Color(0xFF517B99),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCountBadge extends StatelessWidget {
  const _EventCountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _NewEventData {
  const _NewEventData(
    this.name,
    this.city,
    this.startDate,
    this.endDate,
    this.stand,
  );
  final String name;
  final String city;
  final String startDate;
  final String endDate;
  final String stand;
}

class _EventFormSheet extends StatefulWidget {
  const _EventFormSheet();
  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _stand = TextEditingController();
  DateTimeRange? _dates;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _stand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      14,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 22,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Créer un événement',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Mode stand-alone · stocké sur cet appareil',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 17),
            TextFormField(
              controller: _name,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Nom du salon'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _city,
              validator: _required,
              decoration: const InputDecoration(labelText: 'Lieu'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 5),
                );
                if (range != null) setState(() => _dates = range);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                _dates == null
                    ? 'Choisir les dates du salon'
                    : '${_shortDate(_isoDate(_dates!.start))} — ${_shortDate(_isoDate(_dates!.end))}',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _stand,
              decoration: const InputDecoration(
                labelText: 'Numéro de stand (facultatif)',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate() || _dates == null) {
                    if (_dates == null) {
                      _message(context, 'Choisissez les dates du salon.');
                    }
                    return;
                  }
                  Navigator.pop(
                    context,
                    _NewEventData(
                      _name.text,
                      _city.text,
                      _isoDate(_dates!.start),
                      _isoDate(_dates!.end),
                      _stand.text,
                    ),
                  );
                },
                child: const Text('Créer localement'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.onMessage,
    required this.username,
    required this.events,
    required this.agents,
    required this.onCreateAgent,
    required this.onUpdateAgent,
    required this.onDeleteAgent,
  });
  final ValueChanged<String> onMessage;
  final String username;
  final List<EventItem> events;
  final List<AgentItem> agents;
  final Future<void> Function({
    required String name,
    required String email,
    required String password,
    required int eventId,
  })
  onCreateAgent;
  final Future<void> Function({
    required int id,
    required String name,
    required String email,
    required String password,
    required int eventId,
  })
  onUpdateAgent;
  final Future<void> Function(int id) onDeleteAgent;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 23, 20, 28),
    children: [
      const Text(
        'Mon espace',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const SizedBox(height: 5),
      const Text('Compte et accès exposant', style: TextStyle(color: _muted)),
      const SizedBox(height: 15),
      const _PlanStatus(),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _brandDark,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.person_outline, color: Colors.white),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Session de démonstration · compte non vérifié',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.cloud_off, color: Colors.white70, size: 18),
          ],
        ),
      ),
      const SizedBox(height: 13),
      FilledButton.icon(
        onPressed: events.isEmpty ? null : () => _manageAgents(context),
        icon: const Icon(Icons.badge_outlined),
        label: const Text('Mode Agent'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      if (agents.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          '${agents.length} agent${agents.length == 1 ? '' : 's'} ajouté${agents.length == 1 ? '' : 's'}',
          style: const TextStyle(color: _muted),
        ),
      ],
      if (events.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Créez d’abord un événement pour ajouter un agent.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: () => _accountDialog(context),
        icon: const Icon(Icons.mail_outline),
        label: const Text('Se connecter / créer un compte'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
      const SizedBox(height: 24),
      const Text(
        'ACTIVER MON ACCÈS',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
          color: _muted,
        ),
      ),
      const SizedBox(height: 10),
      _AccessCard(
        icon: Icons.workspace_premium_outlined,
        title: 'Passer à Pro annuel',
        subtitle: '12 mois · accès illimité aux événements',
        onTap: () => _showAnnualOffer(context),
      ),
      _AccessCard(
        icon: Icons.confirmation_number_outlined,
        title: 'Pass événement',
        subtitle: 'Accès ponctuel à un salon',
        onTap: () => _activationInfo(context),
      ),
      _AccessCard(
        icon: Icons.qr_code_2,
        title: 'Code organisateur',
        subtitle: 'Débloquer l’accès avec mon code',
        onTap: () => _codeDialog(context),
      ),
      const SizedBox(height: 12),
      const _PrototypeNote(
        text:
            'Offre Pro affichée à titre indicatif : souscription, tarif et date de validité nécessitent le service de compte et de paiement Digitalyx. Aucun achat ni accès n’est activé ici.',
      ),
    ],
  );

  Future<void> _manageAgents(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AgentManagementSheet(
        events: events,
        agents: agents,
        onCreateAgent: onCreateAgent,
        onUpdateAgent: onUpdateAgent,
        onDeleteAgent: onDeleteAgent,
      ),
    );
  }

  void _showAnnualOffer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Digitalyx Exhibitor Pro'),
        content: const Text(
          'Abonnement annuel · 12 mois d’accès à un nombre illimité de salons, dans l’espace de votre entreprise.\n\nLe prix et la souscription ne sont pas configurés dans ce prototype. Aucun paiement ne sera effectué.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onMessage(
                'Souscription annuelle indisponible : service de paiement non configuré.',
              );
            },
            child: const Text('Découvrir Pro annuel'),
          ),
        ],
      ),
    );
  }

  Future<void> _accountDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compte exposant'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Adresse e-mail'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onMessage(
                'Connexion indisponible hors ligne : aucun e-mail envoyé.',
              );
            },
            child: const Text('Recevoir un lien magique'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _codeDialog(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code organisateur'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Code d’activation'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && context.mounted) {
      _activationInfo(context);
    }
  }

  void _activationInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activation non disponible'),
        content: const Text(
          'Le pass événement est réservé au salon sélectionné et peut dépendre de la taille de l’équipe. Paiement, prix et validation du code nécessitent le service Digitalyx. Aucun achat ni accès n’a été activé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showChangePasswordDialog(
  BuildContext context,
  ValueChanged<String> onMessage,
) async {
  final formKey = GlobalKey<FormState>();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmation = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Modifier mon mot de passe'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saisissez votre code actuel, puis choisissez un nouveau mot de passe.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: currentPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Code actuel'),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
                validator: _passwordValidator,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le nouveau mot de passe',
                ),
                validator: (value) => value != newPassword.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, true);
            }
          },
          child: const Text('Continuer'),
        ),
      ],
    ),
  );
  currentPassword.dispose();
  newPassword.dispose();
  confirmation.dispose();
  if (accepted == true && context.mounted) {
    onMessage(
      'Demande non enregistrée : le mode local est actif et l’API ne fournit pas encore de route de changement de mot de passe.',
    );
  }
}

class _AgentManagementSheet extends StatefulWidget {
  const _AgentManagementSheet({
    required this.events,
    required this.agents,
    required this.onCreateAgent,
    required this.onUpdateAgent,
    required this.onDeleteAgent,
  });

  final List<EventItem> events;
  final List<AgentItem> agents;
  final Future<void> Function({
    required String name,
    required String email,
    required String password,
    required int eventId,
  })
  onCreateAgent;
  final Future<void> Function({
    required int id,
    required String name,
    required String email,
    required String password,
    required int eventId,
  })
  onUpdateAgent;
  final Future<void> Function(int id) onDeleteAgent;

  @override
  State<_AgentManagementSheet> createState() => _AgentManagementSheetState();
}

class _AgentManagementSheetState extends State<_AgentManagementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int? _eventId;
  AgentItem? _editingAgent;
  bool _saving = false;
  bool _showPassword = false;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _edit(AgentItem agent) {
    setState(() {
      _editingAgent = agent;
      _name.text = agent.name;
      _email.text = agent.email;
      _password.text = agent.password;
      _eventId = agent.eventId;
      _showPassword = false;
    });
  }

  Future<void> _delete(AgentItem agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet agent ?'),
        content: Text('L’accès de ${agent.name} sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onDeleteAgent(agent.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _eventId == null) return;
    setState(() => _saving = true);
    try {
      final editing = _editingAgent;
      if (editing == null) {
        await widget.onCreateAgent(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          eventId: _eventId!,
        );
      } else {
        await widget.onUpdateAgent(
          id: editing.id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          eventId: _eventId!,
        );
      }
      if (mounted) {
        _name.clear();
        _email.clear();
        _password.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Agent ajouté. Il peut se connecter avec son e-mail et son mot de passe.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cet e-mail est déjà associé à un agent.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Mode Agent',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Créez un accès limité à un événement.',
              style: TextStyle(color: _muted),
            ),
            if (widget.agents.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...widget.agents.map((agent) {
                final event = _eventFor(widget.events, agent.eventId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.badge_outlined),
                  ),
                  title: Text(agent.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Modifier l’agent',
                        onPressed: () => _edit(agent),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Supprimer l’agent',
                        onPressed: () => _delete(agent),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${agent.email} · ${event?.name ?? 'Événement supprimé'}',
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l’agent',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Renseignez le nom.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail de connexion',
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Renseignez un e-mail valide.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _password,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe (6 caractères minimum)',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        tooltip: 'Afficher ou masquer le mot de passe',
                      ),
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Choisissez au moins 6 caractères.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _eventId,
                    decoration: const InputDecoration(
                      labelText: 'Événement autorisé',
                    ),
                    items: widget.events
                        .map(
                          (event) => DropdownMenuItem(
                            value: event.id,
                            child: Text(
                              event.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _eventId = value),
                    validator: (value) =>
                        value == null ? 'Sélectionnez un événement.' : null,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _create,
                    icon: Icon(
                      _editingAgent == null
                          ? Icons.person_add_alt_1
                          : Icons.save_outlined,
                    ),
                    label: Text(
                      _saving
                          ? 'Enregistrement…'
                          : _editingAgent == null
                          ? 'Créer l’agent'
                          : 'Enregistrer les modifications',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  if (_editingAgent != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _editingAgent = null;
                              _name.clear();
                              _email.clear();
                              _password.clear();
                              _eventId = null;
                              _showPassword = false;
                            }),
                      child: const Text('Annuler la modification'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connexion locale de démonstration : les identifiants sont stockés sur cet appareil.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlanStatus extends StatelessWidget {
  const _PlanStatus();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E5),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFF0E6C9)),
    ),
    child: const Row(
      children: [
        Icon(Icons.workspace_premium_outlined, color: Color(0xFFA77C17)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Forfait Gratuit',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
        ),
        Text('Non connecté', style: TextStyle(fontSize: 11, color: _muted)),
      ],
    ),
  );
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: const BorderSide(color: _line),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _brandTint,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _brand),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 19),
    ),
  );
}

class AgentHomePage extends StatelessWidget {
  const AgentHomePage({
    super.key,
    required this.agent,
    required this.event,
    required this.leads,
    required this.onCapture,
    required this.onScan,
    required this.onLogout,
  });

  final AgentItem agent;
  final EventItem event;
  final List<LeadItem> leads;
  final VoidCallback onCapture;
  final VoidCallback onScan;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = leads.where((lead) {
      final date = DateTime.tryParse(lead.createdAt);
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
    final hot = leads.where((lead) => lead.priority == 'Chaud').length;
    final warm = leads.where((lead) => lead.priority == 'Tiède').length;
    final info = leads.where((lead) => lead.priority == 'Info').length;
    int percent(int count) =>
        leads.isEmpty ? 0 : (count * 100 / leads.length).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Espace agent',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: onLogout,
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Bonjour ${agent.name}',
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Votre activité sur votre événement',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _brandDark,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      color: Colors.white70,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'ÉVÉNEMENT AUTORISÉ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  event.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${event.city} · ${_shortDate(event.startDate)} — ${_shortDate(event.endDate)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Stand ${event.stand.isEmpty ? '—' : event.stand}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.people_alt_outlined,
                  value: '${leads.length}',
                  title: 'Visiteurs capturés',
                  tint: _brandTint,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.today_outlined,
                  value: '$today',
                  title: 'Aujourd’hui',
                  tint: const Color(0xFFFFF0EC),
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scanner un badge'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Saisir un visiteur'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'MON ÉVOLUTION CRM',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
          const SizedBox(height: 10),
          _AgentCrmRow(
            label: 'Chaud',
            count: hot,
            percent: percent(hot),
            color: const Color(0xFFC64F36),
          ),
          _AgentCrmRow(
            label: 'Tiède',
            count: warm,
            percent: percent(warm),
            color: const Color(0xFFB77A1B),
          ),
          _AgentCrmRow(
            label: 'Info',
            count: info,
            percent: percent(info),
            color: const Color(0xFF517B99),
          ),
          const SizedBox(height: 7),
          Text(
            '${leads.length} visiteur${leads.length == 1 ? '' : 's'} au total · $today aujourd’hui',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 22),
          Text(
            'Mes visiteurs (${leads.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          if (leads.isEmpty)
            const _EmptyHint(
              icon: Icons.people_outline,
              text:
                  'Vos visiteurs apparaîtront ici après vos premières saisies.',
            )
          else
            ...leads.map((lead) => LeadCard(lead: lead, event: event)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: _brandTint,
                  child: Icon(Icons.person_outline, color: _brand),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        agent.email,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_user_outlined, color: _brand),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

class _AgentCrmRow extends StatelessWidget {
  const _AgentCrmRow({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });
  final String label;
  final int count;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ),
              Text(
                '$count · $percent%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    ),
  );
}

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.event,
    required this.onSave,
    this.initialScan = false,
    this.initialOwner,
  });
  final EventItem event;
  final Future<void> Function(LeadDraft draft) onSave;
  final bool initialScan;
  final String? initialOwner;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final _formKey = GlobalKey<FormState>();
  final _audioRecorder = AudioRecorder();
  final _voiceBytes = <int>[];
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _position = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _owner = TextEditingController(text: 'Équipe de stand');
  final List<String> _selectedTags = [];
  StreamSubscription<Uint8List>? _voiceStream;
  Timer? _voiceTimer;
  Uint8List? _voiceNote;
  String _priority = 'Tiède';
  bool _saving = false;
  bool _continueScanning = false;
  bool _recordingVoice = false;
  bool _playingVoice = false;
  int _voiceSeconds = 0;
  final _voicePlayer = AudioPlayer();
  StreamSubscription<void>? _voicePlaybackSubscription;

  @override
  void initState() {
    super.initState();
    _owner.text = widget.initialOwner ?? 'Équipe de stand';
    _continueScanning = widget.initialScan;
    _voicePlaybackSubscription = _voicePlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingVoice = false);
    });
    if (widget.initialScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _voiceStream?.cancel();
    _voicePlaybackSubscription?.cancel();
    if (_recordingVoice) unawaited(_audioRecorder.stop());
    unawaited(_audioRecorder.dispose());
    unawaited(_voicePlayer.dispose());
    _name.dispose();
    _company.dispose();
    _position.dispose();
    _email.dispose();
    _phone.dispose();
    _note.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          _message(
            context,
            'Autorisez l’accès au microphone pour enregistrer.',
          );
        }
        return;
      }
      _voiceBytes.clear();
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _voiceStream = stream.listen(
        _voiceBytes.addAll,
        onError: (Object error) {
          if (mounted) {
            _message(context, 'Enregistrement vocal impossible : $error');
          }
          _stopVoiceRecording();
        },
      );
      if (!mounted) return;
      setState(() {
        _recordingVoice = true;
        _voiceSeconds = 0;
        _voiceNote = null;
      });
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_voiceSeconds >= 14) {
          timer.cancel();
          setState(() => _voiceSeconds = 15);
          _stopVoiceRecording();
        } else {
          setState(() => _voiceSeconds++);
        }
      });
    } catch (error) {
      if (mounted) {
        _message(context, 'Démarrage du microphone impossible : $error');
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_recordingVoice) return;
    _voiceTimer?.cancel();
    try {
      await _audioRecorder.stop();
      await _voiceStream?.cancel();
      _voiceStream = null;
      if (!mounted) return;
      setState(() {
        _recordingVoice = false;
        _voiceNote = _voiceBytes.isEmpty
            ? null
            : Uint8List.fromList(_voiceBytes);
      });
      if (_voiceNote == null) {
        _message(context, 'Aucun son enregistré. Réessayez.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _recordingVoice = false);
        _message(context, 'Arrêt de l’enregistrement impossible : $error');
      }
    }
  }

  Future<void> _toggleVoicePlayback() async {
    if (_recordingVoice) return;
    final voiceNote = _voiceNote;
    if (voiceNote == null || voiceNote.isEmpty) return;
    if (_playingVoice) {
      await _voicePlayer.stop();
      if (mounted) setState(() => _playingVoice = false);
      return;
    }
    try {
      await _voicePlayer.play(
        BytesSource(_voiceNoteWav(voiceNote), mimeType: 'audio/wav'),
      );
      if (mounted) setState(() => _playingVoice = true);
    } catch (error) {
      if (mounted) {
        _message(context, 'Lecture de la note vocale impossible : $error');
      }
    }
  }

  Future<void> _scan() async {
    final data = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (!mounted) return;
    if (data == null) {
      setState(() => _continueScanning = false);
      return;
    }
    setState(() {
      _name.text = data['name'] ?? _name.text;
      _company.text = data['company'] ?? _company.text;
      _position.text = data['position'] ?? _position.text;
      _email.text = data['email'] ?? _email.text;
      _phone.text = data['phone'] ?? _phone.text;
      _continueScanning = true;
    });
  }

  Future<void> _save() async {
    if (_recordingVoice) await _stopVoiceRecording();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        LeadDraft(
          eventId: widget.event.id,
          name: _name.text,
          company: _company.text,
          position: _position.text,
          owner: _owner.text,
          email: _email.text,
          phone: _phone.text,
          priority: _priority,
          tags: _selectedTags,
          note: _note.text,
          voiceNote: _voiceNote,
        ),
      );
      if (mounted) {
        _name.clear();
        _company.clear();
        _position.clear();
        _email.clear();
        _phone.clear();
        _note.clear();
        _voiceNote = null;
        _voiceBytes.clear();
        await _voicePlayer.stop();
        _playingVoice = false;
        _selectedTags.clear();
        _priority = 'Tiède';
        _formKey.currentState?.reset();
        if (!mounted) return;
        _message(context, 'Visiteur enregistré sur cet appareil.');
        if (_continueScanning) {
          await _scan();
        }
      }
    } catch (error) {
      if (mounted) {
        _message(context, 'Enregistrement local impossible : $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Nouveau visiteur',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
      actions: [
        TextButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scanner'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _brandTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined, color: _brand),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${widget.event.name} · stand ${widget.event.stand.isEmpty ? '—' : widget.event.stand}',
                    style: const TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'COORDONNÉES',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 11,
              color: _muted,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            validator: _required,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom complet *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _company,
            validator: _required,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Entreprise',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _position,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Poste (facultatif)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
            decoration: const InputDecoration(
              labelText: 'E-mail *',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: _required,
            decoration: const InputDecoration(
              labelText: 'Téléphone *',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'QUALIFICATION À CHAUD',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 11,
              color: _muted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final priority in ['Chaud', 'Tiède', 'Info'])
                ChoiceChip(
                  label: Text(priority),
                  selected: _priority == priority,
                  onSelected: (_) => setState(() => _priority = priority),
                  selectedColor: priority == 'Chaud'
                      ? const Color(0xFFFFE2DA)
                      : priority == 'Tiède'
                      ? const Color(0xFFFFF0D8)
                      : const Color(0xFFE1EEF5),
                  labelStyle: TextStyle(
                    color: _priority == priority ? _ink : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'INTÉRÊTS PRODUIT',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontSize: 11,
              color: _muted,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final tag in [
                'Green Stand',
                'Catalogue',
                'Équipement',
                'Service',
                'Devis',
              ])
                FilterChip(
                  label: Text(tag),
                  selected: _selectedTags.contains(tag),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _selectedTags.add(tag)
                        : _selectedTags.remove(tag),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note de conversation',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: _recordingVoice
                        ? _stopVoiceRecording
                        : _startVoiceRecording,
                    tooltip: _recordingVoice
                        ? 'Arrêter l’enregistrement'
                        : 'Enregistrer une note vocale de 15 secondes maximum',
                    icon: Icon(
                      _recordingVoice ? Icons.stop : Icons.mic_none_outlined,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: _recordingVoice
                          ? const Color(0xFFC64F36)
                          : _brand,
                    ),
                  ),
                  Text(
                    _recordingVoice
                        ? '$_voiceSeconds/15 s'
                        : _voiceNote != null
                        ? 'Note prête'
                        : '15 s max',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                  if (_voiceNote != null && !_recordingVoice)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: _playingVoice ? 'Arrêter' : 'Écouter',
                          onPressed: _toggleVoicePlayback,
                          icon: Icon(
                            _playingVoice ? Icons.stop : Icons.play_arrow,
                            size: 19,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Supprimer la note vocale',
                          onPressed: () => setState(() {
                            _voiceNote = null;
                            _voiceBytes.clear();
                          }),
                          icon: const Icon(Icons.delete_outline, size: 19),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _owner,
            validator: _required,
            decoration: const InputDecoration(
              labelText: 'Commercial responsable',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 13),
          const _PrototypeNote(
            text:
                'Le visiteur sera enregistré localement. L’envoi du pass, du catalogue PDF et de la carte commerciale n’est pas actif dans ce prototype.',
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Enregistrement…' : 'Enregistrer et suivant'),
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
    ),
  );
}

class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();
  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _handled = false;

  Map<String, String> _parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return _normalizeBadgeFields(
          decoded.map((key, value) => MapEntry(key, value.toString())),
        );
      }
    } on FormatException {
      // QR badges may also use query-string or line-based formats.
    }
    try {
      final query = Uri.splitQueryString(raw);
      if (query.keys.any(
        (key) => const {
          'name',
          'company',
          'email',
          'phone',
        }.contains(key.toLowerCase()),
      )) {
        return _normalizeBadgeFields(query);
      }
    } on FormatException {
      // Fall through to the simple line-based badge format.
    }
    final result = <String, String>{};
    final lines = raw.split(RegExp(r'[\n;]'));
    if (lines.isNotEmpty) result['name'] = lines.first.trim();
    for (final line in lines.skip(1)) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final key = parts.first.trim().toLowerCase();
      final value = parts.skip(1).join(':').trim();
      result[key] = value;
    }
    return _normalizeBadgeFields(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scanner le badge')),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          onDetect: (capture) {
            if (_handled || capture.barcodes.isEmpty) return;
            final raw = capture.barcodes.first.rawValue;
            if (raw == null || raw.isEmpty) return;
            _handled = true;
            Navigator.pop(context, _parse(raw));
          },
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Placez le QR code du badge dans le cadre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 260,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: _accent, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Ouvrir le formulaire'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.action});
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 14, 17),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _LocalNotice extends StatelessWidget {
  const _LocalNotice({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4DF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.sync_problem_outlined,
          color: Color(0xFFA16A14),
          size: 19,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$count visiteur${count == 1 ? '' : 's'} enregistré${count == 1 ? '' : 's'} sur cet appareil · synchronisation indisponible',
            style: const TextStyle(
              color: Color(0xFF805817),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PrototypeNote extends StatelessWidget {
  const _PrototypeNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F2EF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: _muted, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: _mutedSoft),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4F0),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String? _emailValidator(String? value) {
  final requiredError = _required(value);
  if (requiredError != null) return requiredError;
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
    return 'Adresse e-mail invalide';
  }
  return null;
}

Map<String, String> _normalizeBadgeFields(Map<String, String> fields) {
  final normalized = <String, String>{};
  for (final entry in fields.entries) {
    final key = entry.key
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z]'), '');
    final target = switch (key) {
      'name' || 'fullname' || 'visitorname' => 'name',
      'firstname' || 'givenname' || 'prenom' => 'first_name',
      'lastname' || 'familyname' || 'nom' => 'last_name',
      'company' ||
      'organization' ||
      'organisation' ||
      'societe' ||
      'entreprise' => 'company',
      'position' || 'jobtitle' || 'title' || 'poste' => 'position',
      'email' || 'mail' => 'email',
      'phone' || 'telephone' || 'mobile' || 'tel' => 'phone',
      _ => '',
    };
    if (target.isNotEmpty && entry.value.trim().isNotEmpty) {
      normalized[target] = entry.value.trim();
    }
  }
  if (!normalized.containsKey('name')) {
    final firstName = normalized.remove('first_name');
    final lastName = normalized.remove('last_name');
    final fullName = [
      firstName,
      lastName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) normalized['name'] = fullName;
  }
  normalized.remove('first_name');
  normalized.remove('last_name');
  return normalized;
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _shortDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return value;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _shortDateTime(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

EventItem? _eventFor(List<EventItem> events, int id) {
  for (final event in events) {
    if (event.id == id) return event;
  }
  return null;
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
