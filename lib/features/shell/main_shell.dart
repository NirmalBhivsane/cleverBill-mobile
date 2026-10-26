import 'package:flutter/material.dart' hide Text;

import '../../core/i18n/i18n.dart';

import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bills'),
      (Icons.add_rounded, Icons.add_rounded, 'New Bill'),
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
    ];
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: C.card,
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => shell.goBranch(
                        i,
                        initialLocation: i == shell.currentIndex,
                      ),
                      child: i == 2
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: C.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: C.primary.withOpacity(.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  items[i].$3,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: shell.currentIndex == i
                                        ? C.primary
                                        : C.muted,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  shell.currentIndex == i
                                      ? items[i].$2
                                      : items[i].$1,
                                  color: shell.currentIndex == i
                                      ? C.primary
                                      : C.muted,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  items[i].$3,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: shell.currentIndex == i
                                        ? C.primary
                                        : C.muted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
