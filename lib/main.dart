import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'dart:async'; // Add Timer import
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/device.dart';
import 'services/app_state.dart';
import 'screens/admin_dashboard.dart';
import 'config/supabase_config.dart';
import 'package:flutter/services.dart'; // Add Clipboard import

// Initialize logger
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables from .env file
    await dotenv.load();

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    runApp(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: MyApp(),
      ),
    );
  } catch (e) {
    logger.e('Failed to initialize Supabase: $e');
    // Show error UI or handle initialization failure
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app. Please try again later.'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartMixer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  final adminCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isLogin = true;
  bool _showAdminField = false;

  // Admin code to verify admin registration - should ideally be stored securely
  final String _adminSecretCode = "admin1234";

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    adminCodeController.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _setLoading(true);
    _setError('');

    try {
      if (_isLogin) {
        await _signIn();
      } else {
        await _signUp();
      }
    } catch (e) {
      _setError('Authentication error: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signIn() async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (res.session != null) {
        // Get the AppState instance
        final appState = Provider.of<AppState>(context, listen: false);

        // First initialize to fetch the user profile data
        await appState.initialize();

        // Then check admin status and fetch devices
        await appState.checkAdminStatus();
        await appState.fetchDevices();

        print(
            'Login successful. User: ${res.user?.id}, Admin status: ${appState.isAdmin}');
        _navigateToHome();
      } else {
        _setError('Login failed. Please check your credentials.');
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred.');
      print('Error during sign in: $e');
    }
  }

  Future<void> _signUp() async {
    try {
      // Check admin code if admin field is shown
      bool isAdmin = false;
      if (_showAdminField) {
        if (adminCodeController.text.trim() != _adminSecretCode) {
          _setError('Invalid admin code. Please try again.');
          return;
        }
        isAdmin = true;
      }

      final res = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (res.user != null) {
        // Create profile for the new user with admin status if applicable
        await Supabase.instance.client.from('profiles').insert({
          'id': res.user!.id,
          'email': emailController.text.trim(),
          'full_name': fullNameController.text.trim(),
          'is_admin': isAdmin,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        _navigateToHome();
      } else {
        _setError('Registration failed. Please try again.');
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred.');
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Create Account'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/App Name
                  Icon(
                    Icons.cyclone,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'SmartMixer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 32),

                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  // Email field
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Full Name field (only for registration)
                  if (!_isLogin)
                    TextFormField(
                      controller: fullNameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Full Name is required';
                        }
                        return null;
                      },
                    ),
                  SizedBox(height: 16),

                  // Admin Code field (only for registration)
                  if (!_isLogin && _showAdminField)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: adminCodeController,
                          decoration: InputDecoration(
                              labelText: "Admin Code",
                              prefixIcon: Icon(Icons.security),
                              hintText: "Enter admin verification code"),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Admin Code is required';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 8),
                        Text(
                          "You're registering as an administrator",
                          style: TextStyle(
                            color: Colors.blue,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 24),

                  // Login/Register button
                  _isLoading
                      ? Center(
                          child: SpinKitCircle(
                            color: Theme.of(context).primaryColor,
                            size: 40,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _authenticate,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isLogin ? 'Login' : 'Register',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                  SizedBox(height: 16),

                  // Switch between login/register
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = '';
                        _showAdminField = false;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Need an account? Register'
                          : 'Already have an account? Login',
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Toggle admin field
                  if (!_isLogin)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showAdminField = !_showAdminField;
                        });
                      },
                      child: Text(
                        _showAdminField
                            ? 'Not an admin? Register as user'
                            : 'Register as admin',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Timer for periodic permission checks
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    // Fetch devices when page loads
    Future.microtask(() {
      final appState = Provider.of<AppState>(context, listen: false);
      _initializeUserData(appState);
    });

    // Set up periodic permission checking
    _permissionCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        _checkUserPermissions(appState);
      } else {
        timer.cancel(); // Cancel timer if widget is not mounted
      }
    });
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    _permissionCheckTimer = null;
    super.dispose();
  }

  // Initialize user data and fetch necessary information
  Future<void> _initializeUserData(AppState appState) async {
    try {
      // First reinitialize to make sure we have the latest user data from the database
      await appState.initialize();

      // Then check admin status directly from the database (not relying on session)
      await appState.checkAdminStatus();

      // Finally fetch the appropriate devices
      await appState.fetchDevices();
    } catch (e) {
      logger.e('Error initializing user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize user data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Periodically check user permissions to ensure they're current
  Future<void> _checkUserPermissions(AppState appState) async {
    if (!mounted) return;

    try {
      // Check if the user is still authenticated
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession == null) {
        // Session expired, redirect to login
        _redirectToLogin();
        return;
      }

      // Fetch the latest user profile data directly from the database
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _redirectToLogin();
        return;
      }

      // Check admin status directly from the database
      await appState.checkAdminStatus();
    } catch (e) {
      logger.e('Error checking user permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking permissions. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Redirect to login page if session is invalid or permissions changed
  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Device Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => appState.fetchDevices(),
            tooltip: 'Refresh devices',
          ),
          if (appState.isAdmin)
            IconButton(
              icon: Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AdminDashboard()),
                );
              },
              tooltip: 'Admin Dashboard',
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => AuthPage()),
                (route) => false,
              );
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: appState.isLoading
          ? Center(
              child: SpinKitCircle(
                color: Theme.of(context).primaryColor,
                size: 50,
              ),
            )
          : appState.errorMessage.isNotEmpty
              ? _buildErrorView(appState)
              : _buildDeviceList(appState),
    );
  }

  Widget _buildErrorView(AppState appState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          SizedBox(height: 16),
          Text(
            appState.errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              appState.clearError();
              appState.fetchDevices();
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(AppState appState) {
    if (appState.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.fetchDevices(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: appState.devices.length,
        itemBuilder: (context, index) {
          final device = appState.devices[index];
          return DeviceCard(device: device);
        },
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Device device;

  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final bool isActive = device.isActive;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DeviceDetailPage(deviceId: device.id)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(isActive ? 'Active' : 'Inactive'),
                    backgroundColor: isActive
                        ? Colors.green.withAlpha(51) // ~0.2 opacity (51/255)
                        : Colors.red.withAlpha(51), // ~0.2 opacity (51/255)
                    labelStyle: TextStyle(
                      color: isActive
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Show mode (auto/manual)
              Row(
                children: [
                  Icon(
                    device.mode == 'auto' ? Icons.autorenew : Icons.pan_tool,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Mode: ${device.mode == 'auto' ? 'Automatic' : 'Manual'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Add UUID display and copy button
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.perm_device_info,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'UUID: ${device.id}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    child: Icon(Icons.copy, size: 16, color: Colors.blue),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: device.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Device UUID copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Provider.of<AppState>(context, listen: false)
                          .toggleDeviceActive(device.id, !isActive);
                    },
                    child: Text(isActive ? 'Deactivate' : 'Activate'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DeviceDetailPage(deviceId: device.id)));
                    },
                    child: Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceDetailPage extends StatefulWidget {
  final String deviceId;

  const DeviceDetailPage({super.key, required this.deviceId});

  @override
  _DeviceDetailPageState createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load device details
    Future.microtask(() {
      Provider.of<AppState>(context, listen: false)
          .selectDevice(widget.deviceId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final device = appState.selectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: Text(device?.name ?? 'Device Details'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Control', icon: Icon(Icons.tune)),
            Tab(text: 'Status', icon: Icon(Icons.info_outline)),
            Tab(text: 'Activity', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: appState.isLoading
          ? Center(
              child: SpinKitCircle(
                color: Theme.of(context).primaryColor,
                size: 50,
              ),
            )
          : device == null
              ? Center(child: Text('Device not found'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    DeviceControlTab(device: device),
                    DeviceStatusTab(device: device),
                    DeviceActivityTab(),
                  ],
                ),
    );
  }
}

class DeviceControlTab extends StatefulWidget {
  final Device device;

  const DeviceControlTab({super.key, required this.device});

  @override
  _DeviceControlTabState createState() => _DeviceControlTabState();
}

class _DeviceControlTabState extends State<DeviceControlTab> {
  String _selectedMode = 'auto';
  bool _motorOn = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.device.mode;
    _motorOn = widget.device.status?.motorOn ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Check if this is a coordinator node (nodeRole == 1)
    final bool isCoordinatorNode = widget.device.nodeRole == 1;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active toggle
          SwitchListTile(
            title: Text('Device Active'),
            subtitle: Text(widget.device.isActive
                ? 'Device is currently active'
                : 'Device is currently inactive'),
            value: widget.device.isActive,
            onChanged: (value) {
              appState.toggleDeviceActive(widget.device.id, value);
            },
          ),

          Divider(),

          // Display node role information with null check
          ListTile(
            title: Text('Node Type'),
            subtitle:
                Text(_getNodeTypeDescription(widget.device.nodeRole ?? 0)),
            leading: Icon(_getNodeTypeIcon(widget.device.nodeRole)),
          ),

          // Only show mode selector and motor control for coordinator nodes
          if (isCoordinatorNode) ...[
            Divider(),

            // Mode selector
            Text(
              'Operating Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('Auto'),
                    value: 'auto',
                    groupValue: _selectedMode,
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value!;
                      });
                      appState.setDeviceMode(widget.device.id, value!);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('Manual'),
                    value: 'manual',
                    groupValue: _selectedMode,
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value!;
                      });
                      appState.setDeviceMode(widget.device.id, value!);
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Manual controls (only enabled in manual mode)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motor Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.cyclone,
                            size: 60,
                            color: _motorOn && _selectedMode == 'manual'
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon:
                                Icon(_motorOn ? Icons.power_off : Icons.power),
                            label: Text(_motorOn ? 'Turn Off' : 'Turn On'),
                            onPressed: _selectedMode == 'manual' &&
                                    widget.device.isActive
                                ? () {
                                    setState(() {
                                      _motorOn = !_motorOn;
                                    });

                                    // Update device status
                                    appState.updateDeviceStatus(
                                      widget.device.id,
                                      _motorOn,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _motorOn ? Colors.red : Colors.green,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _selectedMode == 'auto'
                                ? 'Switch to Manual mode to control motor'
                                : widget.device.isActive
                                    ? 'Click button to control motor'
                                    : 'Activate device to control motor',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Show sensor-specific info for non-coordinator nodes
            SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _getNodeTypeIcon(widget.device.nodeRole),
                      size: 60,
                      color: widget.device.isActive ? Colors.blue : Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'This is a ${_getNodeTypeDescription(widget.device.nodeRole)} node',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Motor control is only available for coordinator nodes',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to get node type description
  String _getNodeTypeDescription(int? nodeRole) {
    switch (nodeRole) {
      case 1:
        return 'Coordinator (IR Sensor)';
      case 2:
        return 'Weight Sensor';
      case 3:
        return 'Touch Sensor';
      default:
        return 'Unknown';
    }
  }

  // Helper method to get appropriate icon for node type
  IconData _getNodeTypeIcon(int? nodeRole) {
    switch (nodeRole) {
      case 1:
        return Icons.settings_remote;
      case 2:
        return Icons.scale;
      case 3:
        return Icons.touch_app;
      default:
        return Icons.device_unknown;
    }
  }
}

class DeviceStatusTab extends StatelessWidget {
  final Device device;

  const DeviceStatusTab({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final status = device.status;
    final lastUpdated = status?.updatedAt ?? DateTime.now();

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // Status card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatusRow(
                      'Device State',
                      device.isActive ? 'Active' : 'Inactive',
                      device.isActive ? Colors.green : Colors.red),
                  Divider(),
                  _buildStatusRow('Operating Mode',
                      device.mode == 'auto' ? 'Automatic' : 'Manual', null),
                  Divider(),
                  _buildStatusRow(
                      'Motor',
                      status?.motorOn ?? false ? 'Running' : 'Stopped',
                      status?.motorOn ?? false ? Colors.green : Colors.grey),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Device information with UUID
          Text(
            'Device Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text('Device Name'),
                    trailing: Text(device.name),
                  ),
                  Divider(),
                  ListTile(
                    title: Text('Device UUID'),
                    subtitle: Text(
                      device.id,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.copy, color: Colors.blue),
                      tooltip: 'Copy UUID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: device.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Device UUID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(),
                  ListTile(
                    title: Text('Sensor ID'),
                    trailing: Text(device.sensorId ?? 'Not assigned'),
                  ),
                  Divider(),
                  ListTile(
                    title: Text('Last Updated'),
                    trailing: Text(
                        '${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year} ${lastUpdated.hour}:${lastUpdated.minute.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Refresh Status'),
              onPressed: () {
                Provider.of<AppState>(context, listen: false)
                    .selectDevice(device.id);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String title, String value, Color? valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceActivityTab extends StatelessWidget {
  const DeviceActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final logs = appState.deviceLogs;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No activity logs found',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => appState.refreshLogs(),
              child: Text('Refresh Logs'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => appState.refreshLogs(),
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: Icon(_getLogIcon(log.action)),
              title: Text(log.action),
              subtitle: Text(_formatDateTime(log.timestamp)),
            ),
          );
        },
      ),
    );
  }

  IconData _getLogIcon(String action) {
    if (action.contains('activated')) return Icons.check_circle;
    if (action.contains('deactivated')) return Icons.cancel;
    if (action.contains('Mode')) return Icons.settings;
    if (action.contains('Motor turned on')) return Icons.play_circle;
    if (action.contains('Motor turned off')) return Icons.stop_circle;
    return Icons.history;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
