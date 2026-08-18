import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/wallet_provider.dart';

class ConnectWalletModal extends ConsumerStatefulWidget {
  const ConnectWalletModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ConnectWalletModal(),
    );
  }

  @override
  ConsumerState<ConnectWalletModal> createState() => _ConnectWalletModalState();
}

class _ConnectWalletModalState extends ConsumerState<ConnectWalletModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedProvider = 'Wave';
  String _authMethod = 'OAUTH2_WAVE';
  final TextEditingController _phoneController =
      TextEditingController(text: '+225 07 00 00 05');
  final TextEditingController _balanceController =
      TextEditingController(text: '12000');

  final TextEditingController _smsSimulatorController = TextEditingController(
    text: 'Vous avez reçu 15 000 FCFA de Kouamé via Wave. Votre nouveau solde est de 45 000 FCFA.',
  );
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _providers = [
    {
      'name': 'Wave',
      'image': AppImages.wave,
      'authMethod': 'OAUTH2_WAVE',
      'type': 'API Officielle Wave (OAuth2 Direct)',
      'brandColor': Colors.blue,
    },
    {
      'name': 'Orange Money',
      'image': AppImages.orange,
      'authMethod': 'ORANGE_DEVELOPER_API',
      'type': 'Orange Developer API (Méthode 1)',
      'brandColor': Colors.orange,
    },
    {
      'name': 'MTN MoMo',
      'image': AppImages.mtn,
      'authMethod': 'MTN_MOMO_API',
      'type': 'MTN MoMo Open API (Méthode 1)',
      'brandColor': Colors.amber,
    },
    {
      'name': 'Perception Engine',
      'image': AppImages.logo,
      'authMethod': 'PERCEIVE_SMS_PUSH',
      'type': 'Moteur de Perception SMS & Push (Méthode 3)',
      'brandColor': AppColors.emerald,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _balanceController.dispose();
    _smsSimulatorController.dispose();
    super.dispose();
  }

  Future<void> _handleConnectApi() async {
    setState(() => _isSubmitting = true);
    final phone = _phoneController.text.trim();
    final balance = double.tryParse(_balanceController.text.trim()) ?? 10000.0;

    final success = await ref.read(walletProvider.notifier).connectNewWallet(
          provider: _selectedProvider,
          accountNumber: phone,
          authMethod: _authMethod,
          initialBalance: balance,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('✅ Compte $_selectedProvider connecté via Méthode 1 !'),
          ),
        );
      }
    }
  }

  Future<void> _handleSimulatePerception() async {
    setState(() => _isSubmitting = true);
    final smsText = _smsSimulatorController.text.trim();

    final success = await ref
        .read(walletProvider.notifier)
        .perceiveSmsNotification(smsText, sender: _selectedProvider.toUpperCase());

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('🚀 Moteur de Perception (Méthode 3) : SMS analysé et solde mis à jour !'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDarker,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // TITRE ET EXPLICATION MÉTHODES 1 & 3
          Text(
            langNotifier.tr(
              'Connexion Portefeuilles (Méthodes 1 & 3)',
              'Wallet Connection (Methods 1 & 3)',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            langNotifier.tr(
              'Méthode 1 : APIs & OAuth2 Officiels (Wave, Orange, MTN)\nMéthode 3 : Moteur de Perception SIKA (SMS & Notifications Push Android 🚀)',
              'Method 1: Official APIs & OAuth2 (Wave, Orange, MTN)\nMethod 3: SIKA Perception Engine (SMS & Push Notifications 🚀)',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),

          const SizedBox(height: 16),

          // TAB BAR POUR MÉTHODES 1 & 3
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.cyan,
            labelColor: AppColors.cyan,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(
                text: langNotifier.tr('Méthode 1 : APIs OAuth2', 'Method 1: OAuth2 APIs'),
              ),
              Tab(
                text: langNotifier.tr('Méthode 3 : SMS Perception', 'Method 3: SMS Perception'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 310,
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1 : MÉTHODE 1 (APIS ET OAUTH2 DIRECT)
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SÉLECTION PROVIDER
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                          itemBuilder: (ctx, index) {
                            final prov = _providers[index];
                            final bool isSelected = _selectedProvider == prov['name'];

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedProvider = prov['name'] as String;
                                  _authMethod = prov['authMethod'] as String;
                                });
                              },
                              child: Container(
                                width: 105,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (prov['brandColor'] as Color).withValues(alpha: 0.15)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? (prov['brandColor'] as Color) : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        prov['image'] as String,
                                        width: 22,
                                        height: 22,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Icon(
                                          Icons.account_balance_wallet,
                                          color: prov['brandColor'] as Color,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      prov['name'] as String,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          hintText: '+225 07 00 00 00',
                          prefixIcon: const Icon(Icons.phone, color: AppColors.cyan, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: _balanceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          hintText: 'Solde initial (FCFA)',
                          prefixIcon: const Icon(Icons.account_balance_wallet, color: AppColors.emerald, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleConnectApi,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cyan,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  langNotifier.tr('Connecter via OAuth2', 'Connect via OAuth2'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // TAB 2 : MÉTHODE 3 (MOTEUR DE PERCEPTION SMS & PUSH NOTIFICATIONS 🚀)
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.emerald),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: AppColors.emerald, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                langNotifier.tr(
                                  'Perception Automatique SIKA : Interception en arrière-plan des SMS de Wave, Orange et MTN.',
                                  'SIKA Auto Perception: Background interception of Wave, Orange, and MTN SMS.',
                                ),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        langNotifier.tr('Simuler ou Coller un SMS Telco :', 'Simulate or Paste Telco SMS:'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 6),

                      TextField(
                        controller: _smsSimulatorController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          hintText: 'Collage d\'un SMS de notification...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleSimulatePerception,
                          icon: const Icon(Icons.bolt, color: Colors.white),
                          label: Text(
                            langNotifier.tr('Analyser via Moteur SIKA', 'Analyze via SIKA Engine'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
