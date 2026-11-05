import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Heart, "Add to Favorites" switch, Favorite Group (+ New group…) and Notes → Save to Favorites.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

const _newGroup = 'New group…';

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool? _on;
  String? _group;
  TextEditingController? _notes;
  int _rev = 0; // resets the dropdown after "New group…" is cancelled

  @override
  void dispose() {
    _notes?.dispose();
    super.dispose();
  }

  Future<void> _chooseGroup(String v) async {
    if (v != _newGroup) {
      setState(() => _group = v);
      return;
    }
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => const _NewGroupDialog(),
    );
    if (name == null || !mounted) {
      setState(() => _rev++); // the dropdown goes back to the previous group
      return;
    }
    final added = ref.read(favoriteGroupsProvider.notifier).add(name);
    setState(() => _group = ref.read(favoriteGroupsProvider).firstWhere((g) => g.toLowerCase() == name.toLowerCase()));
    context.showSnack(added ? 'Group "$name" created' : 'Group "$_group" already exists – selected');
  }

  void _save(Asset a, bool on, String group) {
    final notes = _notes!.text.trim();
    ref.read(assetsProvider.notifier).setFavorite(a.id, favorite: on, group: group, note: notes);
    finishAction(context, on ? '${a.id} saved to Favorites · $group' : '${a.id} removed from Favorites');
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(favoriteGroupsProvider);
    return MoreActionPage(
      action: MoreAction.favorites,
      assetId: widget.assetId,
      button: (a) => FilledButton(
        onPressed: () => _save(a, _on ?? a.favorite, _group ?? a.favoriteGroup ?? groups.first),
        child: const Text('Save to Favorites'),
      ),
      builder: (context, a) {
        _notes ??= TextEditingController(text: a.favoriteNote ?? '');
        final on = _on ?? a.favorite;
        final group = _group ?? a.favoriteGroup ?? groups.first;
        return [
          AppCard(
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, anim) => ScaleTransition(scale: anim, child: c),
                  child: Icon(
                    on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(on),
                    color: on ? AppColors.red : AppColors.textMuted,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add to Favorites', style: AppText.bodyStrong),
                      Text(on ? 'Shown under Assets → Favorites' : 'Not in your favorites', style: AppText.caption),
                    ],
                  ),
                ),
                Switch(value: on, activeTrackColor: AppColors.primary, onChanged: (v) => setState(() => _on = v)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          formField(
            'Favorite Group',
            required: true,
            DropdownButtonFormField<String>(
              key: ValueKey('$group/${groups.length}/$_rev'),
              initialValue: group,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (final g in groups)
                  DropdownMenuItem(
                    value: g,
                    child: Text('$g (${ref.watch(assetsProvider).favoritesIn(g).length})', style: inputStyle),
                  ),
                DropdownMenuItem(
                  value: _newGroup,
                  child: Text(_newGroup, style: inputStyle.copyWith(color: AppColors.primary)),
                ),
              ],
              onChanged: on ? (v) => v == null ? null : _chooseGroup(v) : null,
            ),
          ),
          formField(
            'Notes',
            TextField(
              controller: _notes,
              maxLines: 3,
              style: inputStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Why is this asset a favorite?'),
            ),
          ),
        ];
      },
    );
  }
}

class _NewGroupDialog extends StatefulWidget {
  const _NewGroupDialog();

  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New favorite group'),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(hintText: 'Group name', errorText: _error),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          final n = _name.text.trim();
          if (n.isEmpty) {
            setState(() => _error = 'Enter a name');
          } else {
            Navigator.pop(context, n);
          }
        },
        child: const Text('Create'),
      ),
    ],
  );
}
