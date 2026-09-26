import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../models/business_profile.dart';
import '../../models/print_settings.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/page_header.dart';
import '../../widgets/toast.dart';
import '../../widgets/ui_kit.dart';
import 'business_profile_controller.dart';
import 'print_settings_controller.dart';

/// Business details and how printing behaves. The business profile is the only
/// place the pharmacy's own name is typed, because it is what every printed
/// invoice carries in the header.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _tin;

  /// Set once the user types, so a late load cannot overwrite their work.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _address = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _tin = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _tin.dispose();
    super.dispose();
  }

  /// The stored profile arrives after the first frame, so the fields are filled
  /// from it whenever it differs and the user has not started typing.
  void _seed(BusinessProfile profile) {
    if (_dirty) return;
    _name.text = profile.name;
    _address.text = profile.address;
    _phone.text = profile.phone;
    _email.text = profile.email;
    _tin.text = profile.tin;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(businessProfileProvider.notifier).save(
          BusinessProfile(
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            tin: _tin.text.trim(),
          ),
        );
    _dirty = false;
    if (mounted) toast(context, 'Business details saved.');
  }

  /// The pharmacy's own details, laid out one field per line except the phone
  /// and email, which share a row when the window is wide enough to hold them.
  Widget _profileForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Business name',
              hintText: 'PFA Pharmacy',
            ),
            onChanged: (_) => _dirty = true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'Street, town',
            ),
            onChanged: (_) => _dirty = true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: Insets.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final phone = TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                ),
                onChanged: (_) => _dirty = true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              );
              final email = TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                onChanged: (_) => _dirty = true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  children: <Widget>[
                    phone,
                    const SizedBox(height: Insets.md),
                    email,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: phone),
                  const SizedBox(width: Insets.md),
                  Expanded(child: email),
                ],
              );
            },
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _tin,
            decoration: const InputDecoration(
              labelText: 'TIN',
              helperText: 'Shown after the address when filled in',
            ),
            onChanged: (_) => _dirty = true,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);
    final printSettings = ref.watch(printSettingsProvider);
    _seed(profile);

    final saveButton = FilledButton.icon(
      onPressed: _saveProfile,
      icon: const Icon(Icons.save_outlined),
      label: const Text('Save details'),
    );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: Insets.huge),
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: PageHeader(
              title: 'Settings',
              subtitle: 'Your details on every printed invoice',
              icon: Icons.tune,
              accentIndex: 4,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              actions: <Widget>[saveButton],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.lg, Insets.xxl, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 70),
              child: SectionCard(
                title: 'Business details',
                subtitle: 'Printed at the top of the invoice. Leave a field '
                    'blank and it is left off the page.',
                icon: Icons.storefront_outlined,
                accentIndex: 0,
                children: <Widget>[
                  _profileForm(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: saveButton,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.lg, Insets.xxl, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 130),
              child: SectionCard(
                title: 'Printing',
                subtitle: 'Which layout the Print button uses. "Ask each time" '
                    'opens the picker every time you print.',
                icon: Icons.print_outlined,
                accentIndex: 1,
                children: <Widget>[
                  _LayoutChoice(
                    settings: printSettings,
                    onChanged: (layout) => ref
                        .read(printSettingsProvider.notifier)
                        .setDefaultLayout(layout),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xxl, Insets.lg, Insets.xxl, 0),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 190),
              child: SectionCard(
                title: 'Data',
                subtitle: 'Everything is stored on this PC only.',
                icon: Icons.lock_outline,
                accentIndex: 2,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Back to invoices'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The print layouts, each one a row you press, with the chosen one lit up.
class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({required this.settings, required this.onChanged});

  final PrintSettings settings;
  final ValueChanged<InvoicePrintLayout?> onChanged;

  static const Map<InvoicePrintLayout?, IconData> _icons =
      <InvoicePrintLayout?, IconData>{
    null: Icons.help_outline,
    InvoicePrintLayout.classicForm: Icons.description_outlined,
    InvoicePrintLayout.splitLedger: Icons.view_column_outlined,
    InvoicePrintLayout.paymentVoucher: Icons.receipt_long_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _option(
          context,
          'Ask each time',
          'Open the layout picker when you print. Nothing is remembered.',
          null,
        ),
        for (final layout in InvoicePrintLayout.values)
          _option(context, layout.label, layout.blurb, layout),
      ],
    );
  }

  Widget _option(
    BuildContext context,
    String label,
    String blurb,
    InvoicePrintLayout? value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final selected = settings.defaultLayout == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.10)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  _icons[value],
                  size: 20,
                  color: selected ? scheme.primary : null,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: texts.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        blurb,
                        style: texts.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
