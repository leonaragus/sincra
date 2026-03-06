
import 'package:flutter/material.dart';

@immutable
class SubscriptionPlan {
  final String name;
  final String description;
  
  // --- Identificadores de Producto en Google Play ---
  final String monthlyId; 
  final String annualId;

  // --- Precios en ARS ---
  final String monthlyPrice;
  final String annualPrice;

  // --- Límites y Características ---
  final int maxCompanies;
  final int maxEmployeesPerCompany;
  final int claudeCallsPerMonth;
  final bool unlimitedClaudeCalls; // Nuevo campo para llamadas ilimitadas
  final bool isUnlimited; // Para empresas y empleados
  
  final int trialDurationDays; 
  final int trialClaudeCallsLimit;

  const SubscriptionPlan({
    required this.name,
    required this.description,
    this.monthlyId = '',
    this.annualId = '',
    this.monthlyPrice = '',
    this.annualPrice = '',
    this.maxCompanies = 0,
    this.maxEmployeesPerCompany = 0,
    this.claudeCallsPerMonth = 0,
    this.unlimitedClaudeCalls = false,
    this.isUnlimited = false,
    this.trialDurationDays = 0,
    this.trialClaudeCallsLimit = 0,
  });

  // Plan de Prueba Gratuito
  static const SubscriptionPlan freeTrial = SubscriptionPlan(
    name: 'Prueba Gratuita',
    description: 'Acceso completo por tiempo limitado.',
    trialDurationDays: 20,
    trialClaudeCallsLimit: 2,
    isUnlimited: true,
  );

  // Plan 1: Independientes y Pymes
  static const SubscriptionPlan independent = SubscriptionPlan(
    name: 'Independiente & Pyme',
    monthlyId: 'independent_monthly_ars_v1',
    annualId: 'independent_annual_ars_v1',
    monthlyPrice: '15000',
    annualPrice: '120000',
    description: 'Ideal para profesionales que empiezan o pymes que se autogestionan.',
    maxCompanies: 5,
    maxEmployeesPerCompany: 10,
    claudeCallsPerMonth: 50,
  );

  // Plan 2: Estudios Contables
  static const SubscriptionPlan accountingFirm = SubscriptionPlan(
    name: 'Estudio Contable',
    monthlyId: 'firm_monthly_ars_v1',
    annualId: 'firm_annual_ars_v1',
    monthlyPrice: '50000',
    annualPrice: '500000',
    description: 'La herramienta perfecta para contadores con múltiples clientes.',
    maxCompanies: 10,
    maxEmployeesPerCompany: 50,
    unlimitedClaudeCalls: true, 
  );

  // Plan 3: Corporativo (ACTUALIZADO)
  static const SubscriptionPlan corporate = SubscriptionPlan(
    name: 'Corporativo',
    monthlyId: 'corporate_monthly_ars_v1',
    annualId: 'corporate_annual_ars_v1',
    monthlyPrice: '150000',
    annualPrice: '1500000',
    description: 'Solución total para empresas y estudios de gran volumen.',
    unlimitedClaudeCalls: true,
    isUnlimited: true, // Empresas y empleados ilimitados
  );
}
