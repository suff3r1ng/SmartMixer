import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/app_state.dart';
import '../models/user.dart';
import '../models/device.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // Import main.dart which contains AuthPage and HomePage

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  // Timer for periodic permission checks
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();

    // Initialize admin data when the dashboard loads
    Future.microtask(() {
      final appState = Provider.of<AppState>(context, listen: false);
      _initializeAdminData(appState);
    });

    // Set up periodic permission checking
    _permissionCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        _checkAdminPermissions(appState);
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

  // Initialize admin data and fetch necessary information
  Future<void> _initializeAdminData(AppState appState) async {
    try {
      // Verify admin status directly from the database
      await appState.checkAdminStatus();

      // If user is no longer admin, redirect to home page
      if (!appState.isAdmin) {
        _redirectToHome();
        return;
      }

      // Fetch admin data
      await Future.wait([
        appState.fetchSystemStats(),
        appState.fetchAllUsers(),
        appState.fetchAllDevices(),
        appState.fetchAllLogs(),
      ]);
    } catch (e) {
      logger.e('Error initializing admin data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize admin data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Periodically check admin permissions
  Future<void> _checkAdminPermissions(AppState appState) async {
    if (!mounted) return;

    try {
      // Check if the user is still authenticated
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession == null) {
        _redirectToLogin();
        return;
      }

      // Check admin status directly from the database
      await appState.checkAdminStatus();

      // If user is no longer admin, redirect to home
      if (!appState.isAdmin) {
        _redirectToHome();
      }
    } catch (e) {
      logger.e('Error checking admin permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error checking admin permissions. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Redirect to login page if session is invalid
  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthPage()),
        (route) => false,
      );
    }
  }

  // Redirect to home if user lost admin privileges
  void _redirectToHome() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You no longer have administrator privileges'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
      ),
      body: appState.isLoading
          ? Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                AdminOverviewTab(
                  onUsersPressed: () => setState(() => _currentIndex = 2),
                  onLogsPressed: () => setState(() => _currentIndex = 3),
                ),
                AdminDevicesTab(),
                AdminUsersTab(),
                AdminLogsTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Logs'),
        ],
      ),
    );
  }
}

// Overview tab showing system statistics
class AdminOverviewTab extends StatelessWidget {
  final VoidCallback onUsersPressed;
  final VoidCallback onLogsPressed;

  const AdminOverviewTab({
    super.key,
    required this.onUsersPressed,
    required this.onLogsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final stats = appState.systemStats;

    return RefreshIndicator(
      onRefresh: () => appState.fetchSystemStats(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'System Overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 24),

            // Stats overview
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Devices',
                    value: stats['total_devices']?.toString() ?? '0',
                    icon: Icons.devices,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Total Users',
                    value: stats['total_users']?.toString() ?? '0',
                    icon: Icons.people,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Active Devices',
                    value: stats['active_devices']?.toString() ?? '0',
                    icon: Icons.power,
                    color: Colors.amber,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Manual Mode',
                    value: stats['manual_mode_devices']?.toString() ?? '0',
                    icon: Icons.touch_app,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            SizedBox(height: 32),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16),

            // Quick actions
            Card(
              child: ListTile(
                leading: Icon(Icons.people),
                title: Text('Manage Users'),
                subtitle: Text('View and edit user roles'),
                trailing: Icon(Icons.chevron_right),
                onTap: onUsersPressed,
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('View System Logs'),
                subtitle: Text('Check recent system activity'),
                trailing: Icon(Icons.chevron_right),
                onTap: onLogsPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Displays a card with a statistic
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tab for managing devices
class AdminDevicesTab extends StatelessWidget {
  const AdminDevicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => appState.fetchAllDevices(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Devices',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Device'),
                    onPressed: () => _showAddDeviceDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: appState.allDevices.length,
                  itemBuilder: (context, index) {
                    final device = appState.allDevices[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _showUserAssignmentDialog(context, device),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Device Name',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.device_hub,
                                            size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            device.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          device.isActive
                                              ? Icons.power
                                              : Icons.power_off,
                                          size: 14,
                                          color: device.isActive
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        SizedBox(width: 4),
                                        Text(device.isActive
                                            ? "Active"
                                            : "Inactive"),
                                        SizedBox(width: 8),
                                        Icon(
                                          device.mode == 'auto'
                                              ? Icons.autorenew
                                              : Icons.pan_tool,
                                          size: 14,
                                          color: device.mode == 'auto'
                                              ? Colors.blue
                                              : Colors.orange,
                                        ),
                                        SizedBox(width: 4),
                                        Text(device.mode == 'auto'
                                            ? "Auto"
                                            : "Manual"),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.perm_device_info,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'UUID: ${device.id}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.copy, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                          tooltip: 'Copy UUID',
                                          onPressed: () {
                                            Clipboard.setData(
                                                ClipboardData(text: device.id));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Device UUID copied to clipboard'),
                                              duration: Duration(seconds: 2),
                                            ));
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _showDeleteDeviceDialog(context, device);
                                    } else if (value == 'edit') {
                                      _showEditDeviceDialog(context, device);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit,
                                              size: 18, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Edit Device'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method for user assignment with checkboxes
  void _showUserAssignmentDialog(BuildContext context, Device device) {
    // Track assigned users
    List<String> assignedUserIds = [];
    String searchQuery = '';
    // Variable to track if dialog is still mounted
    bool isDialogMounted = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final appState = Provider.of<AppState>(context);

          // Load assigned users when dialog opens
          if (assignedUserIds.isEmpty) {
            // We need to fetch the user assignments asynchronously
            Future.microtask(() async {
              final userIds = await appState.getUsersForDevice(device.id);
              // Only update state if the dialog is still open
              if (userIds.isNotEmpty && isDialogMounted) {
                setState(() {
                  assignedUserIds = userIds;
                });
              }
            });
          }

          // Filter users based on search
          List<AppUser> filteredUsers = appState.users.where((user) {
            if (searchQuery.isEmpty) return true;
            return user.fullName
                        ?.toLowerCase()
                        .contains(searchQuery.toLowerCase()) ==
                    true ||
                user.email.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            // (removed onClosing callback, Dialog doesn't support that parameter)
            child: Container(
              constraints: BoxConstraints(maxWidth: 400, maxHeight: 500),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with device name and close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available on users',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Device: ${device.name}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'UUID: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      device.id,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.copy, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    tooltip: 'Copy UUID',
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: device.id));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            'Device UUID copied to clipboard'),
                                        duration: Duration(seconds: 2),
                                      ));
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            isDialogMounted = false;
                            Navigator.pop(context);
                          },
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 10),

                    // Search field for users
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // User list with checkboxes
                    Text(
                      'Select users who can access this device:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),

                    Expanded(
                      child: filteredUsers.isEmpty
                          ? Center(child: Text('No users found'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                bool hasAccess =
                                    assignedUserIds.contains(user.id);

                                return CheckboxListTile(
                                  title: Text(user.fullName ?? 'Unknown User'),
                                  subtitle: Text(
                                    user.email,
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  secondary: CircleAvatar(
                                    radius: 16,
                                    child: Text(user.fullName?.characters.first
                                            .toUpperCase() ??
                                        'U'),
                                  ),
                                  value: hasAccess,
                                  onChanged: (bool? value) async {
                                    if (value == true) {
                                      await appState.assignDeviceToUser(
                                          device.id, user.id);
                                      if (isDialogMounted) {
                                        setState(() {
                                          assignedUserIds.add(user.id);
                                        });
                                      }
                                    } else {
                                      // Now we remove just this specific user
                                      await appState.removeUserFromDevice(
                                          device.id, user.id);
                                      if (isDialogMounted) {
                                        setState(() {
                                          assignedUserIds.remove(user.id);
                                        });
                                      }
                                    }
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  dense: true,
                                );
                              },
                            ),
                    ),

                    SizedBox(height: 10),
                    Divider(),
                    SizedBox(height: 10),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            isDialogMounted = false;
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Done',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    ).then((_) {
      // Ensure flag is set to false when dialog is dismissed
      isDialogMounted = false;
    });
  }

  void _showAddDeviceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final sensorIdController = TextEditingController();
    final speedController = TextEditingController(text: '50');
    final timerController = TextEditingController(text: '0');
    String selectedMode = 'auto';
    int selectedNodeRole = 1; // Default to Coordinator

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with title and close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle,
                                color: Colors.blue, size: 24),
                            SizedBox(width: 8),
                            Text('Add New Device',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 10),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Device Name',
                                prefixIcon: Icon(Icons.device_hub),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: sensorIdController,
                              decoration: InputDecoration(
                                labelText: 'Sensor ID (Optional)',
                                prefixIcon: Icon(Icons.sensors),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(height: 24),

                            // Node Role selection
                            Row(
                              children: [
                                Icon(Icons.device_hub,
                                    size: 20, color: Colors.grey[700]),
                                SizedBox(width: 8),
                                Text(
                                  'ESP8266 Node Type:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: selectedNodeRole,
                                  underline: SizedBox(),
                                  items: [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Row(
                                        children: [
                                          Icon(Icons.sensors_outlined,
                                              color: Colors.blue, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  'Coordinator (IR Sensor & Motor)')),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Row(
                                        children: [
                                          Icon(Icons.scale,
                                              color: Colors.green, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child:
                                                  Text('Weight Sensor Node')),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Row(
                                        children: [
                                          Icon(Icons.touch_app,
                                              color: Colors.orange, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child: Text('Touch Sensor Node')),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedNodeRole = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 24),

                            // Configuration section with icon - Only show for Coordinator nodes
                            if (selectedNodeRole == 1) ...[
                              Row(
                                children: [
                                  Icon(Icons.settings,
                                      size: 20, color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Text(
                                    'Motor Configuration:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Mode selection with icons
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Row(
                                        children: [
                                          Icon(Icons.autorenew,
                                              size: 18, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Auto'),
                                        ],
                                      ),
                                      value: 'auto',
                                      groupValue: selectedMode,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMode = value!;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Row(
                                        children: [
                                          Icon(Icons.pan_tool,
                                              size: 18, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Manual'),
                                        ],
                                      ),
                                      value: 'manual',
                                      groupValue: selectedMode,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMode = value!;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Speed control with icon
                              TextField(
                                controller: speedController,
                                decoration: InputDecoration(
                                  labelText: 'Initial Speed Percentage (0-100)',
                                  prefixIcon: Icon(Icons.speed),
                                  suffixText: '%',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 16),

                              // Timer control with icon
                              TextField(
                                controller: timerController,
                                decoration: InputDecoration(
                                  labelText: 'Timer Minutes (0 = no timer)',
                                  prefixIcon: Icon(Icons.timer),
                                  suffixText: 'min',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ] else ...[
                              // Info message for sensor nodes
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Sensor Node Configuration',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'This node doesn\'t have motor control. It will connect to the network and provide sensor data.',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 24),
                            Divider(),
                            SizedBox(height: 10),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.cancel, size: 18),
                                  label: Text('Cancel'),
                                ),
                                SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final appState = Provider.of<AppState>(
                                        context,
                                        listen: false);
                                    // Parse numeric values with validation
                                    int speed = 0;
                                    int timer = 0;

                                    // Only process speed/timer for coordinator nodes
                                    if (selectedNodeRole == 1) {
                                      try {
                                        speed = int.parse(speedController.text);
                                        if (speed < 0) speed = 0;
                                        if (speed > 100) speed = 100;
                                      } catch (e) {
                                        speed = 50; // Default if parsing fails
                                      }

                                      try {
                                        timer = int.parse(timerController.text);
                                        if (timer < 0) timer = 0;
                                      } catch (e) {
                                        timer = 0; // Default if parsing fails
                                      }
                                    }

                                    appState.createDevice(
                                      name: nameController.text,
                                      sensorId:
                                          sensorIdController.text.isNotEmpty
                                              ? sensorIdController.text
                                              : null,
                                      mode: selectedNodeRole == 1
                                          ? selectedMode
                                          : 'auto',
                                      speedPercentage: speed,
                                      timerMinutes: timer,
                                      nodeRole: selectedNodeRole,
                                    );

                                    Navigator.pop(context);
                                  },
                                  icon: Icon(Icons.check_circle, size: 18),
                                  label: Text('Create'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showDeleteDeviceDialog(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and warning icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Delete Device',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 16),

                // Warning message with device info
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.device_hub,
                              size: 20, color: Colors.grey[800]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              device.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Are you sure you want to permanently delete this device? This action cannot be undone.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 10),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.cancel, size: 18),
                      label: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.delete, size: 18),
                      label: Text('Delete'),
                      onPressed: () {
                        final appState =
                            Provider.of<AppState>(context, listen: false);
                        appState.deleteDevice(device.id);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDeviceDialog(BuildContext context, Device device) {
    final nameController = TextEditingController(text: device.name);
    final sensorIdController =
        TextEditingController(text: device.sensorId ?? '');
    final speedController =
        TextEditingController(text: device.speedPercentage?.toString() ?? '50');
    final timerController =
        TextEditingController(text: device.timerMinutes?.toString() ?? '0');
    String selectedMode = device.mode;
    int selectedNodeRole =
        device.nodeRole ?? 1; // Default to Coordinator if not set

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with title and close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 24),
                            SizedBox(width: 8),
                            Text('Edit Device',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 10),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Device Name',
                                prefixIcon: Icon(Icons.device_hub),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: sensorIdController,
                              decoration: InputDecoration(
                                labelText: 'Sensor ID (Optional)',
                                prefixIcon: Icon(Icons.sensors),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            SizedBox(height: 24),

                            // Node Role selection
                            Row(
                              children: [
                                Icon(Icons.device_hub,
                                    size: 20, color: Colors.grey[700]),
                                SizedBox(width: 8),
                                Text(
                                  'ESP8266 Node Type:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: selectedNodeRole,
                                  underline: SizedBox(),
                                  items: [
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Row(
                                        children: [
                                          Icon(Icons.sensors_outlined,
                                              color: Colors.blue, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  'Coordinator (IR Sensor & Motor)')),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Row(
                                        children: [
                                          Icon(Icons.scale,
                                              color: Colors.green, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child:
                                                  Text('Weight Sensor Node')),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Row(
                                        children: [
                                          Icon(Icons.touch_app,
                                              color: Colors.orange, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child: Text('Touch Sensor Node')),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedNodeRole = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 24),

                            // Configuration section for motor control - Only for Coordinator nodes
                            if (selectedNodeRole == 1) ...[
                              Row(
                                children: [
                                  Icon(Icons.settings,
                                      size: 20, color: Colors.grey[700]),
                                  SizedBox(width: 8),
                                  Text(
                                    'Motor Configuration:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Mode selection with icons
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Row(
                                        children: [
                                          Icon(Icons.autorenew,
                                              size: 18, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Auto'),
                                        ],
                                      ),
                                      value: 'auto',
                                      groupValue: selectedMode,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMode = value!;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Row(
                                        children: [
                                          Icon(Icons.pan_tool,
                                              size: 18, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Manual'),
                                        ],
                                      ),
                                      value: 'manual',
                                      groupValue: selectedMode,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMode = value!;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Speed control with icon
                              TextField(
                                controller: speedController,
                                decoration: InputDecoration(
                                  labelText: 'Speed Percentage (0-100)',
                                  prefixIcon: Icon(Icons.speed),
                                  suffixText: '%',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: 16),

                              // Timer control with icon
                              TextField(
                                controller: timerController,
                                decoration: InputDecoration(
                                  labelText: 'Timer Minutes (0 = no timer)',
                                  prefixIcon: Icon(Icons.timer),
                                  suffixText: 'min',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ] else ...[
                              // Info message for non-coordinator nodes
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.blue),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Sensor Node Configuration',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'This node type doesn\'t have motor control. It only provides sensor data to the network.',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 16),

                            // Active status with icon (for all node types)
                            SwitchListTile(
                              title: Row(
                                children: [
                                  Icon(Icons.power_settings_new,
                                      size: 18,
                                      color: device.isActive
                                          ? Colors.green
                                          : Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Device Active'),
                                ],
                              ),
                              value: device.isActive,
                              onChanged: (value) {
                                setState(() {
                                  device = device.copyWith(isActive: value);
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 10),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.cancel, size: 18),
                          label: Text('Cancel'),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            final appState =
                                Provider.of<AppState>(context, listen: false);

                            // Parse numeric values with validation (only for coordinator nodes)
                            int speed = 0;
                            int timer = 0;

                            if (selectedNodeRole == 1) {
                              try {
                                speed = int.parse(speedController.text);
                                if (speed < 0) speed = 0;
                                if (speed > 100) speed = 100;
                              } catch (e) {
                                speed = device.speedPercentage ?? 50;
                              }

                              try {
                                timer = int.parse(timerController.text);
                                if (timer < 0) timer = 0;
                              } catch (e) {
                                timer = device.timerMinutes ?? 0;
                              }
                            }

                            // Update device details
                            appState.updateDevice(
                              deviceId: device.id,
                              name: nameController.text,
                              sensorId: sensorIdController.text.isNotEmpty
                                  ? sensorIdController.text
                                  : null,
                              mode:
                                  selectedNodeRole == 1 ? selectedMode : 'auto',
                              speedPercentage: speed,
                              timerMinutes: timer,
                              isActive: device.isActive,
                              nodeRole: selectedNodeRole,
                            );

                            Navigator.pop(context);
                          },
                          icon: Icon(Icons.check_circle, size: 18),
                          label: Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

// Tab for managing users
class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return RefreshIndicator(
      onRefresh: () => appState.fetchAllUsers(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: appState.users.length,
                itemBuilder: (context, index) {
                  final user = appState.users[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                            user.fullName?.characters.first.toUpperCase() ??
                                'U'),
                      ),
                      title: Text(user.fullName ?? 'Unknown User'),
                      subtitle: Text(user.email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.isAdmin)
                            Chip(
                              label: Text('Admin'),
                              backgroundColor: Colors.blue.shade100,
                            ),
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () => _showUserAdminDialog(
                              context,
                              user,
                              user.isAdmin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserAdminDialog(BuildContext context, AppUser user, bool isAdmin) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            color: Colors.blue, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Update User',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 10),

                // User information with icons
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            child: Text(
                                user.fullName?.characters.first.toUpperCase() ??
                                    'U'),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName ?? 'Unknown User',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined,
                                        size: 16, color: Colors.grey[700]),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Admin status switch with icon
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      'Admin Status:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Switch(
                      value: isAdmin,
                      onChanged: (value) {
                        final appState =
                            Provider.of<AppState>(context, listen: false);
                        appState.updateUserAdminStatus(user.id, value);
                        Navigator.pop(context);
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 10),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.cancel, size: 18),
                      label: Text('Cancel'),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.check_circle, size: 18),
                      label: Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Tab for viewing system logs
class AdminLogsTab extends StatefulWidget {
  const AdminLogsTab({super.key});

  @override
  _AdminLogsTabState createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  // Filtering options
  String _selectedLogType = 'All';
  String _selectedDeviceId = 'All';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  // Sorting
  String _sortCriteria = 'newest';

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Filter logs based on criteria
    List filteredLogs = appState.allLogs.where((log) {
      // Apply type filter
      if (_selectedLogType != 'All' &&
          !log.action.toLowerCase().contains(_selectedLogType.toLowerCase())) {
        return false;
      }

      // Apply device filter
      if (_selectedDeviceId != 'All' && log.deviceId != _selectedDeviceId) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty &&
          !log.action.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !(log.deviceId?.toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase()) &&
          !log.userId.toString().contains(_searchQuery)) {
        return false;
      }

      // Apply date range
      if (_startDate != null && log.timestamp.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && log.timestamp.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    if (_sortCriteria == 'newest') {
      filteredLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else if (_sortCriteria == 'oldest') {
      filteredLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } else if (_sortCriteria == 'deviceId') {
      filteredLogs.sort((a, b) => a.deviceId.compareTo(b.deviceId));
    }

    // Get unique device IDs for filtering
    final deviceIds = ['All', ...appState.allDevices.map((d) => d.id)];
    final logTypes = [
      'All',
      'Connect',
      'Disconnect',
      'Speed Change',
      'Mode Change',
      'Error',
      'Timer'
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => appState.fetchAllLogs(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with title and export button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'System Logs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.download),
                    label: Text('Export Logs'),
                    onPressed: () => _exportLogs(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Search and filter row
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Filter Logs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),
                        TextButton.icon(
                          icon: Icon(Icons.clear_all, size: 18),
                          label: Text('Clear Filters'),
                          onPressed: () => setState(() {
                            _selectedLogType = 'All';
                            _selectedDeviceId = 'All';
                            _searchQuery = '';
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search field
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search logs...',
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                    SizedBox(height: 16),

                    // Filters row
                    Row(
                      children: [
                        // Log type filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Action Type',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            value: _selectedLogType,
                            items: logTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child:
                                    Text(type, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedLogType = value!;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 16),

                        // Device filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Device',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            value: _selectedDeviceId,
                            items: deviceIds.map((deviceId) {
                              // Find device name if possible
                              String label = deviceId;
                              if (deviceId != 'All') {
                                final device = appState.allDevices.firstWhere(
                                    (d) => d.id == deviceId,
                                    orElse: () => Device(
                                        id: deviceId,
                                        name: deviceId,
                                        mode: 'auto',
                                        isActive: false));
                                label = device.name;
                              }

                              return DropdownMenuItem(
                                value: deviceId,
                                child: Text(label,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDeviceId = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Date range selector
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.date_range),
                            label: Text(_startDate != null
                                ? 'From: ${_startDate!.toLocal().toString().split(' ')[0]}'
                                : 'Start Date'),
                            onPressed: () => _selectDate(context, true),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.date_range),
                            label: Text(_endDate != null
                                ? 'To: ${_endDate!.toLocal().toString().split(' ')[0]}'
                                : 'End Date'),
                            onPressed: () => _selectDate(context, false),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Sort options
                    Row(
                      children: [
                        Text('Sort by: ',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Newest'),
                          selected: _sortCriteria == 'newest',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _sortCriteria = 'newest');
                            }
                          },
                        ),
                        SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Oldest'),
                          selected: _sortCriteria == 'oldest',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _sortCriteria = 'oldest');
                            }
                          },
                        ),
                        SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Device'),
                          selected: _sortCriteria == 'deviceId',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _sortCriteria = 'deviceId');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Log count and clear logs button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredLogs.length} log entries',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(
                      'Clear All Logs',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => _showClearLogsDialog(context),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Logs list
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sentiment_dissatisfied,
                                size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No logs match your filters',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _selectedLogType = 'All';
                                _selectedDeviceId = 'All';
                                _searchQuery = '';
                                _startDate = null;
                                _endDate = null;
                              }),
                              child: Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];

                          // Determine log severity for color coding
                          Color logColor = Colors.blue;
                          IconData logIcon = Icons.info_outline;

                          if (log.action.toLowerCase().contains('error')) {
                            logColor = Colors.red;
                            logIcon = Icons.error_outline;
                          } else if (log.action
                              .toLowerCase()
                              .contains('warning')) {
                            logColor = Colors.orange;
                            logIcon = Icons.warning_amber_outlined;
                          } else if (log.action
                              .toLowerCase()
                              .contains('connect')) {
                            logColor = Colors.green;
                            logIcon = Icons.link;
                          } else if (log.action
                              .toLowerCase()
                              .contains('disconnect')) {
                            logColor = Colors.grey;
                            logIcon = Icons.link_off;
                          } else if (log.action
                              .toLowerCase()
                              .contains('speed')) {
                            logColor = Colors.purple;
                            logIcon = Icons.speed;
                          } else if (log.action
                              .toLowerCase()
                              .contains('mode')) {
                            logColor = Colors.teal;
                            logIcon = Icons.sync_alt;
                          } else if (log.action
                              .toLowerCase()
                              .contains('timer')) {
                            logColor = Colors.amber;
                            logIcon = Icons.timer;
                          }

                          // Find device name
                          String deviceName = log.deviceId;
                          final device = appState.allDevices.firstWhere(
                              (d) => d.id == log.deviceId,
                              orElse: () => Device(
                                  id: log.deviceId,
                                  name: 'Unknown Device',
                                  mode: 'auto',
                                  isActive: false));
                          if (device.name != log.deviceId) {
                            deviceName = device.name;
                          }

                          // Find user name if available
                          String userName = log.userId ?? '';
                          if (log.userId != null) {
                            final user = appState.users.firstWhere(
                                (u) => u.id == log.userId,
                                orElse: () => AppUser(
                                    id: log.userId ?? '',
                                    email: '',
                                    isAdmin: false,
                                    createdAt: DateTime.now()));
                            userName = user.fullName ?? user.email;
                          }

                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.grey[200]!, width: 1),
                            ),
                            child: InkWell(
                              onTap: () => _showLogDetails(
                                  context, log, deviceName, userName),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: logColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(logIcon,
                                          color: logColor, size: 24),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.action,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Device: $deviceName',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          if (userName.isNotEmpty)
                                            Text(
                                              'User: $userName',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              SizedBox(width: 4),
                                              Text(
                                                _formatDateTime(log.timestamp),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final logDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String prefix = '';
    if (logDate == today) {
      prefix = 'Today';
    } else if (logDate == yesterday) {
      prefix = 'Yesterday';
    } else {
      prefix = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    return '$prefix at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // If end date is before start date, update it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(Duration(days: 1));
          }
        } else {
          _endDate = picked;
          // If start date is after end date, update it
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate!.subtract(Duration(days: 1));
          }
        }
      });
    }
  }

  void _showLogDetails(
      BuildContext context, dynamic log, String deviceName, String userName) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 16),
                _detailRow('Action', log.action),
                _detailRow('Device ID', log.deviceId),
                _detailRow('Device Name', deviceName),
                if (log.userId != null) _detailRow('User ID', log.userId),
                if (userName.isNotEmpty) _detailRow('User Name', userName),
                _detailRow('Timestamp', log.timestamp.toLocal().toString()),
                if (log.details != null && log.details.isNotEmpty)
                  _detailRow('Additional Info', log.details),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.content_copy, size: 18),
                      label: Text('Copy Details'),
                      onPressed: () {
                        // Copy log details to clipboard
                        final details = 'Log Details:\n'
                                'Action: ${log.action}\n'
                                'Device: $deviceName (${log.deviceId})\n' +
                            'User: $userName (${log.userId ?? 'N/A'})\n' +
                            'Timestamp: ${log.timestamp.toLocal().toString()}\n' +
                            'Details: ${log.details ?? 'N/A'}';

                        Clipboard.setData(ClipboardData(text: details));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Log details copied to clipboard')));
                      },
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.close, size: 18),
                      label: Text('Close'),
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 2),
          Text(
            value?.toString() ?? 'N/A',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showClearLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Clear All Logs',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 16),
                Text(
                  'Are you sure you want to clear all system logs? This action cannot be undone.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.delete_forever, size: 18),
                      label: Text('Clear All'),
                      onPressed: () {
                        final appState =
                            Provider.of<AppState>(context, listen: false);
                        appState.clearAllLogs();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportLogs(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    // Show options dialog for export
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download_rounded, color: Colors.blue, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Export Logs',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Divider(),
                SizedBox(height: 16),
                Text(
                  'Choose export format:',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    // Use the AppState service to export logs as CSV
                    appState.exportLogsAsCSV();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logs exported as CSV file')));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description, color: Colors.green),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CSV Format',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Export as comma-separated values file',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    // Use the AppState service to export logs as JSON
                    appState.exportLogsAsJSON();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logs exported as JSON file')));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.data_object, color: Colors.blue),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JSON Format',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Export as structured JSON data',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
