import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';

/// A screen that a later build step will replace.
class ScreenLink {
  const ScreenLink(this.label, this.route, {this.icon = Icons.open_in_new_rounded});

  final String label;
  final String route;
  final IconData icon;
}

/// Styled "Coming in next step" page with the real header (the shell adds the
/// bottom bar). [links] open the other screens of the module so every route
/// can already be reached.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.prompt,
    this.links = const [],
    this.homeHeader = false,
    this.filter,
  });

  final String title;
  final String subtitle;
  final int prompt;
  final List<ScreenLink> links;
  final bool homeHeader;

  /// Query the screen was opened with (e.g. "tab=mine"), shown until the real screen applies it.
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final promptLabel = 'Prompt ${prompt.toString().padLeft(2, '0')}';
    final canPop = GoRouter.of(context).canPop();
    return AppScaffold(
      header: homeHeader ? const HomeHeader(showProduct: true) : null,
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            title: title,
            subtitle: subtitle,
            help:
                '$title is part of the Asset360 demo. The full screen, matching the design, '
                'is built in $promptLabel. Until then this page lets you check that navigation works.',
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.construction_rounded, color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Coming in next step', style: AppText.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'This screen is built in $promptLabel.',
                  textAlign: TextAlign.center,
                  style: AppText.secondary.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 14),
                StatusChip(promptLabel, tone: ChipTone.purple, icon: Icons.schedule_rounded),
                if (filter != null) ...[
                  const SizedBox(height: 8),
                  StatusChip('Opened with: $filter', tone: ChipTone.blue, icon: Icons.filter_alt_rounded),
                ],
              ],
            ),
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Screens in this module',
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Column(
                children: [
                  for (final l in links)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconSquare(icon: l.icon, tone: TileTone.lavender, size: 36),
                      title: Text(l.label, style: AppText.bodyStrong),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () => context.push(l.route),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (canPop)
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Go Back'),
            )
          else if (Routes.tabRootOf(GoRouterState.of(context).uri.path) != Routes.home)
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.home),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Go to Home'),
            ),
        ],
      ),
    );
  }
}
