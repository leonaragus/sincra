import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/claude_vision_service.dart';
import '../theme/app_colors.dart';
import '../utils/auth_middleware.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userInfo;
  bool _loading = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // Direct access to current user
      final user = Supabase.instance.client.auth.currentUser;
      final userInfo = {'user': user};
      
      // Cargar avatar
      String? avatar;
      if (user != null) {
        try {
          final profile = await Supabase.instance.client
              .from('user_profiles')
              .select('avatar_url')
              .eq('id', user.id)
              .maybeSingle();
          if (profile != null) {
            avatar = profile['avatar_url'];
          }
        } catch (_) {} // Ignorar si falla o tabla no existe
      }

      setState(() {
        _userInfo = userInfo;
        _avatarUrl = avatar;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (image == null) return;

    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No usuario autenticado');

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      // Update Profile with ID explicit to avoid 23502 error
      await Supabase.instance.client.from('user_profiles').upsert({
        'id': user.id,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _avatarUrl = imageUrl;
        _loading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo actualizado correctamente')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir logo: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _openWhatsAppSupport() async {
    const phone = '+5491123456789'; // Reemplazar con número real
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _configurarApiKey() async {
    final currentKey = await ClaudeVisionService.getApiKey() ?? '';
    final ctrl = TextEditingController(text: currentKey);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar Claude API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingrese su clave de API de Anthropic (Claude) para habilitar el reconocimiento avanzado de recibos.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'API Key (sk-ant-...)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await ClaudeVisionService.setApiKey(ctrl.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key guardada correctamente')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _userInfo?['user'] as User?;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de Cuenta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Icon(Icons.email, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user?.email ?? 'No email',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              GestureDetector(
                onTap: _uploadLogo,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuario desde: ${user?.createdAt.substring(0, 10) ?? 'N/A'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toca el icono para cambiar logo',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    const url = 'https://sincra.web.app/privacy-policy';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Syncra Arg',
      applicationVersion: '1.0.0',
      applicationIcon: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Icon(Icons.verified_user, size: 48),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Soporte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.green),
            title: const Text('Soporte por WhatsApp'),
            subtitle: const Text('Contactanos 24/7'),
            onTap: _openWhatsAppSupport,
            contentPadding: EdgeInsets.zero,
          ),
          
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: AppColors.primary),
            title: const Text('Políticas de Privacidad'),
            subtitle: const Text('Términos y condiciones'),
            onTap: _launchPrivacyPolicy,
            contentPadding: EdgeInsets.zero,
          ),
          
          ListTile(
            leading: const Icon(Icons.description, color: Colors.blueGrey),
            title: const Text('Licencias'),
            subtitle: const Text('Software de código abierto'),
            onTap: _showLicenses,
            contentPadding: EdgeInsets.zero,
          ),

          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('Versión de la App'),
            subtitle: const Text('1.0.0'),
            contentPadding: EdgeInsets.zero,
          ),
          
          ListTile(
            leading: const Icon(Icons.key, color: Colors.purple),
            title: const Text('Configuración API (Claude)'),
            subtitle: const Text('Mejorar reconocimiento OCR'),
            onTap: _configurarApiKey,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildUserInfo(),
                  const SizedBox(height: 20),
                  _buildSupportSection(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cerrar Sesión', style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}