import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/ghost_layer/bloc/ghost_bloc.dart';
import '../../../features/settings/bloc/settings_bloc.dart';
import '../../../features/stack_mode/bloc/stack_bloc.dart';
import '../../../shared/theme/app_theme.dart';
import 'clipboard_view.dart';
import '../../stack_mode/widgets/stack_view.dart';
import '../../scratchpad/widgets/scratchpad_view.dart';
import '../../chunking/widgets/chunk_view.dart';
import '../../teleport/widgets/teleport_view.dart';
import '../../ghost_layer/widgets/ghost_view.dart';
import '../../settings/widgets/settings_view.dart';

enum AppSection { clipboard, stack, scratchpad, chunk, teleport, ghost, settings }

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppSection _section = AppSection.clipboard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true):
          () => setState(() => _section = AppSection.clipboard),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
          () => context.read<StackBloc>().add(const StackToggleMode()),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true):
          () => setState(() => _section = AppSection.scratchpad),
        const SingleActivator(LogicalKeyboardKey.escape):
          () {},
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.bg,
          body: Row(children: [
            _Sidebar(
              selected: _section,
              onSelect: (s) => setState(() => _section = s),
            ),
            Expanded(child: _buildBody()),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_section) {
      case AppSection.clipboard:  return const ClipboardView();
      case AppSection.stack:      return const StackView();
      case AppSection.scratchpad: return const ScratchpadView();
      case AppSection.chunk:      return const ChunkView();
      case AppSection.teleport:   return const TeleportView();
      case AppSection.ghost:      return const GhostView();
      case AppSection.settings:   return const SettingsView();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 56,
      color: colors.surface,
      child: Column(children: [
        // Logo
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00D4FF), Color(0xFFA855F7)],
              ),
            ),
            child: const Center(
              child: Text('CN',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700,
                  fontSize: 12, letterSpacing: -0.5)),
            ),
          ),
        ),

        // Nav items
        _NavBtn(icon: Icons.content_paste_rounded,  label: 'History',    section: AppSection.clipboard,  selected: selected, onTap: onSelect),
        _NavBtn(icon: Icons.layers_rounded,          label: 'Stack Mode', section: AppSection.stack,      selected: selected, onTap: onSelect,
          badge: BlocBuilder<StackBloc, StackState>(
            builder: (ctx, s) => s.isActive ? _ActiveDot(color: ctx.colors.accent) : const SizedBox.shrink(),
          ),
        ),
        _NavBtn(icon: Icons.edit_note_rounded,       label: 'Scratchpad', section: AppSection.scratchpad, selected: selected, onTap: onSelect),
        _NavBtn(icon: Icons.content_cut_rounded,     label: 'Chunk',      section: AppSection.chunk,      selected: selected, onTap: onSelect),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: colors.border, thickness: 1, indent: 12, endIndent: 12),
        ),

        _NavBtn(icon: Icons.wifi_tethering_rounded,  label: 'Teleport',  section: AppSection.teleport,  selected: selected, onTap: onSelect),
        _NavBtn(icon: Icons.security_rounded,         label: 'Ghost',     section: AppSection.ghost,     selected: selected, onTap: onSelect,
          badge: BlocBuilder<GhostBloc, GhostState>(
            builder: (ctx, s) => s.sensitiveItems.isNotEmpty
              ? _ActiveDot(color: ctx.colors.red) : const SizedBox.shrink(),
          ),
        ),

        const Spacer(),

        _NavBtn(icon: Icons.settings_rounded,         label: 'Settings',  section: AppSection.settings,  selected: selected, onTap: onSelect),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppSection section;
  final AppSection selected;
  final ValueChanged<AppSection> onTap;
  final Widget? badge;

  const _NavBtn({
    required this.icon, required this.label, required this.section,
    required this.selected, required this.onTap, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelected = section == selected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: InkWell(
          onTap: () => onTap(section),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected ? colors.accentBg : Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon,
                  size: 18,
                  color: isSelected ? colors.accent : colors.text3,
                ),
                if (badge != null)
                  Positioned(top: 4, right: 4, child: badge!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  final Color color;
  const _ActiveDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 1.5),
      ),
    );
  }
}
