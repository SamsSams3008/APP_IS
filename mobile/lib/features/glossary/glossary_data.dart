import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

/// Identificadores de métricas (para rutas y detalle).
const List<String> metricIds = [
  'revenue',
  'impressions',
  'ecpm',
  'clicks',
  'completions',
  'fill_rate',
  'completion_rate',
  'revenue_per_completion',
  'ctr',
  'app_requests',
  'dau',
  'sessions',
];

class GlossaryEntry {
  const GlossaryEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

final Map<String, GlossaryEntry> glossaryEntries = {
  'revenue': const GlossaryEntry(
    id: 'revenue',
    title: 'Ingresos (Revenue)',
    icon: Icons.attach_money,
    description: 'Total de dinero generado por la monetización de anuncios en tu app. '
        'Incluye todos los formatos (rewarded video, intersticial, banner, offerwall) '
        'en el periodo seleccionado. Es el indicador principal de rendimiento económico.',
  ),
  'impressions': const GlossaryEntry(
    id: 'impressions',
    title: 'Impresiones',
    icon: Icons.visibility,
    description: 'Número de veces que se mostró un anuncio a un usuario. '
        'Cada vez que un anuncio aparece en pantalla cuenta como una impresión. '
        'Más impresiones con buen eCPM suelen traducirse en más ingresos.',
  ),
  'ecpm': const GlossaryEntry(
    id: 'ecpm',
    title: 'eCPM (Effective CPM)',
    icon: Icons.trending_up,
    description: 'Ingresos efectivos por cada mil impresiones. Se calcula como: (Ingresos / Impresiones) × 1000. '
        'Indica cuánto estás ganando por mil visualizaciones; sirve para comparar rendimiento entre formatos, apps o periodos.',
  ),
  'clicks': const GlossaryEntry(
    id: 'clicks',
    title: 'Clicks',
    icon: Icons.touch_app,
    description: 'Número de veces que los usuarios hicieron clic en un anuncio. '
        'Útil para formatos donde el click es parte del funnel (por ejemplo banners). '
        'En rewarded video el indicador más relevante suele ser completions.',
  ),
  'completions': const GlossaryEntry(
    id: 'completions',
    title: 'Completados',
    icon: Icons.check_circle,
    description: 'Cantidad de anuncios que el usuario vio por completo (ej. rewarded video visto hasta el final). '
        'Un completion suele pagar más que una simple impresión. Es clave para optimizar inventario de rewarded.',
  ),
  'fill_rate': const GlossaryEntry(
    id: 'fill_rate',
    title: 'Fill rate',
    icon: Icons.pie_chart_outline,
    description: 'Porcentaje de solicitudes de anuncio que recibieron un anuncio para mostrarse. '
        'Un fill rate bajo indica que la demanda de anunciantes no cubre tu inventario; '
        'puedes mejorar con más redes o ajustando segmentación.',
  ),
  'completion_rate': const GlossaryEntry(
    id: 'completion_rate',
    title: 'Completion rate',
    icon: Icons.done_all,
    description: 'Porcentaje de impresiones que se convirtieron en visualizaciones completas (ej. video visto al 100%). '
        'Mide la calidad del engagement: a mayor completion rate, mejor experiencia y normalmente mejor eCPM.',
  ),
  'revenue_per_completion': const GlossaryEntry(
    id: 'revenue_per_completion',
    title: 'Revenue por completion',
    icon: Icons.monetization_on_outlined,
    description: 'Ingresos medios por cada anuncio completado (ej. por cada rewarded video visto hasta el final). '
        'Ayuda a valorar el rendimiento de cada completion y a comparar entre formatos o redes.',
  ),
  'ctr': const GlossaryEntry(
    id: 'ctr',
    title: 'CTR (Click-Through Rate)',
    icon: Icons.ads_click,
    description: 'Porcentaje de impresiones que generaron un clic. Fórmula: (Clicks / Impresiones) × 100. '
        'Relevante sobre todo en banners e intersticiales donde el clic es un objetivo. '
        'Un CTR alto suele indicar creativos atractivos o buena colocación.',
  ),
  'app_requests': const GlossaryEntry(
    id: 'app_requests',
    title: 'App requests',
    icon: Icons.sync,
    description: 'Número de veces que tu app solicitó un anuncio a la plataforma (LevelPlay/IronSource). '
        'Comparado con impresiones y fill rate, te dice cuántas oportunidades de mostrar anuncios hubo y cuántas se cumplieron.',
  ),
  'dau': const GlossaryEntry(
    id: 'dau',
    title: 'DAU (Daily Active Users)',
    icon: Icons.people,
    description: 'Usuarios únicos que interactuaron con tu app en un día. '
        'Indica el alcance diario y la base de usuarios activos; útil para comparar con ingresos e impresiones y ver rendimiento por usuario.',
  ),
  'sessions': const GlossaryEntry(
    id: 'sessions',
    title: 'Sesiones',
    icon: Icons.event_note,
    description: 'Número de sesiones de uso de la app (aperturas o periodos de uso). '
        'Una sesión suele ser una apertura de la app hasta que el usuario la cierra o pasa a segundo plano. '
        'Ayuda a entender la frecuencia de uso y a relacionar monetización con sesiones.',
  ),
};

GlossaryEntry? getGlossaryEntry(String id) => glossaryEntries[id];

/// Keys en AppStrings para título y descripción por idioma.
const Map<String, List<String>> _glossaryKeys = {
  'revenue': ['gloss_revenue_title', 'gloss_revenue_desc'],
  'impressions': ['gloss_impressions_title', 'gloss_impressions_desc'],
  'ecpm': ['gloss_ecpm_title', 'gloss_ecpm_desc'],
  'clicks': ['gloss_clicks_title', 'gloss_clicks_desc'],
  'completions': ['gloss_completions_title', 'gloss_completions_desc'],
  'fill_rate': ['gloss_fill_rate_title', 'gloss_fill_rate_desc'],
  'completion_rate': ['gloss_completion_rate_title', 'gloss_completion_rate_desc'],
  'revenue_per_completion': ['gloss_rev_per_comp_title', 'gloss_rev_per_comp_desc'],
  'ctr': ['gloss_ctr_title', 'gloss_ctr_desc'],
  'app_requests': ['gloss_app_requests_title', 'gloss_app_requests_desc'],
  'dau': ['gloss_dau_title', 'gloss_dau_desc'],
  'sessions': ['gloss_sessions_title', 'gloss_sessions_desc'],
};

String getGlossaryTitle(String id, String locale) {
  final keys = _glossaryKeys[id];
  if (keys != null) return AppStrings.t(keys[0], locale);
  return glossaryEntries[id]?.title ?? id;
}

String getGlossaryDescription(String id, String locale) {
  final keys = _glossaryKeys[id];
  if (keys != null) return AppStrings.t(keys[1], locale);
  return glossaryEntries[id]?.description ?? '';
}

String getMetricRouteId(String metricId) => metricId;
