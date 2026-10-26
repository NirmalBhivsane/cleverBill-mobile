import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/notifications/push_service.dart';
import 'features/security/app_lock.dart';
import 'providers.dart';
import 'router.dart';

class CleverBillApp extends ConsumerStatefulWidget {
  const CleverBillApp({super.key});
  @override
  ConsumerState<CleverBillApp> createState() => _State();
}

class _State extends ConsumerState<CleverBillApp> {
  @override
  void initState() {
    super.initState();
    // register FCM token whenever the user becomes authenticated
    ref.listenManual(authProvider.select((a) => a.status), (prev, next) {
      if (next == AuthStatus.authenticated)
        PushService.register(ref.read(apiProvider));
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final ap = ref.watch(
      appearanceProvider,
    ); // also applies palette to C before theme is built
    return MaterialApp.router(
      title: 'Clever Bill',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final wide = mq.size.width > 600;
        Widget body = child ?? const SizedBox();
        if (wide) {
          body = ColoredBox(
            color: C.dark ? const Color(0xFF05070D) : const Color(0xFFE9EDF5),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ClipRect(child: body),
              ),
            ),
          );
        }
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: C.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(
                mq.textScaler.scale(1.0) * ap.fontScale,
              ),
            ),
            // new key => whole tree rebuilds so every widget picks up the new palette
            child: AppLockGate(
              child: KeyedSubtree(
                key: ValueKey('${ap.dark}-${ap.colorKey}-$lang'),
                child: body,
              ),
            ),
          ),
        );
      },
    );
  }
}
