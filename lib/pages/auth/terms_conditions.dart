import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L10n.languageNotifier,
      builder: (context, lang, child) {
        return BgContainer(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: AppColors.button),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                L10n.tr("Terms & Conditions"),
                style: TextStyle(
                  color: AppColors.button,
                  fontFamily: "Super",
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      width: 1,
                      style: BorderStyle.solid,
                      color: AppColors.background,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr("Kinday Terms & Conditions of Use"),
                          style: TextStyle(
                            fontFamily: "Nunito",
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.button,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          L10n.tr("Last updated: July 8, 2026"),
                          style: TextStyle(
                            fontFamily: "Nunito",
                            fontSize: 12,
                            color: AppColors.button.withAlpha(153),
                          ),
                        ),
                        const Divider(height: 30),
                        _buildSectionTitle(L10n.tr("1. Introduction")),
                        _buildSectionBody(
                          L10n.tr("Welcome to Kinday! By creating an account or using our application, you agree to be bound by these Terms and Conditions. Please read this document carefully before using our Service."),
                        ),
                        _buildSectionTitle(L10n.tr("2. User Accounts")),
                        _buildSectionBody(
                          L10n.tr("To use certain features, you must create an account by providing accurate and complete information. You are fully responsible for maintaining the confidentiality of your account password and for all activities that occur under your account."),
                        ),
                        _buildSectionTitle(L10n.tr("3. Use of Service")),
                        _buildSectionBody(
                          L10n.tr("You agree to use Kinday only for lawful purposes and not to violate the laws or rights of others. You are strictly prohibited from misusing our system, attempting to access other users' data without authorization, or disrupting app performance."),
                        ),
                        _buildSectionTitle(L10n.tr("4. Intellectual Property Rights")),
                        _buildSectionBody(
                          L10n.tr("All materials, designs, logos, and code within Kinday are our exclusive property or that of our licensors. You may not copy, modify, distribute, or sell any part of our Service without our written consent."),
                        ),
                        _buildSectionTitle(L10n.tr("5. Limitation of Liability")),
                        _buildSectionBody(
                          L10n.tr("Kinday is provided 'as is' without warranties of any kind, whether express or implied. We are not liable for any direct, indirect, or consequential damages arising from your use or inability to use our application."),
                        ),
                        _buildSectionTitle(L10n.tr("6. Changes to Terms")),
                        _buildSectionBody(
                          L10n.tr("We reserve the right to modify or update these Terms and Conditions at any time. Changes will take effect immediately upon publication in the app. Your continued use after such changes constitutes your acceptance of the new terms."),
                        ),
                        _buildSectionTitle(L10n.tr("7. Contact Us")),
                        _buildSectionBody(
                          L10n.tr("If you have any questions about these Terms and Conditions, please contact us via our support email at harumone.airin@gmail.com."),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: "Nunito",
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppColors.button,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String body) {
    return Text(
      body,
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontFamily: "Nunito",
        fontSize: 13,
        height: 1.5,
        color: AppColors.button.withAlpha(204),
      ),
    );
  }
}
