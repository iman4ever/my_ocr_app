// empty
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/receipt_provider.dart';

class SettingsScreen extends StatefulWidget {
	const SettingsScreen({Key? key}) : super(key: key);

	@override
	State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
	void _showLanguageSelector() async {
		final languageProvider = context.read<LanguageProvider>();
		final currentLanguage = languageProvider.language;

		final selected = await showModalBottomSheet<String>(
			context: context,
			builder: (context) {
				return SafeArea(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							ListTile(title: Text('Select Language', style: Theme.of(context).textTheme.titleMedium)),
							RadioListTile<String>(
								value: 'en',
								groupValue: currentLanguage,
								title: const Text('English'),
								onChanged: (v) => Navigator.of(context).pop(v),
							),
							RadioListTile<String>(
								value: 'fr',
								groupValue: currentLanguage,
								title: const Text('French'),
								onChanged: (v) => Navigator.of(context).pop(v),
							),
							RadioListTile<String>(
								value: 'ar',
								groupValue: currentLanguage,
								title: const Text('Arabic'),
								onChanged: (v) => Navigator.of(context).pop(v),
							),
						],
					),
				);
			},
		);

		if (selected != null && selected != currentLanguage) {
			context.read<LanguageProvider>().setLanguage(selected);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Settings'),
				centerTitle: true,
				elevation: 0,
			),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					const SizedBox(height: 8),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
						child: Text('General', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
					),
					Card(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								SwitchListTile.adaptive(
									title: const Text('Dark Mode'),
									secondary: const Icon(Icons.brightness_6),
							value: context.watch<ThemeProvider>().isDarkMode,
							onChanged: (v) => context.read<ThemeProvider>().setDarkMode(v),
								),
								ListTile(
									leading: const Icon(Icons.language),
									title: const Text('Language'),
									subtitle: Text(context.watch<LanguageProvider>().displayName),
									trailing: const Icon(Icons.chevron_right),
									onTap: _showLanguageSelector,
								),
							],
						),
					),

					const SizedBox(height: 16),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
						child: Text('Privacy & Security', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
					),
					Card(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								ListTile(
									leading: const Icon(Icons.data_usage),
									title: const Text('Data Collected'),
									trailing: const Icon(Icons.chevron_right),
									onTap: () => showDialog(
										context: context,
										builder: (_) => const AlertDialog(
											title: Text('Data Collected'),
											content: Text('Information about the data collected by the app.'),
										),
									),
								),
								ListTile(
									leading: const Icon(Icons.bar_chart),
									title: const Text('Data Usage'),
									trailing: const Icon(Icons.chevron_right),
									onTap: () => showDialog(
										context: context,
										builder: (_) => const AlertDialog(
											title: Text('Data Usage'),
											content: Text('How collected data is used and processed.'),
										),
									),
								),
								ListTile(
									leading: const Icon(Icons.security),
									title: const Text('Security Measures'),
									trailing: const Icon(Icons.chevron_right),
									onTap: () => showDialog(
										context: context,
										builder: (_) => const AlertDialog(
											title: Text('Security Measures'),
											content: Text('Overview of security practices and protections.'),
										),
									),
								),
								ListTile(
									leading: const Icon(Icons.perm_device_info),
									title: const Text('Permissions'),
									trailing: const Icon(Icons.chevron_right),
									onTap: () => showDialog(
										context: context,
										builder: (_) => const AlertDialog(
											title: Text('Permissions'),
											content: Text('Permissions the app requests and why they are needed.'),
										),
									),
								),
								ListTile(
									leading: const Icon(Icons.settings_applications),
									title: const Text('User Control'),
									trailing: const Icon(Icons.chevron_right),
									onTap: () {
										showModalBottomSheet<void>(
											context: context,
											builder: (ctx) {
												return SafeArea(
													child: Column(
														mainAxisSize: MainAxisSize.min,
														children: [
															ListTile(
																leading: const Icon(Icons.delete_forever),
																title: const Text('Clear Local Data'),
																subtitle: const Text('Remove all locally stored receipts'),
																onTap: () async {
																final confirm = await showDialog<bool>(
																	context: context,
																	builder: (_) => AlertDialog(
																		title: const Text('Confirm Clear Data'),
																		content: const Text('This will permanently delete all local receipts. Continue?'),
																		actions: [
																			TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
																			TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
																		],
																),
																);
																if (confirm == true) {
																	try {
																		await context.read<ReceiptProvider>().clearAllReceipts();
																		ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local data cleared')));
																	} catch (e) {
																		ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to clear local data')));
																	}
																}
																Navigator.of(ctx).pop();
															},
															),
															ListTile(
																leading: const Icon(Icons.restart_alt),
																title: const Text('Reset Preferences'),
																subtitle: const Text('Restore default app settings (language, theme)'),
																onTap: () async {
																final confirm = await showDialog<bool>(
																	context: context,
																	builder: (_) => AlertDialog(
																		title: const Text('Confirm Reset Preferences'),
																		content: const Text('This will reset language and theme preferences to defaults.'),
																		actions: [
																			TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
																			TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
																		],
																),
																);
																if (confirm == true) {
																	await context.read<LanguageProvider>().setLanguage('en');
																	await context.read<ThemeProvider>().setDarkMode(false);
																	ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences reset')));
																}
																Navigator.of(ctx).pop();
															},
															),
														],
														),
													);
											},
										);
									},
								),
							],
						),
					),

					const SizedBox(height: 24),

					// Additional static settings or info can go here
					Card(
						child: Column(
							children: [
								ListTile(
									leading: const Icon(Icons.info_outline),
									title: const Text('About'),
									subtitle: const Text('Learn more about this app'),
									onTap: () => showAboutDialog(
										context: context,
										applicationName: 'My OCR App',
										applicationVersion: '1.0.0',
										applicationLegalese: '© 2025 My OCR App',
									),
								),
								const Divider(height: 0),
							],
						),
					),

  
				],
			),
		);
	}
}
