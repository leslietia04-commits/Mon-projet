import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'data/local_store.dart';

void main() => runApp(DigitalyxApp(store: SqliteExhibitorStore()));

const _ink = Color(0xFF14231E);
const _green = Color(0xFF167A58);
const _lime = Color(0xFFD8F36A);
const _paper = Color(0xFFF5F7F3);

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
  const DigitalyxApp({super.key, required this.store});
  final ExhibitorStore store;

  @override
  State<DigitalyxApp> createState() => _DigitalyxAppState();
}

class _DigitalyxAppState extends State<DigitalyxApp> {
  int _tab = 0;
  bool _hasDemoSession = false;
  String _username = '';
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late Future<void> _loading;
  List<EventItem> _events = [];
  List<LeadItem> _leads = [];

  @override
  void initState() {
    super.initState();
    _loading = _refresh();
  }

  Future<void> _refresh() async {
    final values = await Future.wait([
      widget.store.getEvents(),
      widget.store.getLeads(),
    ]);
    if (!mounted) return;
    setState(() {
      _events = values[0] as List<EventItem>;
      _leads = values[1] as List<LeadItem>;
    });
  }

  Future<void> _saveLead(LeadDraft draft) async {
    await widget.store.addLead(draft);
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

  Future<void> _openCapture({bool scan = false}) async {
    if (_events.isEmpty) {
      _showMessage('Ajoute d’abord un événement pour enregistrer un prospect.');
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
        'Prospect enregistré sur cet appareil. Aucune donnée envoyée.',
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
        colorScheme: ColorScheme.fromSeed(seedColor: _green),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF929A94)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8ECE7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
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
              body: Center(child: CircularProgressIndicator(color: _green)),
            );
          }
          if (!_hasDemoSession) {
            return LoginPage(
              onLogin: (username) {
                setState(() {
                  _username = username;
                  _hasDemoSession = true;
                });
                _showMessage(
                  'Session de démonstration ouverte. Compte non vérifié.',
                );
              },
            );
          }
          return _buildShell();
        },
      ),
    );
  }

  Widget _buildShell() {
    final pages = [
      HomePage(
        events: _events,
        leads: _leads,
        onCapture: _openCapture,
        onScan: () => _openCapture(scan: true),
        onEvents: () => setState(() => _tab = 3),
        onLeads: () => setState(() => _tab = 1),
        onProfile: () => setState(() => _tab = 4),
      ),
      LeadsPage(leads: _leads, events: _events, onCapture: _openCapture),
      const DirectoryPage(),
      EventsPage(events: _events, onCreate: _createEvent, onJoin: _joinEvent),
      ProfilePage(onMessage: _showMessage, username: _username),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE5F3EA),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            key: ValueKey('nav-leads'),
            icon: Icon(Icons.people_alt_outlined),
            label: 'Prospects',
          ),
          NavigationDestination(
            key: ValueKey('nav-directory'),
            icon: Icon(Icons.storefront_outlined),
            label: 'Annuaire',
          ),
          NavigationDestination(
            key: ValueKey('nav-events'),
            icon: Icon(Icons.event_outlined),
            label: 'Salons',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

const _gold = Color(0xFFE7BD63);
const _goldLight = Color(0xFFFFE9A7);
const _night = Color(0xFF080B12);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});
  final ValueChanged<String> onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    widget.onLogin(_username.text.trim());
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
                      const _GoldDMark(),
                      const SizedBox(height: 17),
                      Text(
                        'Digitalyx',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: _goldLight,
                          shadows: [
                            Shadow(
                              color: Color(0x889C6924),
                              blurRadius: 19,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Exhibitor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 5.5,
                          color: Color(0xFFF4EBDD),
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
                          color: Color(0xFF92919A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Prototype hors ligne · identifiants non vérifiés',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB6B3B0),
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
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
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.065),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _gold.withValues(alpha: 0.57), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.07),
              blurRadius: 30,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 30,
              offset: Offset(0, 18),
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
                style: TextStyle(color: Color(0xFFB6B3B0), fontSize: 12),
              ),
              const SizedBox(height: 17),
              _loginField(
                controller: _username,
                label: 'E-mail',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                suffix: _emailSuffix(_username),
              ),
              const SizedBox(height: 10),
              _loginField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  color: const Color(0xFFC5B894),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
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
                      activeColor: _gold,
                      checkColor: _night,
                      side: const BorderSide(color: Color(0xFFB99B5B)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: const Text(
                      'Remember me',
                      style: TextStyle(color: Color(0xFFE1DED7), fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      foregroundColor: _goldLight,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    child: const Text(
                      'Forgot Password?',
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
                      colors: [
                        Color(0xFFFFE89B),
                        Color(0xFFE4B64E),
                        Color(0xFFC68D2C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.24),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF21180A),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'LOGIN',
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
                    Expanded(child: Divider(color: Color(0x33E7BD63))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'NOUVEAU CHEZ DIGITALYX ?',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.2,
                          color: Color(0xFFB6B3B0),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0x33E7BD63))),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _createAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: _gold.withValues(alpha: 0.7)),
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
    style: const TextStyle(color: Colors.white, fontSize: 14),
    cursorColor: _goldLight,
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Ce champ est obligatoire'
        : null,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFCCC5B3), fontSize: 13),
      prefixIcon: Icon(icon, color: _gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF080B12).withValues(alpha: 0.24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _gold.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _goldLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE68D80)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE68D80), width: 1.5),
      ),
    ),
  );

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password?'),
        content: const Text(
          'La réinitialisation nécessite le service de compte Digitalyx. Aucun e-mail ne sera envoyé en mode démonstration.',
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
      _username.text = registration.email;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => WelcomePage(fullName: registration.fullName),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'L’inscription n’a pas été envoyée : service Digitalyx non connecté.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

Widget _atSignButton(TextEditingController controller) => IconButton(
  onPressed: () => _insertEmailText(controller, '@'),
  tooltip: 'Insérer @',
  color: _goldLight,
  icon: const Text(
    '@',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
);

Widget _emailSuffix(TextEditingController controller) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _atSignButton(controller),
    TextButton(
      onPressed: () => _insertEmailText(controller, '@gmail.com'),
      style: TextButton.styleFrom(
        foregroundColor: _goldLight,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        '@gmail.com',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ),
  ],
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
    required this.company,
    required this.position,
    required this.phone,
  });

  final String fullName;
  final String email;
  final String company;
  final String position;
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
  final _company = TextEditingController();
  final _position = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _company.dispose();
    _position.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
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
        company: _company.text.trim(),
        position: _position.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _night,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: _goldLight,
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
          child: _AmbientGlow(size: 270, color: _gold.withValues(alpha: 0.1)),
        ),
        SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              children: [
                const _GoldDMark(),
                const SizedBox(height: 18),
                const Text(
                  'Inscription exposant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Renseignez les informations de votre profil.',
                  style: TextStyle(color: Color(0xFFB6B3B0), fontSize: 13),
                ),
                const SizedBox(height: 20),
                _registrationField(
                  controller: _fullName,
                  label: 'Nom complet',
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
                  suffix: _emailSuffix(_email),
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _company,
                  label: 'Entreprise',
                  icon: Icons.business_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _position,
                  label: 'Poste',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _phone,
                  label: 'Numéro de téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _phoneValidator,
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _password,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  validator: _passwordValidator,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    color: const Color(0xFFC5B894),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                    ),
                    tooltip: _obscurePassword
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                  ),
                ),
                const SizedBox(height: 12),
                _registrationField(
                  controller: _confirmPassword,
                  label: 'Confirmer le mot de passe',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    final error = _passwordValidator(value);
                    if (error != null) return error;
                    if (value != _password.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                  suffix: IconButton(
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    color: const Color(0xFFC5B894),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                    ),
                    tooltip: _obscureConfirmPassword
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 53,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFE89B),
                          Color(0xFFE4B64E),
                          Color(0xFFC68D2C),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF21180A),
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
                const Text(
                  'Le service de création de compte n’est pas encore connecté. '
                  'La validation de ce formulaire ne transmet aucune donnée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB6B3B0),
                    fontSize: 11,
                    height: 1.4,
                  ),
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
    style: const TextStyle(color: Colors.white, fontSize: 14),
    cursorColor: _goldLight,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFCCC5B3), fontSize: 13),
      prefixIcon: Icon(icon, color: _gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.055),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: _gold.withValues(alpha: 0.42)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _goldLight, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE68D80)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE68D80), width: 1.4),
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
          child: IgnorePointer(child: CustomPaint(painter: _GoldSparkles())),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(25, 30, 25, 24),
            child: Column(
              children: [
            const Spacer(flex: 2),
            const _GoldDMark(),
            const SizedBox(height: 18),
            const Text(
              'Digitalyx',
              style: TextStyle(
                color: _goldLight,
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: Color(0x887A4B12),
                    blurRadius: 16,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
            const Text(
              'Exhibitor',
              style: TextStyle(
                color: Colors.white,
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
                color: _goldLight,
                fontSize: 29,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                height: 1.2,
                shadows: [Shadow(color: Color(0xAA07133E), blurRadius: 18)],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Bienvenue sur votre nouvelle plateforme exposant Digitalyx Exhibitor. Connectez-vous pour accéder à votre portail exclusif et gérer vos événements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF2F2FA),
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
                    colors: [
                      Color(0xFFFFE9A1),
                      Color(0xFFE8BC5B),
                      Color(0xFFC68D2C),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.3),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF21180A),
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
                color: Color(0xFFD4DCF5),
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
            colors: [Color(0xFF17202A), _night, Color(0xFF11131A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      Positioned(
        top: -115,
        right: -105,
        child: _AmbientGlow(size: 330, color: _gold.withValues(alpha: 0.13)),
      ),
      Positioned(
        bottom: -155,
        left: -110,
        child: _AmbientGlow(
          size: 350,
          color: const Color(0xFF9D7132).withValues(alpha: 0.13),
        ),
      ),
    ],
  );
}

class _GoldSparkles extends CustomPainter {
  const _GoldSparkles();

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
        ..color = _goldLight.withValues(alpha: index.isEven ? 0.85 : 0.58)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(point, radius * 2.2, glow);
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = _goldLight.withValues(alpha: 0.92),
      );

      if (index.isEven) {
        final flare = Paint()
          ..color = _goldLight.withValues(alpha: 0.58)
          ..strokeWidth = 0.7;
        canvas.drawLine(
          point.translate(-5, 0),
          point.translate(5, 0),
          flare,
        );
        canvas.drawLine(
          point.translate(0, -5),
          point.translate(0, 5),
          flare,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldSparkles oldDelegate) => false;
}

class _GoldDMark extends StatelessWidget {
  const _GoldDMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 78,
    height: 78,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x66FFECA8), Color(0x117B541D)],
      ),
      border: Border.all(color: _gold.withValues(alpha: 0.75), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: _gold.withValues(alpha: 0.19),
          blurRadius: 25,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'D',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 54,
            fontWeight: FontWeight.w700,
            height: 1,
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [_goldLight, Color(0xFFB47B24)],
              ).createShader(const Rect.fromLTWH(0, 0, 70, 70)),
          ),
        ),
        Positioned(
          right: 17,
          top: 22,
          bottom: 22,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF171923),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Positioned(
          right: 14,
          top: 24,
          child: Transform.rotate(
            angle: -0.62,
            child: Container(
              width: 15,
              height: 2,
              color: _goldLight.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
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

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.events,
    required this.leads,
    required this.onCapture,
    required this.onScan,
    required this.onEvents,
    required this.onLeads,
    required this.onProfile,
  });

  final List<EventItem> events;
  final List<LeadItem> leads;
  final VoidCallback onCapture;
  final VoidCallback onScan;
  final VoidCallback onEvents;
  final VoidCallback onLeads;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final hot = leads.where((lead) => lead.priority == 'Chaud').length;
    final event = events.isEmpty ? null : events.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIGITALYX',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bonjour, exposant 👋',
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
                backgroundColor: Color(0xFFE5F3EA),
                child: Icon(Icons.eco_outlined, color: _green),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EB),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 17, color: _green),
              SizedBox(width: 7),
              Text(
                'Mode hors ligne · données enregistrées sur l’appareil',
                style: TextStyle(
                  fontSize: 12,
                  color: _green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E5),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFF0E6C9)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFA77C17),
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
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.chevron_right, color: _green, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (event != null)
          _EventHero(event: event)
        else
          _EmptyEventCard(onTap: onEvents),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                value: '${leads.length}',
                title: 'Prospects',
                icon: Icons.people_alt_outlined,
                tint: const Color(0xFFE8F2F5),
                onTap: onLeads,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                value: '$hot',
                title: 'À traiter vite',
                icon: Icons.bolt,
                tint: const Color(0xFFFFF0DB),
                onTap: onLeads,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _LeadBreakdown(leads: leads),
        const SizedBox(height: 22),
        const Text(
          'CAPTER UN CONTACT',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6D7971),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scanner un badge',
                subtitle: 'Lire un QR code',
                color: const Color(0xFFE8F4EB),
                onTap: onScan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.person_add_alt_1,
                title: 'Saisie manuelle',
                subtitle: 'Ajouter un visiteur',
                color: const Color(0xFFEAF0F6),
                onTap: onCapture,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Derniers prospects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            TextButton(onPressed: onLeads, child: const Text('Tout voir')),
          ],
        ),
        if (leads.isEmpty)
          const _EmptyHint(
            icon: Icons.inbox_outlined,
            text: 'Vos nouveaux contacts apparaîtront ici.',
          )
        else
          ...leads.take(3).map((lead) => LeadCard(lead: lead)),
      ],
    );
  }
}

class _LeadBreakdown extends StatelessWidget {
  const _LeadBreakdown({required this.leads});
  final List<LeadItem> leads;

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
        border: Border.all(color: const Color(0xFFEAEEEA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatValue(
              value: '$hot',
              label: 'Chaud',
              color: const Color(0xFFC64F36),
            ),
          ),
          Expanded(
            child: _StatValue(
              value: '$warm',
              label: 'Tiède',
              color: const Color(0xFFB77A1B),
            ),
          ),
          Expanded(
            child: _StatValue(
              value: '$info',
              label: 'Info',
              color: const Color(0xFF517B99),
            ),
          ),
          Expanded(
            child: _StatValue(
              value: '${leads.length}',
              label: 'Total',
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
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
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF77827A)),
      ),
    ],
  );
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF155B43), Color(0xFF238963)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_available, color: _lime, size: 17),
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
            const Icon(Icons.calendar_month_outlined, size: 15, color: _lime),
            const SizedBox(width: 7),
            Text(
              '${_shortDate(event.startDate)} — ${_shortDate(event.endDate)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EmptyEventCard extends StatelessWidget {
  const _EmptyEventCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.event_available, color: _green),
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
        border: Border.all(color: const Color(0xFFEAEEEA)),
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
            child: Icon(icon, size: 19, color: _green),
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
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF768079)),
          ),
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
        border: Border.all(color: const Color(0xFFEAEEEA)),
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
            child: Icon(icon, color: _green, size: 20),
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
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF87918A), fontSize: 11),
          ),
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
        title: 'Prospects',
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
              foregroundColor: _green,
            ),
          ),
        ),
      Expanded(
        child: leads.isEmpty
            ? _EmptyHint(
                icon: Icons.person_search_outlined,
                text:
                    'Aucun prospect pour le moment. Ajoutez votre premier contact.',
                action: FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter un prospect'),
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
            Text(
              profile.description,
              style: const TextStyle(color: Color(0xFF657168)),
            ),
            const SizedBox(height: 12),
            Text(
              'Stand ${profile.stand}  ·  ${profile.website}',
              style: const TextStyle(
                color: _green,
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
      side: const BorderSide(color: Color(0xFFEAEEEA)),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE8F3EB),
        child: Text(
          profile.name.substring(0, 1),
          style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
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
        border: Border.all(color: const Color(0xFFEAEEEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFFE8F3EB),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _green,
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8982),
                      ),
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF646F68)),
            ),
          ],
          if (event != null) ...[
            const SizedBox(height: 10),
            Text(
              '${event!.name} · ${_shortDateTime(lead.createdAt)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF98A099)),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            'Contact : ${lead.owner}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF98A099)),
          ),
        ],
      ),
    );
  }
}

class EventsPage extends StatelessWidget {
  const EventsPage({
    super.key,
    required this.events,
    required this.onCreate,
    required this.onJoin,
  });
  final List<EventItem> events;
  final Future<void> Function({
    required String name,
    required String city,
    required String startDate,
    required String endDate,
    required String stand,
  })
  onCreate;
  final Future<void> Function(EventItem event, String stand) onJoin;

  Future<void> _newEvent(BuildContext context) async {
    final result = await showModalBottomSheet<_NewEventData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (_) => const _EventFormSheet(),
    );
    if (result != null) {
      EventItem? duplicate;
      for (final event in events) {
        if (_normalize(event.name) == _normalize(result.name) &&
            _normalize(event.city) == _normalize(result.city) &&
            event.startDate == result.startDate &&
            event.endDate == result.endDate) {
          duplicate = event;
          break;
        }
      }
      if (duplicate != null && context.mounted) {
        await _join(context, duplicate);
      } else {
        await onCreate(
          name: result.name,
          city: result.city,
          startDate: result.startDate,
          endDate: result.endDate,
          stand: result.stand,
        );
        if (context.mounted) {
          _message(
            context,
            'Événement créé localement. Le rapprochement avec le salon officiel attend le serveur.',
          );
        }
      }
    }
  }

  Future<void> _join(BuildContext context, EventItem event) async {
    final controller = TextEditingController(text: event.stand);
    final stand = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rejoindre ${event.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Numéro de stand'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (stand != null) {
      await onJoin(event, stand);
      if (context.mounted) {
        _message(context, 'Stand mis à jour sur cet appareil.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _PageHeader(
        title: 'Événements',
        subtitle: 'Salons et stands enregistrés localement',
        action: IconButton.filledTonal(
          onPressed: () => _newEvent(context),
          icon: const Icon(Icons.add),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: OutlinedButton.icon(
          onPressed: () => _findEvent(context),
          icon: const Icon(Icons.search),
          label: const Text('Rechercher un salon connu'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: _green,
            side: const BorderSide(color: Color(0xFFD9E5DB)),
          ),
        ),
      ),
      Expanded(
        child: events.isEmpty
            ? _EmptyHint(
                icon: Icons.event_note_outlined,
                text:
                    'Aucun événement enregistré. Créez votre salon temporaire ou recherchez un salon.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  for (final event in events)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEAEEEA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 43,
                                height: 43,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F3EB),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.event_available,
                                  color: _green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.cloud_off,
                                size: 16,
                                color: Color(0xFF87918A),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Text(
                            '${event.city} · ${_shortDate(event.startDate)} — ${_shortDate(event.endDate)}',
                            style: const TextStyle(
                              color: Color(0xFF707B73),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _Tag(
                                text:
                                    'Stand ${event.stand.isEmpty ? 'à définir' : event.stand}',
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _join(context, event),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Mon stand'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const _PrototypeNote(
                    text:
                        'La recherche, le rapprochement avec un événement maître et la synchronisation nécessitent le serveur organisateur.',
                  ),
                ],
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: FilledButton.icon(
          onPressed: () => _newEvent(context),
          icon: const Icon(Icons.add),
          label: const Text('Créer un événement local'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: _green,
          ),
        ),
      ),
    ],
  );

  Future<void> _findEvent(BuildContext context) async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechercher un salon'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nom du salon'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || !context.mounted) return;
    final matches = events
        .where(
          (event) =>
              event.name.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    if (matches.isEmpty) {
      _message(
        context,
        'Aucun salon correspondant dans les événements déjà enregistrés sur cet appareil.',
      );
      return;
    }
    await _join(context, matches.first);
  }
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
                  color: const Color(0xFFD7DDD7),
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
              style: TextStyle(color: Color(0xFF77827A)),
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
              decoration: const InputDecoration(labelText: 'Ville'),
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
  });
  final ValueChanged<String> onMessage;
  final String username;

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
      const Text(
        'Compte et accès exposant',
        style: TextStyle(color: Color(0xFF77827A)),
      ),
      const SizedBox(height: 15),
      const _PlanStatus(),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF173E30),
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
          color: Color(0xFF77827A),
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
        Text(
          'Non connecté',
          style: TextStyle(fontSize: 11, color: Color(0xFF77827A)),
        ),
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
      side: const BorderSide(color: Color(0xFFEAEEEA)),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3EB),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _green),
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

class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.event,
    required this.onSave,
    this.initialScan = false,
  });
  final EventItem event;
  final Future<void> Function(LeadDraft draft) onSave;
  final bool initialScan;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _position = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _owner = TextEditingController(text: 'Équipe de stand');
  final List<String> _selectedTags = [];
  String _priority = 'Tiède';
  bool _saving = false;
  bool _continueScanning = false;

  @override
  void initState() {
    super.initState();
    _continueScanning = widget.initialScan;
    if (widget.initialScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _position.dispose();
    _email.dispose();
    _phone.dispose();
    _note.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final data = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const _QrScannerPage()),
    );
    if (data == null || !mounted) return;
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
        ),
      );
      if (mounted) {
        _name.clear();
        _company.clear();
        _position.clear();
        _email.clear();
        _phone.clear();
        _note.clear();
        _selectedTags.clear();
        _priority = 'Tiède';
        _formKey.currentState?.reset();
        _message(context, 'Prospect enregistré sur cet appareil.');
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
        'Nouveau prospect',
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
              color: const Color(0xFFE9F3EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_outlined, color: _green),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${widget.event.name} · stand ${widget.event.stand.isEmpty ? '—' : widget.event.stand}',
                    style: const TextStyle(
                      color: _green,
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
              color: Color(0xFF68756C),
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
              color: Color(0xFF68756C),
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
                    color: _priority == priority
                        ? _ink
                        : const Color(0xFF657168),
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
              color: Color(0xFF68756C),
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
          TextFormField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note de conversation',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
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
                'Le prospect sera enregistré localement. L’envoi du pass, du catalogue PDF et de la carte commerciale n’est pas actif dans ce prototype.',
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
            backgroundColor: _green,
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
          child: Container(
            width: 260,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: _lime, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const Positioned(
          left: 28,
          right: 28,
          bottom: 46,
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
                style: const TextStyle(color: Color(0xFF77827A), fontSize: 12),
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
            '$count prospect${count == 1 ? '' : 's'} enregistré${count == 1 ? '' : 's'} sur cet appareil · synchronisation indisponible',
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
        const Icon(Icons.info_outline, color: Color(0xFF6D7971), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6D7971),
              fontSize: 11,
              height: 1.4,
            ),
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
          Icon(icon, size: 42, color: const Color(0xFF9AA49C)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF748078)),
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
        color: Color(0xFF53635A),
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
