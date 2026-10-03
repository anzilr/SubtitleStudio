part of '../settings_sheet.dart';

extension _SettingsSupportSection on _SettingsSheetState {
  Widget _buildSupportSection() {
    return Column(
      children: [
        // Feedback Section with ExpansionTile
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // Remove internal dividers
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.feedback, color: Colors.blue),
            title: const Text('Send Feedback'),
            subtitle: const Text('Report bugs, suggest features, or share your thoughts'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            children: [
              const FeedbackWidget(),
            ],
          ),
        ),
        
        // Logging Section with cleaner ExpansionTile
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // Remove internal dividers
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('Logging'),
            subtitle: const Text('Manage app logs and debugging information'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            children: [
              const LogManagementWidget(),
            ],
          ),
        ),
        
        const Divider(),
        
        // Check for Updates
        ListTile(
          leading: const Icon(Icons.system_update, color: Colors.green),
          title: const Text('Check for Updates'),
          subtitle: const Text('Check for new app versions'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _checkForUpdates(),
        ),
        
        // Help & Documentation
        ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.teal),
          title: const Text('Help & Documentation'),
          subtitle: const Text('Learn how to use Subtitle Studio'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpScreen()),
            );
          },
        ),
        
        // Add more settings here as needed
      ],
    );
  }
}
