import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/models.dart';
import 'features/auth/auth_screens.dart';
import 'features/auth/register_screen.dart';
import 'features/more/appearance_screen.dart';
import 'features/more/extra_screens.dart';
import 'features/more/invoice_design_screen.dart';
import 'features/reports/analytics_screens.dart';
import 'features/search/search_screen.dart';
import 'features/customers/customer_screens.dart';
import 'features/home/home_screen.dart';
import 'features/inventory/inventory_screens.dart';
import 'features/inventory/expiry_screen.dart';
import 'features/invoices/invoice_screens.dart';
import 'features/more/more_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/pos/pos_screens.dart';
import 'features/pos/scan_to_web.dart';
import 'features/pos/thermal_printer.dart';
import 'features/reports/reports_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/suppliers/supplier_screens.dart';
import 'providers.dart';

const _ownerOnly = [
  '/supplier',
  '/purchase',
  '/rfq',
  '/quotation',
  '/reports',
  '/analytics',
  '/branches',
  '/branch-activity',
  '/settings/business',
  '/settings/gst',
  '/settings/defaults',
  '/settings/invoice',
  '/settings/bank',
  '/settings/backup',
];

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this.ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final a = ref.read(authProvider);
    final loc = state.matchedLocation;
    if (a.status == AuthStatus.unknown)
      return loc == '/splash' ? null : '/splash';
    final publicRoute = loc == '/welcome' || loc.startsWith('/auth');
    if (a.status == AuthStatus.unauthenticated)
      return publicRoute ? null : '/welcome';
    // authenticated
    if (a.needsSetup) return loc.startsWith('/setup') ? null : '/setup/shop';
    if (loc == '/splash' || publicRoute || loc.startsWith('/setup'))
      return '/home';
    // Branch employees only get the screens the web app shows them (/branch/*)
    if (!(a.session?.isOwner ?? true) && _ownerOnly.any(loc.startsWith))
      return '/home';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final n = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: n,
    redirect: n.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/auth/phone',
        builder: (_, __) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (_, s) => OtpScreen(args: s.extra as OtpArgs),
      ),
      GoRoute(
        path: '/auth/email',
        builder: (_, __) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(path: '/setup/shop', builder: (_, __) => const ShopSetupScreen()),
      GoRoute(
        path: '/setup/billing',
        builder: (_, __) => const BillingSetupScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/bills', builder: (_, __) => const BillsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (_, __) => const InventoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
            ],
          ),
        ],
      ),

      // POS flow
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(
        path: '/scan',
        builder: (_, s) => ScanScreen(forProductForm: s.extra == 'form'),
      ),
      GoRoute(
        path: '/select-customer',
        builder: (_, __) => const SelectCustomerScreen(),
      ),
      GoRoute(path: '/payment', builder: (_, __) => const PaymentScreen()),
      GoRoute(
        path: '/upi',
        builder: (_, s) => UpiScreen(args: s.extra as UpiArgs),
      ),
      GoRoute(
        path: '/bill-success',
        builder: (_, s) => BillSuccessScreen(invoice: s.extra as Invoice),
      ),

      // Invoices & returns
      GoRoute(
        path: '/invoice/:id',
        builder: (_, s) => InvoiceDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invoice-create',
        builder: (_, __) => const CreateInvoiceScreen(),
      ),
      GoRoute(
        path: '/return-create',
        builder: (_, s) => ReturnCreateScreen(invoice: s.extra as Invoice),
      ),
      GoRoute(path: '/returns', builder: (_, __) => const ReturnsScreen()),

      // Inventory
      GoRoute(
        path: '/product/:id',
        builder: (_, s) => ProductDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/product-form',
        builder: (_, s) => ProductFormScreen(product: s.extra as Product?),
      ),
      GoRoute(
        path: '/categories',
        builder: (_, __) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/adjust-stock',
        builder: (_, s) => AdjustStockScreen(product: s.extra as Product),
      ),
      GoRoute(path: '/purchases', builder: (_, __) => const PurchasesScreen()),
      GoRoute(
        path: '/purchase-form',
        builder: (_, s) => PurchaseFormScreen(preset: s.extra as Product?),
      ),

      // Customers & payments
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
      GoRoute(
        path: '/customer/:id',
        builder: (_, s) => CustomerDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer-form',
        builder: (_, s) => CustomerFormScreen(customer: s.extra as Customer?),
      ),
      GoRoute(
        path: '/receive-payment',
        builder: (_, s) => ReceivePaymentScreen(invoice: s.extra as Invoice),
      ),
      GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),

      // Suppliers
      GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersScreen()),
      GoRoute(
        path: '/supplier/:id',
        builder: (_, s) => SupplierDetailScreen(
          id: s.pathParameters['id'],
          supplier: s.extra as Supplier?,
        ),
      ),
      GoRoute(
        path: '/supplier-form',
        builder: (_, s) => SupplierFormScreen(supplier: s.extra as Supplier?),
      ),
      GoRoute(path: '/rfqs', builder: (_, __) => const RfqScreen()),
      GoRoute(
        path: '/quotation',
        builder: (_, s) => QuotationScreen(rfq: s.extra as Rfq),
      ),

      // More
      GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/settings/business',
        builder: (_, __) => const BusinessSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/invoice',
        builder: (_, __) => const InvoiceDesignScreen(),
      ),
      GoRoute(
        path: '/settings/bank',
        builder: (_, __) => const BankUpiScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (_, __) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (_, __) => const BackupScreen(),
      ),
      GoRoute(path: '/branches', builder: (_, __) => const BranchesScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(
        path: '/scan-to-web',
        builder: (_, __) => const ScanToWebScreen(),
      ),
      GoRoute(path: '/expiry', builder: (_, __) => const ExpiryScreen()),
      GoRoute(
        path: '/rfq-detail',
        builder: (_, s) => RfqDetailScreen(rfq: s.extra as Rfq),
      ),
      GoRoute(
        path: '/quotations',
        builder: (_, __) => const QuotationsListScreen(),
      ),
      GoRoute(
        path: '/settings/printer',
        builder: (_, __) => const BluetoothPrinterScreen(),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(
        path: '/branch-activity',
        builder: (_, s) => BranchActivityScreen(branch: s.extra as Branch),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, __) => const AppearanceScreen(),
      ),
      GoRoute(path: '/settings/gst', builder: (_, __) => const GstTaxScreen()),
      GoRoute(
        path: '/settings/defaults',
        builder: (_, __) => const BusinessDefaultsScreen(),
      ),
      GoRoute(
        path: '/settings/hardware',
        builder: (_, __) => const HardwareScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),
    ],
  );
});
