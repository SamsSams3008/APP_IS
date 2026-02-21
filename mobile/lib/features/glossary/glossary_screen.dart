import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';
import 'glossary_data.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _query = '';

  List<GlossaryEntry> _filtered(String locale) =>
      glossaryEntries.values
          .where((e) {
            final t = getGlossaryTitle(e.id, locale);
            final d = getGlossaryDescription(e.id, locale);
            final q = _query.toLowerCase();
            return t.toLowerCase().contains(q) || d.toLowerCase().contains(q);
          })
          .toList();

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.current;
    final list = _filtered(locale);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
        title: Text(AppStrings.t('glossary_title', locale)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: AppStrings.t('search_hint', locale),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? AppStrings.t('no_entries', locale) : '${AppStrings.t('no_results_for', locale)} "$_query"',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final e = list[i];
                      final cs = Theme.of(context).colorScheme;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.primary.withValues(alpha: 0.08),
                                cs.tertiary.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/dashboard/metric/${e.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              cs.primary.withValues(alpha: 0.25),
                                              cs.tertiary.withValues(alpha: 0.2),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(e.icon, color: cs.primary, size: 24),
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        getGlossaryTitle(e.id, locale),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  getGlossaryDescription(e.id, locale),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
